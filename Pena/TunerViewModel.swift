import Foundation
import SwiftUI
import Observation

public enum TuningMode: String, CaseIterable, Identifiable, Codable {
    case auto
    case manual

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .manual: return "hand.tap.fill"
        }
    }

    public var displayName: String {
        switch self {
        case .auto: return String(localized: "tuning_mode.auto", defaultValue: "Otomatik")
        case .manual: return String(localized: "tuning_mode.manual", defaultValue: "Manuel")
        }
    }
}

public enum NotationStyle: String, CaseIterable, Identifiable, Codable {
    case letter
    case solfege

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .letter: return String(localized: "notation_style.letter", defaultValue: "Harf (E A D G B E)")
        case .solfege: return String(localized: "notation_style.solfege", defaultValue: "Solfej (Mi La Re Sol Si Mi)")
        }
    }
}

/// Three simple presets instead of a raw amplitude slider — most players can judge "how loud
/// is my room" far more reliably than "what RMS threshold do I want", and this maps directly
/// onto `AudioEngineManager.noiseGateThreshold`.
public enum ListeningSensitivity: String, CaseIterable, Identifiable, Codable {
    case quiet
    case normal
    case noisy

    public var id: String { rawValue }

    public var noiseGateThreshold: Float {
        switch self {
        case .quiet: return 0.004
        case .normal: return 0.008
        case .noisy: return 0.018
        }
    }

    public var displayName: String {
        switch self {
        case .quiet: return String(localized: "sensitivity.quiet", defaultValue: "Sessiz Ortam")
        case .normal: return String(localized: "sensitivity.normal", defaultValue: "Normal")
        case .noisy: return String(localized: "sensitivity.noisy", defaultValue: "Gürültülü Ortam")
        }
    }
}

@MainActor
@Observable
public final class TunerViewModel {
    // Dependencies
    public let audioManager: AudioEngineManager

    // Core Configuration
    public var currentPreset: TuningPreset = .standard {
        didSet {
            guard oldValue.id != currentPreset.id else { return }
            if let match = currentPreset.strings.first(where: { $0.id == selectedString.id }) {
                selectedString = match
            } else if let first = currentPreset.strings.first {
                selectedString = first
            }
            lastConfirmedString = nil
            pendingStringCandidate = nil
            pendingStringCandidateCount = 0
            tunedStringIDs.removeAll()
            updateAudioFrequencyRange()
            UserDefaults.standard.set(currentPreset.id, forKey: DefaultsKey.presetID)
        }
    }

    public var tuningMode: TuningMode = .auto {
        didSet {
            UserDefaults.standard.set(tuningMode.rawValue, forKey: DefaultsKey.tuningMode)
        }
    }
    public var selectedString: GuitarString
    public private(set) var lastConfirmedString: GuitarString? = nil
    /// String IDs that have held an in-tune reading for this session — drives the headstock
    /// checkmarks so players can see their progress across all 6 strings.
    public private(set) var tunedStringIDs: Set<Int> = []

    public var notationStyle: NotationStyle = .letter {
        didSet {
            UserDefaults.standard.set(notationStyle.rawValue, forKey: DefaultsKey.notationStyle)
        }
    }
    public var a4Frequency: Double = 440.0 {
        didSet {
            updateAudioFrequencyRange()
            UserDefaults.standard.set(a4Frequency, forKey: DefaultsKey.a4Frequency)
        }
    }
    public var inTuneTolerance: Double = 3.0 { // cents
        didSet {
            UserDefaults.standard.set(inTuneTolerance, forKey: DefaultsKey.inTuneTolerance)
        }
    }
    public var sensitivity: ListeningSensitivity = .normal {
        didSet {
            audioManager.noiseGateThreshold = sensitivity.noiseGateThreshold
            UserDefaults.standard.set(sensitivity.rawValue, forKey: DefaultsKey.sensitivity)
        }
    }
    public var noiseGateThreshold: Float {
        get { audioManager.noiseGateThreshold }
        set { audioManager.noiseGateThreshold = newValue }
    }

    // UI Helpers
    public var isSettingsPresented: Bool = false
    public var isSimulatorSheetPresented: Bool = false
    public var isPlayingReferenceTone: Bool = false
    public var lastInTuneHapticTime: Date = .distantPast

    // Auto-detection hysteresis state (see `updateAutoDetection`)
    @ObservationIgnored private var pendingStringCandidate: GuitarString? = nil
    @ObservationIgnored private var pendingStringCandidateCount = 0
    @ObservationIgnored private var inTuneStabilityTask: Task<Void, Never>?

