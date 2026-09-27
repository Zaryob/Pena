import Foundation
import SwiftUI
import Observation

public enum TuningMode: String, CaseIterable, Identifiable {
    case auto = "Otomatik"
    case manual = "Manuel"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .auto: return "sparkles"
        case .manual: return "hand.tap.fill"
        }
    }
}

public enum NotationStyle: String, CaseIterable, Identifiable {
    case letter = "Harf (E A D G B E)"
    case solfege = "Solfej (Mi La Re Sol Si Mi)"
    
    public var id: String { rawValue }
}

@MainActor
@Observable
public final class TunerViewModel {
    // Dependencies
    public let audioManager: AudioEngineManager
    
    // Core Configuration
    public var currentPreset: TuningPreset = .standard {
        didSet {
            if let match = currentPreset.strings.first(where: { $0.id == selectedString.id }) {
                selectedString = match
            } else if let first = currentPreset.strings.first {
                selectedString = first
            }
            lastConfirmedString = nil
        }
    }
    
    public var tuningMode: TuningMode = .auto
    public var selectedString: GuitarString
    public var lastConfirmedString: GuitarString? = nil
    
    public var notationStyle: NotationStyle = .letter
    public var a4Frequency: Double = 440.0 {
        didSet {
            audioManager.a4Calibration = a4Frequency
        }
    }
    public var inTuneTolerance: Double = 3.0 // cents
    public var noiseGateThreshold: Float = 0.006 {
        didSet {
            audioManager.noiseGateThreshold = noiseGateThreshold
        }
    }
    
    // UI Helpers
    public var isSettingsPresented: Bool = false
    public var isSimulatorSheetPresented: Bool = false
    public var isPlayingReferenceTone: Bool = false
    public var lastInTuneHapticTime: Date = .distantPast
    
    public init(audioManager: AudioEngineManager? = nil) {
        let manager = audioManager ?? AudioEngineManager()
        self.audioManager = manager
        // Start on 6th string (E2)
        self.selectedString = TuningPreset.standard.strings[5]
    }
    
    // MARK: - Active String Identification
    public var activeString: GuitarString {
        switch tuningMode {
        case .manual:
            return selectedString
            
        case .auto:
            guard let freq = audioManager.smoothedFrequency else {
                return lastConfirmedString ?? selectedString
            }
            
            // Find closest string in the current preset
            var closestString: GuitarString? = nil
            var minCentsDist: Double = Double.infinity
            
            for string in currentPreset.strings {
                let targetF = string.targetFrequency(a4: a4Frequency)
                let cents = abs(1200.0 * log2(freq / targetF))
                if cents < minCentsDist {
                    minCentsDist = cents
                    closestString = string
                }
            }
            
            // Only accept if within 220 cents of an actual guitar string
            // (Any speech or random noise outside the tuning band of guitar strings is ignored!)
            if minCentsDist <= 220.0, let matched = closestString {
                if lastConfirmedString?.id != matched.id {
                    Task { @MainActor in
                        self.lastConfirmedString = matched
                        self.selectedString = matched
                    }
                }
                return matched
            }
            
            return lastConfirmedString ?? selectedString
        }
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
    
    public func triggerHapticIfInTune() {
        guard isInTune else { return }
        let now = Date()
        guard now.timeIntervalSince(lastInTuneHapticTime) > 1.2 else { return }
        lastInTuneHapticTime = now
        
        #if os(iOS)
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        #endif
    }
    
    // MARK: - Simulation Helper
    public func simulatePluck(for string: GuitarString, offsetCents: Double = 0.0) {
        selectString(string)
        let baseFreq = string.targetFrequency(a4: a4Frequency)
        audioManager.simulatePluck(frequency: baseFreq, centsOffset: offsetCents)
    }
}
