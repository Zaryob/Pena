import Foundation
import AVFoundation
import Accelerate
import Observation

// MARK: - Pitch Detection Result
public struct PitchDetectionResult: Equatable {
    public let frequency: Double
    public let amplitude: Float
    public let clarity: Double // 0.0 to 1.0 (confidence)
    public let timestamp: Date
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
    
    // User Settings
    public var noiseGateThreshold: Float = 0.012
    public var a4Calibration: Double = 440.0
    
    // Audio engine components
    @ObservationIgnored private var audioEngine: AVAudioEngine?
    @ObservationIgnored private var toneEngine: AVAudioEngine?
    @ObservationIgnored private var toneSourceNode: AVAudioSourceNode?
    
    // Internal pitch detection variables
    @ObservationIgnored private var sampleRate: Double = 44100.0
    @ObservationIgnored private let bufferSize: AVAudioFrameCount = 4096
    @ObservationIgnored private var lastRawFrequency: Double? = nil
    @ObservationIgnored private var pluckCooldown: Double = 0.0
    
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
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setPreferredSampleRate(44100.0)
            try audioSession.setPreferredIOBufferDuration(0.02)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Audio session configuration error: \(error.localizedDescription)")
        }
        #endif
        
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        let actualSampleRate = (format.sampleRate > 0) ? format.sampleRate : 44100.0
        self.sampleRate = actualSampleRate
        
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, sampleRate: actualSampleRate)
        }
        
        do {
            try engine.start()
            self.audioEngine = engine
            self.isRunning = true
            setupToneEngine()
        } catch {
            print("Failed to start audio engine: \(error.localizedDescription)")
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
        self.isRunning = false
        self.currentFrequency = nil
        self.smoothedFrequency = nil
        self.currentAmplitude = 0.0
    }
    
    // MARK: - Audio Processing & Pitch Extraction
    nonisolated private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount >= 1024 else { return }
        
        // Calculate RMS amplitude using Accelerate vDSP
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
        
        // Detect pitch using McLeod Pitch Method (NSDF)
        let pitchResult = detectPitchMcLeod(samples: channelData, count: frameCount, sampleRate: sampleRate, rms: rms)
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentAmplitude = rms
            
            // Check noise threshold
            if rms < self.noiseGateThreshold || pitchResult == nil {
                if self.pluckCooldown > 0 {
                    self.pluckCooldown -= 0.05
                } else {
                    self.currentFrequency = nil
                    self.smoothedFrequency = nil
                }
                return
            }
            
            guard let detected = pitchResult else { return }
            let freq = detected.frequency
            
            // Pluck detection / smoothing
            if let prev = self.smoothedFrequency {
                let semitoneDiff = abs(12.0 * log2(freq / prev))
                if semitoneDiff > 1.5 {
                    // Sudden jump: user hit a new string!
                    self.smoothedFrequency = freq
                    self.isPluckDetected = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        self.isPluckDetected = false
                    }
                } else {
                    // Smooth tracking for steady needle
                    let alpha = 0.30
                    self.smoothedFrequency = prev * (1.0 - alpha) + freq * alpha
                }
            } else {
                self.smoothedFrequency = freq
                self.isPluckDetected = true
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 150_000_000)
                    self.isPluckDetected = false
                }
            }
            
            self.currentFrequency = freq
            self.pluckCooldown = 0.4
        }
    }
    
    // MARK: - McLeod Pitch Method (NSDF Pitch Detection)
    nonisolated private func detectPitchMcLeod(samples: UnsafePointer<Float>, count: Int, sampleRate: Double, rms: Float) -> PitchDetectionResult? {
        let minFreq = 65.0
        let maxFreq = 750.0
        
        let minPeriod = Int(sampleRate / maxFreq) // e.g. ~58 samples
        let maxPeriod = Int(sampleRate / minFreq) // e.g. ~678 samples
        
        guard count > maxPeriod * 2 else { return nil }
        let windowSize = count - maxPeriod
        
        // Compute Normalized Square Difference Function (NSDF)
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
            if denom > 1e-9 {
                nsdf[tau] = (2.0 * sumCross) / denom
            } else {
                nsdf[tau] = 0.0
            }
        }
        
        // Find local maxima with threshold
        var maxVal = -1.0
        for tau in minPeriod...maxPeriod {
            if nsdf[tau] > maxVal {
                maxVal = nsdf[tau]
            }
        }
        
        guard maxVal > 0.45 else { return nil }
        
        let threshold = maxVal * 0.85
        var bestTau: Double? = nil
        var bestClarity: Double = 0.0
        
        for tau in (minPeriod + 1)..<maxPeriod {
            if nsdf[tau] > nsdf[tau - 1] && nsdf[tau] >= nsdf[tau + 1] && nsdf[tau] >= threshold {
                let y1 = nsdf[tau - 1]
                let y2 = nsdf[tau]
                let y3 = nsdf[tau + 1]
                
                let denom = 2.0 * (2.0 * y2 - y1 - y3)
                let delta = (denom != 0.0) ? (y3 - y1) / denom : 0.0
                
                let refinedPeriod = Double(tau) + delta
                if refinedPeriod > 0 {
                    bestTau = refinedPeriod
                    bestClarity = y2
                    break
                }
            }
        }
        
        guard let period = bestTau, period > 0 else { return nil }
        let frequency = sampleRate / period
        
        guard frequency >= minFreq && frequency <= maxFreq else { return nil }
        
        return PitchDetectionResult(frequency: frequency, amplitude: rms, clarity: bestClarity, timestamp: Date())
    }
    
    // MARK: - Tone Generation (Reference Pitch Sound)
    private func setupToneEngine() {
        guard toneEngine == nil else { return }
        
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let actualRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100.0
        
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
    
    // MARK: - Simulator / Demo Mock Pluck
    public func simulatePluck(frequency: Double, centsOffset: Double = 0.0) {
        let simulatedFreq = frequency * pow(2.0, centsOffset / 1200.0)
        self.currentAmplitude = 0.35
        self.currentFrequency = simulatedFreq
        self.smoothedFrequency = simulatedFreq
        self.isPluckDetected = true
        self.pluckCooldown = 1.5
        
        playTone(frequency: simulatedFreq, isPluck: true)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
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