    private enum DefaultsKey {
        static let presetID = "pena.presetID"
        static let tuningMode = "pena.tuningMode"
        static let notationStyle = "pena.notationStyle"
        static let a4Frequency = "pena.a4Frequency"
        static let inTuneTolerance = "pena.inTuneTolerance"
        static let sensitivity = "pena.sensitivity"
    }

    public init(audioManager: AudioEngineManager? = nil) {
        let manager = audioManager ?? AudioEngineManager()
        self.audioManager = manager

        let defaults = UserDefaults.standard
        let preset = defaults.string(forKey: DefaultsKey.presetID).flatMap { id in
            TuningPreset.allPresets.first { $0.id == id }
        } ?? .standard
        // `selectedString` must be assigned before `currentPreset`, since currentPreset's
        // didSet re-matches it against the new preset's strings.
        self.selectedString = TuningPreset.standard.strings.first { $0.id == 6 }!
        self.currentPreset = preset
        if let modeRaw = defaults.string(forKey: DefaultsKey.tuningMode), let mode = TuningMode(rawValue: modeRaw) {
            self.tuningMode = mode
        }
        if let notationRaw = defaults.string(forKey: DefaultsKey.notationStyle), let notation = NotationStyle(rawValue: notationRaw) {
            self.notationStyle = notation
        }
        if defaults.object(forKey: DefaultsKey.a4Frequency) != nil {
            self.a4Frequency = defaults.double(forKey: DefaultsKey.a4Frequency)
        }
        if defaults.object(forKey: DefaultsKey.inTuneTolerance) != nil {
            self.inTuneTolerance = defaults.double(forKey: DefaultsKey.inTuneTolerance)
        }
        if let sensitivityRaw = defaults.string(forKey: DefaultsKey.sensitivity), let level = ListeningSensitivity(rawValue: sensitivityRaw) {
            self.sensitivity = level
        }

        manager.noiseGateThreshold = sensitivity.noiseGateThreshold
        updateAudioFrequencyRange()
    }

    // MARK: - Active String Identification
    /// Pure read of the currently active string — no side effects. Auto-mode detection is
    /// driven explicitly by `ingest(_:)` / `updateAutoDetection(frequency:)`, called in
    /// response to audio analysis, instead of mutating state from inside this getter.
    public var activeString: GuitarString {
        switch tuningMode {
        case .manual:
            return selectedString
        case .auto:
            return lastConfirmedString ?? selectedString
        }
    }

    /// Ingests a new reading from the audio pipeline: drives auto string matching and
    /// evaluates in-tune stability without side-effects in property getters.
    public func ingest(_ reading: TunerReading) {
        updateAutoDetection(frequency: reading.frequency)
        handleTuningStatusChange()
    }

    /// Finds the closest string to `frequency` in the current preset and, in auto mode,
    /// updates `selectedString`/`lastConfirmedString`. A candidate must be clearly closer
    /// (by at least 40 cents) than the current string and hold for a couple of frames before
    /// the display switches, so it doesn't flicker between two adjacent strings.
    public func updateAutoDetection(frequency: Double?) {
        guard tuningMode == .auto, let freq = frequency else { return }

        var closestString: GuitarString? = nil
        var minCents = Double.infinity
        for string in currentPreset.strings {
            let cents = abs(1200.0 * log2(freq / string.targetFrequency(a4: a4Frequency)))
            if cents < minCents {
                minCents = cents
                closestString = string
            }
        }
        // Ignore anything more than ~220 cents from any real string (speech, room noise, etc.)
        guard minCents <= 220.0, let matched = closestString else { return }

        guard let current = lastConfirmedString else {
            commitAutoString(matched)
            return
        }
        guard matched.id != current.id else {
            pendingStringCandidate = nil
            pendingStringCandidateCount = 0
            return
        }

        let currentCents = abs(1200.0 * log2(freq / current.targetFrequency(a4: a4Frequency)))
        guard currentCents - minCents > 40.0 else {
            pendingStringCandidate = nil
            pendingStringCandidateCount = 0
            return
        }

        if pendingStringCandidate?.id == matched.id {
            pendingStringCandidateCount += 1
        } else {
            pendingStringCandidate = matched
            pendingStringCandidateCount = 1
        }

        if pendingStringCandidateCount >= 2 {
            commitAutoString(matched)
        }
    }

    private func commitAutoString(_ string: GuitarString) {
        lastConfirmedString = string
        selectedString = string
        pendingStringCandidate = nil
        pendingStringCandidateCount = 0
    }

    private func updateAudioFrequencyRange() {
        let semitoneMargin = 4.0
        let frequencies = currentPreset.strings.map { $0.targetFrequency(a4: a4Frequency) }
        guard let minFreq = frequencies.min(), let maxFreq = frequencies.max() else { return }
        let lower = minFreq * pow(2.0, -semitoneMargin / 12.0)
        let upper = maxFreq * pow(2.0, semitoneMargin / 12.0)
        audioManager.frequencyRange = lower...upper
    }

