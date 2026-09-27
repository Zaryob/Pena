import Foundation
import AVFoundation
import Accelerate
import Observation

// MARK: - Pitch Detection Result
public struct PitchDetectionResult: Equatable {
    public let frequency: Double
    public let amplitude: Float
    public let clarity: Double
    public let timestamp: Date
}

// MARK: - Thread-Safe Audio Buffer Accumulator
final class AudioBufferAccumulator: @unchecked Sendable {
    private let capacity = 4096
    private var buffer: [Float]
    private var count = 0
    private var lock = os_unfair_lock()
    
    init() {
        self.buffer = [Float](repeating: 0.0, count: capacity)
    }
    
    func append(samples: UnsafePointer<Float>, sampleCount: Int) -> ([Float], Int)? {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        if sampleCount >= capacity {
            for i in 0..<capacity {
                buffer[i] = samples[sampleCount - capacity + i]
            }
            count = capacity
        } else {
            let shift = sampleCount
            let keep = capacity - shift
            buffer.withUnsafeMutableBufferPointer { ptr in
                let base = ptr.baseAddress!
                memmove(base, base.advanced(by: shift), keep * MemoryLayout<Float>.stride)
                memcpy(base.advanced(by: keep), samples, shift * MemoryLayout<Float>.stride)
            }
            count = min(capacity, count + sampleCount)
        }
        
        guard count >= 2048 else { return nil }
        return (buffer, count)
    }
    
    func reset() {
        os_unfair_lock_lock(&lock)
        count = 0
        os_unfair_lock_unlock(&lock)
    }
}

// MARK: - Audio Engine Manager
@MainActor
@Observable
public final class AudioEngineManager: NSObject {
    // Observable State
    public private(set) var isRunning: Bool = false
    public private(set) var hasMicrophonePermission: Bool = false
    public private(set) var permissionRequested: Bool = false
    public private(set) var currentFrequency: Double? = nil
    public private(set) var smoothedFrequency: Double? = nil
    public private(set) var currentAmplitude: Float = 0.0
    public private(set) var isPluckDetected: Bool = false
    public private(set) var lastErrorMessage: String? = nil
    
    // User Settings
    // Default threshold lowered to 0.003 for sensitive acoustic guitar pickup
    public var noiseGateThreshold: Float = 0.003
    public var a4Calibration: Double = 440.0
    
    // Audio engine components
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var toneEngine: AVAudioEngine?
    @ObservationIgnored private var toneSourceNode: AVAudioSourceNode?
    @ObservationIgnored private let accumulator = AudioBufferAccumulator()
    
    // Internal pitch detection variables
    @ObservationIgnored private var sampleRate: Double = 48000.0
    @ObservationIgnored private var pluckCooldown: Double = 0.0
    @ObservationIgnored private var silenceFramesCount = 0
    
    // Tone generation state
    @ObservationIgnored private var tonePhase: Double = 0.0
    @ObservationIgnored private var toneFrequency: Double = 0.0
    @ObservationIgnored private var toneAmplitude: Double = 0.0
    @ObservationIgnored private var toneDecayRate: Double = 1.5
    @ObservationIgnored private var isToneActive: Bool = false
    @ObservationIgnored private var toneTimer: Timer?
    
    public override init() {
        super.init()
        checkMicrophonePermission()
    }
    
