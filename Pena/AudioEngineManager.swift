import Foundation
import AVFoundation
import Accelerate
import Observation
#if os(iOS)
import UIKit
#endif

// MARK: - Real-time-safe Rolling Window Buffer
/// Fixed-capacity rolling window guarded by a spinlock. `append` runs on the real-time audio
/// render thread and only ever copies bytes (memmove/memcpy) into buffers that are allocated
/// once, up front — it never allocates, so it can never stall the render deadline the way the
/// original per-callback `[Float](repeating:...)` allocations + O(n·m) DSP work used to.
private nonisolated final class RollingWindowBuffer: @unchecked Sendable {
    private let capacity: Int
    private var ring: [Float]
    private var filled = 0
    private var lock = os_unfair_lock()

    init(capacity: Int) {
        self.capacity = capacity
        self.ring = [Float](repeating: 0, count: capacity)
    }

    /// Copies `sampleCount` new samples in, then — if the window is fully populated —
    /// copies the current window into the caller-owned `output` buffer (which must already
    /// be sized to `capacity`) and returns `true`. `output` is never allocated here.
    @discardableResult
    func append(samples: UnsafePointer<Float>, sampleCount: Int, into output: inout [Float]) -> Bool {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }

        ring.withUnsafeMutableBufferPointer { dst in
            let base = dst.baseAddress!
            if sampleCount >= capacity {
                base.update(from: samples.advanced(by: sampleCount - capacity), count: capacity)
                filled = capacity
            } else {
                let keep = capacity - sampleCount
                memmove(base, base.advanced(by: sampleCount), keep * MemoryLayout<Float>.stride)
                base.advanced(by: keep).update(from: samples, count: sampleCount)
                filled = min(capacity, filled + sampleCount)
            }
        }

        guard filled >= capacity else { return false }
        ring.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                dst.baseAddress!.update(from: src.baseAddress!, count: capacity)
            }
        }
        return true
    }

    func reset() {
        os_unfair_lock_lock(&lock)
        filled = 0
        os_unfair_lock_unlock(&lock)
    }
}