    // MARK: - Pitch Metrics & Validation
    public var detectedFrequency: Double? {
        guard let freq = audioManager.smoothedFrequency else { return nil }

        // In manual mode, only show if within 250 cents of the selected string
        if tuningMode == .manual {
            let targetF = selectedString.targetFrequency(a4: a4Frequency)
            let cents = abs(1200.0 * log2(freq / targetF))
            if cents > 250.0 {
                return nil
            }
        }

        return freq
    }

    public var targetFrequency: Double {
        activeString.targetFrequency(a4: a4Frequency)
    }

    /// Cents difference: negative = flat (needs tightening), positive = sharp (needs loosening)
    public var centsDifference: Double {
        guard let freq = detectedFrequency else { return 0.0 }
        let cents = MusicPitchHelper.centsDifference(frequency: freq, target: targetFrequency)
        return max(-50.0, min(50.0, cents))
    }

    public var tuningStatus: TuningStatus {
        guard detectedFrequency != nil else {
            return .silent
        }
        return TuningStatus.evaluate(cents: centsDifference, tolerance: inTuneTolerance)
    }

    public var isInTune: Bool {
        return tuningStatus == .inTune
    }

    public var displayNoteName: String {
        switch notationStyle {
        case .letter:
            return activeString.noteLetter
        case .solfege:
            return activeString.solfege
        }
    }

    public var displayOctave: String {
        return "\(activeString.octave)"
    }

    // MARK: - Lifecycle Actions
    public func onAppear() {
        audioManager.checkMicrophonePermission()
        if audioManager.hasMicrophonePermission {
            audioManager.start()
        } else {
            audioManager.requestMicrophonePermission { [weak self] granted in
                if granted {
                    self?.audioManager.start()
                }
            }
        }
    }

    public func onDisappear() {
        audioManager.stop()
    }

    public func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if audioManager.hasMicrophonePermission {
                audioManager.start()
            }
        case .background, .inactive:
            audioManager.stop()
        @unknown default:
            break
        }
    }

    public func toggleListening() {
        if audioManager.isRunning {
            audioManager.stop()
        } else {
            if audioManager.hasMicrophonePermission {
                audioManager.start()
            } else {
                audioManager.requestMicrophonePermission { [weak self] granted in
                    if granted {
                        self?.audioManager.start()
                    }
                }
            }
        }
    }

    public func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    // MARK: - String & Tuning Actions
    public func selectString(_ string: GuitarString) {
        selectedString = string
        lastConfirmedString = string
        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        #endif
    }

    public func playReferenceTone(for string: GuitarString? = nil) {
        let str = string ?? activeString
        let freq = str.targetFrequency(a4: a4Frequency)
        isPlayingReferenceTone = true
        audioManager.playTone(frequency: freq, isPluck: true)

        #if os(iOS)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #endif

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.isPlayingReferenceTone = false
        }
    }

    /// Call whenever `tuningStatus` changes. Requires the reading to hold `.inTune` for
    /// ~300ms on the same string before marking it tuned and firing haptic feedback — this
    /// avoids a single lucky frame near the boundary triggering a false "in tune" moment.
    public func handleTuningStatusChange() {
        guard tuningStatus == .inTune else {
            inTuneStabilityTask?.cancel()
            inTuneStabilityTask = nil
            return
        }
        guard inTuneStabilityTask == nil else { return }

        let string = activeString
        inTuneStabilityTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            guard self.tuningStatus == .inTune, self.activeString.id == string.id else { return }
            self.markStringTuned(string)
        }
    }

    private func markStringTuned(_ string: GuitarString) {
        tunedStringIDs.insert(string.id)

        let now = Date()
        guard now.timeIntervalSince(lastInTuneHapticTime) > 1.0 else { return }
        lastInTuneHapticTime = now
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let announcement = String(
            localized: "a11y.announcement.in_tune",
            defaultValue: "\(string.displayTitle) tam akort"
        )
        AccessibilityNotification.Announcement(announcement).post()
        #endif
    }

    public func triggerHapticIfInTune() {
        guard isInTune else { return }
        markStringTuned(activeString)
    }

    // MARK: - Simulation Helper
    #if DEBUG
    public func simulatePluck(for string: GuitarString, offsetCents: Double = 0.0) {
        selectString(string)
        let baseFreq = string.targetFrequency(a4: a4Frequency)
        audioManager.simulatePluck(frequency: baseFreq, centsOffset: offsetCents)
    }
    #endif
}
