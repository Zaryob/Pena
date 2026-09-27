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
    private let capacity = 2048
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
    public private(set) var currentClarity: Double = 0.0
    public private(set) var isPluckDetected: Bool = false
    public private(set) var lastErrorMessage: String? = nil
    
    // User Settings
    // Default threshold set to 0.006 to catch acoustic classical guitar without catching ambient noise
    public var noiseGateThreshold: Float = 0.006
    public var a4Calibration: Double = 440.0
    
    // Audio engine components
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var toneEngine: AVAudioEngine?
    @ObservationIgnored private var toneSourceNode: AVAudioSourceNode?
    @ObservationIgnored private let accumulator = AudioBufferAccumulator()
    
    // Internal pitch detection variables
    @ObservationIgnored private var sampleRate: Double = 48000.0
    @ObservationIgnored private var silenceFramesCount = 0
    @ObservationIgnored private var persistenceTimer: Task<Void, Never>?
    
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
            try audioSession.setPreferredIOBufferDuration(0.01)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioSession setup error: \(error.localizedDescription)")
            self.lastErrorMessage = error.localizedDescription
        }
        #endif
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        
        inputNode.removeTap(onBus: 0)
        let accumulatorRef = self.accumulator
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
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
        persistenceTimer?.cancel()
        accumulator.reset()
        self.isRunning = false
        self.currentFrequency = nil
        self.smoothedFrequency = nil
        self.currentAmplitude = 0.0
        self.currentClarity = 0.0
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
        
        // Run Accelerated YIN Pitch Detection
        let pitchResult = detectPitchYIN(
            samples: centeredSamples,
            count: currentCount,
            sampleRate: actualSampleRate,
            rms: rms
        )
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentAmplitude = rms
            
            // If below noise threshold or no musical pitch found:
            guard rms >= self.noiseGateThreshold, let detected = pitchResult else {
                self.silenceFramesCount += 1
                // Allow sound to sustain for ~800ms before clearing display
                if self.silenceFramesCount > 35 {
                    self.currentFrequency = nil
                    self.smoothedFrequency = nil
                    self.currentClarity = 0.0
                }
                return
            }
            
            self.silenceFramesCount = 0
            self.currentClarity = detected.clarity
            let freq = detected.frequency
            
            // Guitar frequency range check: 68 Hz to 380 Hz (6 classical guitar open strings)
            guard freq >= 68.0 && freq <= 380.0 else {
                return
            }
            
            // Smooth tracking
            if let prev = self.smoothedFrequency {
                let semitoneDiff = abs(12.0 * log2(freq / prev))
                if semitoneDiff > 1.2 {
                    // Jump to new string
                    self.smoothedFrequency = freq
                    self.isPluckDetected = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        self.isPluckDetected = false
                    }
                } else {
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
    
    // MARK: - Accelerated YIN Pitch Detection (vDSP)
    nonisolated private func detectPitchYIN(
        samples: [Float],
        count: Int,
        sampleRate: Double,
        rms: Float
    ) -> PitchDetectionResult? {
        // Guitar pitch bounds: 65 Hz to 420 Hz
        let minFreq = 65.0
        let maxFreq = 420.0
        
        let minPeriod = max(10, Int(sampleRate / maxFreq))
        let maxPeriod = min(count / 2, Int(sampleRate / minFreq))
        let windowSize = count - maxPeriod
        
        guard maxPeriod > minPeriod, windowSize > 0 else { return nil }
        
        // 1. Initial energy of window
        var energy0: Float = 0.0
        vDSP_svesq(samples, 1, &energy0, vDSP_Length(windowSize))
        
        // 2. Cross-correlation using vDSP_conv
        var xcorr = [Float](repeating: 0, count: maxPeriod)
        samples.withUnsafeBufferPointer { ptr in
            let s = ptr.baseAddress!
            vDSP_conv(s, 1, s, 1, &xcorr, 1, vDSP_Length(maxPeriod), vDSP_Length(windowSize))
        }
        
        // 3. Difference function d(tau) = energy0 + energy(tau) - 2 * xcorr(tau)
        var d = [Float](repeating: 0, count: maxPeriod)
        for tau in 1..<maxPeriod {
            var energyTau: Float = 0.0
            samples.withUnsafeBufferPointer { ptr in
                vDSP_svesq(ptr.baseAddress!.advanced(by: tau), 1, &energyTau, vDSP_Length(windowSize))
            }
            let diff = energy0 + energyTau - 2.0 * xcorr[tau]
            d[tau] = max(0.0, diff)
        }
        
        // 4. Cumulative Mean Normalized Difference Function (CMNDF)
        var cmndf = [Float](repeating: 1.0, count: maxPeriod)
        var runningSum: Float = 0.0
        for tau in 1..<maxPeriod {
            runningSum += d[tau]
            if runningSum > 1e-6 {
                cmndf[tau] = d[tau] / (runningSum / Float(tau))
            } else {
                cmndf[tau] = 1.0
            }
        }
        
        // 5. Absolute thresholding (YIN threshold: 0.20 for guitar)
        let threshold: Float = 0.20
        var bestTau: Int? = nil
        for tau in minPeriod..<maxPeriod {
            if cmndf[tau] < threshold {
                var localMin = tau
                while localMin + 1 < maxPeriod && cmndf[localMin + 1] < cmndf[localMin] {
                    localMin += 1
                }
                bestTau = localMin
                break
            }
        }
        
        // Fallback: If no dip below 0.20, find the global minimum in range if it's below 0.35
        if bestTau == nil {
            var minVal: Float = 1.0
            var minTau: Int? = nil
            for tau in minPeriod..<maxPeriod {
                if cmndf[tau] < minVal {
                    minVal = cmndf[tau]
                    minTau = tau
                }
            }
            if minVal < 0.35, let mt = minTau {
                bestTau = mt
            }
        }
        
        guard let tau = bestTau else { return nil }
        
        // 6. Parabolic interpolation for sub-Hz precision
        var refinedTau = Double(tau)
        if tau > 0 && tau + 1 < maxPeriod {
            let y1 = Double(cmndf[tau - 1])
            let y2 = Double(cmndf[tau])
            let y3 = Double(cmndf[tau + 1])
            let denom = 2.0 * (2.0 * y2 - y1 - y3)
            if denom != 0.0 {
                refinedTau += (y3 - y1) / denom
            }
        }
        
        guard refinedTau > 0 else { return nil }
        let frequency = sampleRate / refinedTau
        let clarity = Double(1.0 - cmndf[tau])
        
        return PitchDetectionResult(
            frequency: frequency,
            amplitude: rms,
            clarity: max(0.0, clarity),
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
        self.currentClarity = 0.95
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
                self.currentClarity = 0.0
            }
        }
    }
}