// MARK: - Real-time-safe Reference Tone State
/// Holds the reference-tone oscillator state behind a spinlock instead of letting the
/// `AVAudioSourceNode` render callback read/write `@MainActor`-isolated stored properties
/// directly from the audio thread (a genuine data race the previous implementation had).
private nonisolated final class ToneStateBox: @unchecked Sendable {
    private var isActive = false
    private var frequency: Double = 0
    private var amplitude: Double = 0
    private var decayRate: Double = 1.5
    private var phase: Double = 0
    private var lock = os_unfair_lock()

    func start(frequency: Double, decayRate: Double) {
        os_unfair_lock_lock(&lock)
        self.isActive = true
        self.frequency = frequency
        self.amplitude = 0.85
        self.decayRate = decayRate
        self.phase = 0
        os_unfair_lock_unlock(&lock)
    }

    func stop() {
        os_unfair_lock_lock(&lock)
        isActive = false
        amplitude = 0
        os_unfair_lock_unlock(&lock)
    }

    /// Called from the render thread only; produces one sample and advances the envelope.
    func nextSample(sampleRate: Double) -> Float {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        guard isActive, amplitude > 0.001 else { return 0 }

        let twoPi = 2.0 * Double.pi
        let fund = sin(twoPi * frequency * phase)
        let harm2 = 0.35 * sin(twoPi * 2.0 * frequency * phase)
        let harm3 = 0.15 * sin(twoPi * 3.0 * frequency * phase)
        let harm4 = 0.06 * sin(twoPi * 4.0 * frequency * phase)
        let sample = Float((fund + harm2 + harm3 + harm4) * amplitude * 0.4)

        phase += 1.0 / sampleRate
        amplitude *= exp(-decayRate / sampleRate)
        return sample
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
    public private(set) var smoothedFrequency: Double? = nil
    public private(set) var currentAmplitude: Float = 0.0
    public private(set) var currentClarity: Double = 0.0
    public private(set) var isPluckDetected: Bool = false
    public private(set) var lastErrorMessage: String? = nil

    // User Settings
    // Default threshold set to catch acoustic classical guitar without catching ambient noise.
    public var noiseGateThreshold: Float = 0.006 {
        didSet { noiseGateThresholdBox = noiseGateThreshold }
    }
    /// Valid pitch range for the currently active tuning. Narrowing this to the active
    /// preset's actual string range (with a little headroom) instead of a fixed constant
    /// meaningfully cuts down false-positive detections from room noise and voice.
    public var frequencyRange: ClosedRange<Double> = 60.0...440.0 {
        didSet { frequencyRangeBox = frequencyRange }
    }

    // MARK: Real-time-safe shared state
    // Everything below is read from the audio render thread and/or the background analysis
    // queue, never only through MainActor. Plain scalar reads/writes are not linearizable by
    // the Swift memory model, but a torn read here only ever yields a stale value for a
    // single ~20ms audio frame of a tuning meter — never a crash — so a lock isn't worth
    // paying on every render callback. Mutable buffers that DSP code writes into are only
    // ever touched from the single serial audio thread (never concurrently), so they're safe
    // without a lock too.
    nonisolated(unsafe) private var noiseGateThresholdBox: Float = 0.006
    nonisolated(unsafe) private var frequencyRangeBox: ClosedRange<Double> = 60.0...440.0
    nonisolated(unsafe) private var isSuppressingToneAnalysis = false
    nonisolated(unsafe) private var snapshotA = [Float](repeating: 0, count: PitchDetector.windowSize)
    nonisolated(unsafe) private var snapshotB = [Float](repeating: 0, count: PitchDetector.windowSize)
    nonisolated(unsafe) private var useSnapshotA = true
    private let pitchDetector = PitchDetector()
    private let pitchStabilizer = PitchStabilizer()
    private let toneBox = ToneStateBox()
    private let micWindow = RollingWindowBuffer(capacity: PitchDetector.windowSize)
    private let analysisQueue = DispatchQueue(label: "pena.pitch-analysis", qos: .userInteractive)

    // Audio engine components — a single engine drives both the microphone tap and the
    // reference-tone output, instead of the two independent engines the app used to spin up.
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var toneSourceNode: AVAudioSourceNode?
    @ObservationIgnored private var toneStopTask: Task<Void, Never>?
    @ObservationIgnored private var pluckClearTask: Task<Void, Never>?
    @ObservationIgnored private var wasRunningBeforeInterruption = false

    public override init() {
        super.init()
        checkMicrophonePermission()
        #if os(iOS)
        registerForSessionNotifications()
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Permission Handling
    public func checkMicrophonePermission() {
        #if os(iOS)
        let status = AVAudioApplication.shared.recordPermission
        self.hasMicrophonePermission = (status == .granted)
        self.permissionRequested = (status != .undetermined)
        #endif
    }

    public func requestMicrophonePermission(completion: @escaping (Bool) -> Void = { _ in }) {
        #if os(iOS)
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor in
                self?.hasMicrophonePermission = granted
                self?.permissionRequested = true
                completion(granted)
            }
        }
        #else
        completion(false)
        #endif
    }

    // MARK: - Session Configuration
    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // `.measurement` disables system AGC/EQ so the mic signal reaches our detector
        // unprocessed. `.allowBluetoothA2DP` (not `.allowBluetooth`/HFP) lets audio route to
        // a Bluetooth speaker without downgrading the *input* to a 16kHz phone-call mic.
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
    }

    #if os(iOS)
    private func registerForSessionNotifications() {
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        center.addObserver(self, selector: #selector(handleMediaServicesReset(_:)), name: AVAudioSession.mediaServicesWereResetNotification, object: nil)
    }

    @objc private nonisolated func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        let optionsValue = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
        let shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.wasRunningBeforeInterruption = self.isRunning
                if self.isRunning { self.stop() }
            case .ended:
                if shouldResume && self.wasRunningBeforeInterruption {
                    self.start()
                }
            @unknown default:
                break
            }
        }
    }

    /// A route change (headphones plugged/unplugged, Bluetooth connect/disconnect) can leave
    /// the engine's input/output formats stale. Fully restarting on the new route is far more
    /// robust than trying to patch the running graph in place.
    @objc private nonisolated func handleRouteChange(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self, self.isRunning else { return }
            self.stop()
            self.start()
        }
    }

    @objc private nonisolated func handleMediaServicesReset(_ notification: Notification) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let wasRunning = self.isRunning
            self.engine = nil
            self.toneSourceNode = nil
            self.isRunning = false
            if wasRunning { self.start() }
        }
    }
    #endif

    // MARK: - Start / Stop Audio Engine
    public func start() {
        guard !isRunning else { return }

        do {
            try configureAudioSession()
        } catch {
            lastErrorMessage = "Ses oturumu yapılandırılamadı: \(error.localizedDescription)"
            return
        }

        let activeEngine = engine ?? AVAudioEngine()
        if toneSourceNode == nil {
            attachToneSourceNode(to: activeEngine)
        }

        let inputNode = activeEngine.inputNode
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { [weak self] buffer, _ in
            self?.handleTapBuffer(buffer)
        }

        do {
            if !activeEngine.isRunning {
                try activeEngine.start()
            }
            engine = activeEngine
            isRunning = true
            lastErrorMessage = nil
            micWindow.reset()
            pitchStabilizer.reset()
        } catch {
            lastErrorMessage = "Ses motoru başlatılamadı: \(error.localizedDescription)"
            isRunning = false
            return
        }

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    public func stop() {
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        engine = nil
        toneSourceNode = nil
        toneBox.stop()
        toneStopTask?.cancel()
        pluckClearTask?.cancel()
        micWindow.reset()
        pitchStabilizer.reset()
        isSuppressingToneAnalysis = false

        isRunning = false
        smoothedFrequency = nil
        currentAmplitude = 0.0
        currentClarity = 0.0
        isPluckDetected = false

        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - Incoming Audio Buffer Handling
    /// Runs on the real-time audio render thread: only copies samples and hands off to the
    /// background `analysisQueue` for the actual YIN math, so heavy DSP never competes with
    /// the render deadline.
    nonisolated private func handleTapBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        var rawRms: Float = 0
        vDSP_rmsqv(channelData, 1, &rawRms, vDSP_Length(frameCount))
        let rms = rawRms

        guard !isSuppressingToneAnalysis else {
            Task { @MainActor [weak self] in self?.currentAmplitude = 0 }
            return
        }

        let sampleRate = buffer.format.sampleRate > 0 ? buffer.format.sampleRate : 48000.0
        let didFill: Bool
        if useSnapshotA {
            didFill = micWindow.append(samples: channelData, sampleCount: frameCount, into: &snapshotA)
        } else {
            didFill = micWindow.append(samples: channelData, sampleCount: frameCount, into: &snapshotB)
        }

        guard didFill else {
            Task { @MainActor [weak self] in self?.currentAmplitude = rms }
            return
        }

        let snapshot = useSnapshotA ? snapshotA : snapshotB
        useSnapshotA.toggle()

        let range = frequencyRangeBox
        let gate = noiseGateThresholdBox
        let config = PitchDetectorConfig(minFrequency: range.lowerBound, maxFrequency: range.upperBound)
        let detector = pitchDetector
        let stabilizer = pitchStabilizer

        analysisQueue.async { [weak self] in
            let result = detector.detectPitch(samples: snapshot, sampleRate: sampleRate, rms: rms, config: config)
            let reading = stabilizer.ingest(result, rms: rms, noiseGateAmplitude: gate)
            Task { @MainActor in
                self?.apply(reading: reading)
            }
        }
    }

    private func apply(reading: TunerReading) {
        currentAmplitude = reading.amplitude
        currentClarity = reading.clarity
        smoothedFrequency = reading.frequency

        guard reading.isOnset else { return }
        isPluckDetected = true
        pluckClearTask?.cancel()
        pluckClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            self?.isPluckDetected = false
        }
    }

    // MARK: - Tone Generation (Reference Pitch Sound)
    private func attachToneSourceNode(to engine: AVAudioEngine) {
        let mainMixer = engine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)
        let sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 48000.0
        let toneBox = self.toneBox

        // Captures only Sendable value/reference types below — no `self` — so this render
        // callback never touches MainActor-isolated state.
        let sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                let sample = toneBox.nextSample(sampleRate: sampleRate)
                for buffer in ablPointer {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sample
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: mainMixer, format: outputFormat)
        self.toneSourceNode = sourceNode
    }

    public func playTone(frequency: Double, isPluck: Bool = true) {
        let activeEngine = engine ?? AVAudioEngine()
        if toneSourceNode == nil {
            attachToneSourceNode(to: activeEngine)
        }
        if !activeEngine.isRunning {
            do {
                if engine == nil { try configureAudioSession() }
                try activeEngine.start()
                engine = activeEngine
            } catch {
                lastErrorMessage = "Referans ton çalınamadı: \(error.localizedDescription)"
                return
            }
        }

        toneStopTask?.cancel()
        isSuppressingToneAnalysis = true
        toneBox.start(frequency: frequency, decayRate: isPluck ? 1.6 : 0.0001)

        if isPluck {
            toneStopTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                guard !Task.isCancelled else { return }
                self?.toneBox.stop()
                self?.isSuppressingToneAnalysis = false
            }
        }
    }

    public func stopTone() {
        toneStopTask?.cancel()
        toneBox.stop()
        isSuppressingToneAnalysis = false
    }

    // MARK: - Simulator / DEBUG Mock Pluck
    // Only compiled into DEBUG builds: this drives the on-device developer test panel and
    // must never ship in the App Store build.
    #if DEBUG
    public func simulatePluck(frequency: Double, centsOffset: Double = 0.0) {
        let simulatedFreq = frequency * pow(2.0, centsOffset / 1200.0)
        let sampleRate = 48000.0
        let synthetic = Self.syntheticPluckSamples(frequency: simulatedFreq, sampleRate: sampleRate, count: PitchDetector.windowSize)
        let config = PitchDetectorConfig(minFrequency: max(30.0, simulatedFreq * 0.5), maxFrequency: simulatedFreq * 2.0)

        // Exercises the exact same detector used for real microphone input, rather than
        // faking the UI fields directly, so this panel actually validates production code.
        guard let result = pitchDetector.detectPitch(samples: synthetic, sampleRate: sampleRate, rms: 0.35, config: config) else { return }

        currentAmplitude = result.amplitude
        currentClarity = result.clarity
        smoothedFrequency = result.frequency
        isPluckDetected = true
        pluckClearTask?.cancel()
        pluckClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            self?.isPluckDetected = false
        }

        playTone(frequency: simulatedFreq, isPluck: true)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard let self, self.smoothedFrequency == result.frequency else { return }
            self.smoothedFrequency = nil
            self.currentAmplitude = 0.0
            self.currentClarity = 0.0
        }
    }

    private static func syntheticPluckSamples(frequency: Double, sampleRate: Double, count: Int) -> [Float] {
        var samples = [Float](repeating: 0, count: count)
        let twoPi = 2.0 * Double.pi
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let fund = sin(twoPi * frequency * t)
            let harm2 = 0.5 * sin(twoPi * 2.0 * frequency * t)
            let harm3 = 0.25 * sin(twoPi * 3.0 * frequency * t)
            samples[i] = Float((fund + harm2 + harm3) * 0.3)
        }
        return samples
    }
    #endif
}