    // MARK: - Permission Handling
    public func checkMicrophonePermission() {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            let status = AVAudioApplication.shared.recordPermission
            self.hasMicrophonePermission = (status == .granted)
            self.permissionRequested = (status != .undetermined)
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            self.hasMicrophonePermission = (status == .granted)
            self.permissionRequested = (status != .undetermined)
        }
        #else
        self.hasMicrophonePermission = true
        self.permissionRequested = true
        #endif
    }
    
    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void = { _ in }) {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasMicrophonePermission = granted
                    self?.permissionRequested = true
                    completion(granted)
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasMicrophonePermission = granted
                    self?.permissionRequested = true
                    completion(granted)
                }
            }
        }
        #else
        self.hasMicrophonePermission = true
        self.permissionRequested = true
        completion(true)
        #endif
    }
    
    // MARK: - Start / Stop Audio Engine
    public func start() {
        guard !isRunning else { return }
        
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
            )
            try audioSession.setPreferredIOBufferDuration(0.01) // Low latency input
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession setup error: \(error.localizedDescription)")
            self.lastErrorMessage = error.localizedDescription
        }
        #endif
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        
        // Pass nil to installTap to automatically match hardware format
        inputNode.removeTap(onBus: 0)
        let accumulatorRef = self.accumulator
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            self?.processIncomingBuffer(buffer, accumulator: accumulatorRef)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
            self.isRunning = true
            self.lastErrorMessage = nil
            setupToneEngine()
        } catch {
            print("AudioEngine start error: \(error.localizedDescription)")
            self.lastErrorMessage = error.localizedDescription
            self.isRunning = false
        }
    }
    
    public func stop() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            self.audioEngine = nil
        }
        stopToneEngine()
        accumulator.reset()
        self.isRunning = false
        self.currentFrequency = nil
        self.smoothedFrequency = nil
        self.currentAmplitude = 0.0
    }
    
    // MARK: - Incoming Audio Buffer Handling
    nonisolated private func processIncomingBuffer(_ buffer: AVAudioPCMBuffer, accumulator: AudioBufferAccumulator) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        
        let actualSampleRate = buffer.format.sampleRate > 0 ? buffer.format.sampleRate : 48000.0
        
        // Compute RMS of incoming chunk
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
        
        // Append to rolling analysis buffer
        guard let (analysisSamples, currentCount) = accumulator.append(samples: channelData, sampleCount: frameCount) else {
            return
        }
        
        // Remove DC offset
        var mean: Float = 0.0
        vDSP_meanv(analysisSamples, 1, &mean, vDSP_Length(currentCount))
        var negativeMean = -mean
        var centeredSamples = [Float](repeating: 0.0, count: currentCount)
        vDSP_vsadd(analysisSamples, 1, &negativeMean, &centeredSamples, 1, vDSP_Length(currentCount))
        
        // Detect pitch using McLeod NSDF
        let pitchResult = detectPitchMcLeod(
            samples: centeredSamples,
            count: currentCount,
            sampleRate: actualSampleRate,
            rms: rms
        )
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentAmplitude = rms
            
            // Check noise threshold
            if rms < self.noiseGateThreshold || pitchResult == nil {
                self.silenceFramesCount += 1
                if self.silenceFramesCount > 6 { // ~120ms of silence before resetting
                    self.currentFrequency = nil
                    self.smoothedFrequency = nil
                }
                return
            }
            
            self.silenceFramesCount = 0
            guard let detected = pitchResult else { return }
            let freq = detected.frequency
            
            // Pluck detection / smoothing
            if let prev = self.smoothedFrequency {
                let semitoneDiff = abs(12.0 * log2(freq / prev))
                if semitoneDiff > 1.2 {
                    // Quick jump to new note
                    self.smoothedFrequency = freq
                    self.isPluckDetected = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        self.isPluckDetected = false
                    }
                } else {
                    // Smooth tracking
                    let alpha = 0.35
                    self.smoothedFrequency = prev * (1.0 - alpha) + freq * alpha
                }
            } else {
                self.smoothedFrequency = freq
                self.isPluckDetected = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    self.isPluckDetected = false
                }
            }
            
            self.currentFrequency = freq
        }
    }
    
    // MARK: - McLeod Pitch Method (NSDF) with Subharmonic Correction
    nonisolated private func detectPitchMcLeod(
        samples: [Float],
        count: Int,
        sampleRate: Double,
        rms: Float
    ) -> PitchDetectionResult? {
        // Classical guitar range: 65 Hz (Drop D) to 800 Hz (high frets on 1st string)
        let minFreq = 65.0
        let maxFreq = 800.0
        
        let minPeriod = max(8, Int(sampleRate / maxFreq))
        let maxPeriod = min(count / 2, Int(sampleRate / minFreq))
        
        guard maxPeriod > minPeriod, count > maxPeriod * 2 else { return nil }
        let windowSize = count - maxPeriod
        
        // Compute NSDF
        var nsdf = [Double](repeating: 0.0, count: maxPeriod + 1)
        
        for tau in minPeriod...maxPeriod {
            var sumCross: Double = 0.0
            var sumSquare1: Double = 0.0
            var sumSquare2: Double = 0.0
            
            for j in stride(from: 0, to: windowSize, by: 2) {
                let x1 = Double(samples[j])
                let x2 = Double(samples[j + tau])
                sumCross += x1 * x2
                sumSquare1 += x1 * x1
                sumSquare2 += x2 * x2
            }
            
            let denom = sumSquare1 + sumSquare2
            if denom > 1e-8 {
                nsdf[tau] = (2.0 * sumCross) / denom
            } else {
                nsdf[tau] = 0.0
            }
        }
        
        // Find maximum value
        var maxVal = -1.0
        for tau in minPeriod...maxPeriod {
            if nsdf[tau] > maxVal {
                maxVal = nsdf[tau]
            }
        }
        
        // Confidence threshold (at least 0.35 correlation)
        guard maxVal > 0.35 else { return nil }
        
        let threshold = maxVal * 0.82
        var bestTau: Double? = nil
        var bestClarity: Double = 0.0
        
        // Find first prominent peak
        for tau in (minPeriod + 1)..<maxPeriod {
            if nsdf[tau] > nsdf[tau - 1] && nsdf[tau] >= nsdf[tau + 1] && nsdf[tau] >= threshold {
                let y1 = nsdf[tau - 1]
                let y2 = nsdf[tau]
                let y3 = nsdf[tau + 1]
                
                let denom = 2.0 * (2.0 * y2 - y1 - y3)
                let delta = (denom != 0.0) ? (y3 - y1) / denom : 0.0
                
                let refined = Double(tau) + delta
                if refined > 0 {
                    bestTau = refined
                    bestClarity = y2
                    break
                }
            }
        }
        
        guard var period = bestTau, period > 0 else { return nil }
        
        // Check for octave / subharmonic error:
        // On nylon guitar, sometimes the 2nd harmonic (half the true period) has high correlation.
        // Check if there is also a strong peak near 2 * period:
        let doubleTau = Int(round(period * 2.0))
        if doubleTau + 1 <= maxPeriod && doubleTau - 1 >= minPeriod {
            let correlationAt2X = max(nsdf[doubleTau - 1], max(nsdf[doubleTau], nsdf[doubleTau + 1]))
            if correlationAt2X > 0.40 && correlationAt2X >= bestClarity * 0.65 {
                // The true fundamental period is the longer one!
                period = period * 2.0
            }
        }
        
        let frequency = sampleRate / period
        guard frequency >= minFreq && frequency <= maxFreq else { return nil }
        
        return PitchDetectionResult(
            frequency: frequency,
            amplitude: rms,
            clarity: bestClarity,
            timestamp: Date()
        )
    }
    
    // MARK: - Tone Generation (Reference Pitch Sound)
    private func setupToneEngine() {
        guard toneEngine == nil else { return }
        
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let actualRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000.0
        
        let sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            
            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0
                if self.isToneActive && self.toneAmplitude > 0.001 {
                    let twoPi = 2.0 * Double.pi
                    let f = self.toneFrequency
                    let t = self.tonePhase
                    
                    let fund = sin(twoPi * f * t)
                    let harm2 = 0.35 * sin(twoPi * 2.0 * f * t)
                    let harm3 = 0.15 * sin(twoPi * 3.0 * f * t)
                    let harm4 = 0.06 * sin(twoPi * 4.0 * f * t)
                    
                    sample = Float((fund + harm2 + harm3 + harm4) * self.toneAmplitude * 0.4)
                    
                    self.tonePhase += 1.0 / actualRate
                    self.toneAmplitude *= exp(-self.toneDecayRate / actualRate)
                }
                
                for buffer in ablPointer {
                    let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                    buf[frame] = sample
                }
            }
            return noErr
        }
        
        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mainMixer, format: outputFormat)
        
        do {
            try engine.start()
            self.toneEngine = engine
            self.toneSourceNode = sourceNode
        } catch {
            print("Could not start tone engine: \(error.localizedDescription)")
        }
    }
    
    private func stopToneEngine() {
        toneTimer?.invalidate()
        toneTimer = nil
        isToneActive = false
        toneEngine?.stop()
        toneEngine = nil
        toneSourceNode = nil
    }
    
    public func playTone(frequency: Double, isPluck: Bool = true) {
        if toneEngine == nil {
            setupToneEngine()
        }
        
        toneTimer?.invalidate()
        toneFrequency = frequency
        tonePhase = 0.0
        toneAmplitude = 0.85
        toneDecayRate = isPluck ? 1.6 : 0.0001
        isToneActive = true
        
        if isPluck {
            toneTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.isToneActive = false
                }
            }
        }
    }
    
    public func stopTone() {
        toneTimer?.invalidate()
        toneTimer = nil
        isToneActive = false
        toneAmplitude = 0.0
    }
    
    // MARK: - Simulator Mock Pluck
    public func simulatePluck(frequency: Double, centsOffset: Double = 0.0) {
        let simulatedFreq = frequency * pow(2.0, centsOffset / 1200.0)
        self.currentAmplitude = 0.35
        self.currentFrequency = simulatedFreq
        self.smoothedFrequency = simulatedFreq
        self.isPluckDetected = true
        self.silenceFramesCount = 0
        
        playTone(frequency: simulatedFreq, isPluck: true)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            self.isPluckDetected = false
        }
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if self.currentFrequency == simulatedFreq {
                self.currentFrequency = nil
                self.smoothedFrequency = nil
                self.currentAmplitude = 0.0
            }
        }
    }
}
