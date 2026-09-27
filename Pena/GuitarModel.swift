import Foundation
import SwiftUI

// MARK: - Guitar String Definition
public struct GuitarString: Identifiable, Hashable, Equatable {
    public let id: Int // 1 to 6 (1 = high E, 6 = low E)
    public var stringNumber: Int { id }
    public var noteName: String      // e.g. "E4", "B3", "G3", "D3", "A2", "E2"
    public var noteLetter: String    // e.g. "E", "B", "G", "D", "A", "E"
    public var octave: Int           // 4, 3, 3, 3, 2, 2
    public var solfege: String       // "Mi", "Si", "Sol", "Re", "La", "Mi"
    public var semitonesFromA4: Double // semitone offset relative to A4 (440Hz)

    public func targetFrequency(a4: Double = 440.0) -> Double {
        return a4 * pow(2.0, semitonesFromA4 / 12.0)
    }

    public var displayTitle: String {
        String(localized: "guitar_string.display_title", defaultValue: "\(id). Tel (\(noteLetter)\(octave))")
    }

    /// e.g. "6. Tel — Mi2" / "String 6 — E2"
    public var stringLabel: String {
        String(localized: "guitar_string.label", defaultValue: "\(id). Tel — \(noteLetter)\(octave)")
    }
}

// MARK: - Tuning Presets
public struct TuningPreset: Identifiable, Hashable, Equatable {
    public let id: String
    public let strings: [GuitarString]

    public var name: String {
        switch id {
        case "standard": String(localized: "preset.standard.name", defaultValue: "Standart Akort")
        case "drop_d": String(localized: "preset.drop_d.name", defaultValue: "Drop D")
        case "half_step_down": String(localized: "preset.half_step_down.name", defaultValue: "Yarım Ses Pes (D# / E♭)")
        case "dadgad": String(localized: "preset.dadgad.name", defaultValue: "DADGAD")
        case "open_d": String(localized: "preset.open_d.name", defaultValue: "Açık D (Open D)")
        case "open_g": String(localized: "preset.open_g.name", defaultValue: "Açık G (Open G)")
        default: id
        }
    }

    public var presetDescription: String {
        switch id {
        case "standard": String(localized: "preset.standard.description", defaultValue: "Klasik gitar için evrensel standart (E A D G B E)")
        case "drop_d": String(localized: "preset.drop_d.description", defaultValue: "6. tel D2 sesine düşürülür (D A D G B E)")
        case "half_step_down": String(localized: "preset.half_step_down.description", defaultValue: "Tüm teller yarım ses pestir (E♭ A♭ D♭ G♭ B♭ E♭)")
        case "dadgad": String(localized: "preset.dadgad.description", defaultValue: "Geleneksel ve parmak stili akort (D A D G A D)")
        case "open_d": String(localized: "preset.open_d.description", defaultValue: "Boş teller Re majör akoru verir (D A D F# A D)")
        case "open_g": String(localized: "preset.open_g.description", defaultValue: "Boş teller Sol majör akoru verir (D G D G B D)")
        default: ""
        }
    }

    // Standard Tuning: E4 (1), B3 (2), G3 (3), D3 (4), A2 (5), E2 (6)
    // A4 = 440Hz
    public static let standard = TuningPreset(
        id: "standard",
        strings: [
            GuitarString(id: 1, noteName: "E4", noteLetter: "E", octave: 4, solfege: "Mi", semitonesFromA4: -5),
            GuitarString(id: 2, noteName: "B3", noteLetter: "B", octave: 3, solfege: "Si", semitonesFromA4: -10),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "E2", noteLetter: "E", octave: 2, solfege: "Mi", semitonesFromA4: -29)
        ]
    )

    // Drop D: 6th string tuned down to D2 (-31 semitones)
    public static let dropD = TuningPreset(
        id: "drop_d",
        strings: [
            GuitarString(id: 1, noteName: "E4", noteLetter: "E", octave: 4, solfege: "Mi", semitonesFromA4: -5),
            GuitarString(id: 2, noteName: "B3", noteLetter: "B", octave: 3, solfege: "Si", semitonesFromA4: -10),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", semitonesFromA4: -31)
        ]
    )

    // Half Step Down / Eb Tuning
    public static let halfStepDown = TuningPreset(
        id: "half_step_down",
        strings: [
            GuitarString(id: 1, noteName: "D#4", noteLetter: "D#", octave: 4, solfege: "Re#", semitonesFromA4: -6),
            GuitarString(id: 2, noteName: "A#3", noteLetter: "A#", octave: 3, solfege: "La#", semitonesFromA4: -11),
            GuitarString(id: 3, noteName: "F#3", noteLetter: "F#", octave: 3, solfege: "Fa#", semitonesFromA4: -15),
            GuitarString(id: 4, noteName: "C#3", noteLetter: "C#", octave: 3, solfege: "Do#", semitonesFromA4: -20),
            GuitarString(id: 5, noteName: "G#2", noteLetter: "G#", octave: 2, solfege: "Sol#", semitonesFromA4: -25),
            GuitarString(id: 6, noteName: "D#2", noteLetter: "D#", octave: 2, solfege: "Re#", semitonesFromA4: -30)
        ]
    )

    // DADGAD: Celtic / fingerstyle favorite
    public static let dadgad = TuningPreset(
        id: "dadgad",
        strings: [
            GuitarString(id: 1, noteName: "D4", noteLetter: "D", octave: 4, solfege: "Re", semitonesFromA4: -7),
            GuitarString(id: 2, noteName: "A3", noteLetter: "A", octave: 3, solfege: "La", semitonesFromA4: -12),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", semitonesFromA4: -31)
        ]
    )

    // Open D: D A D F# A D
    public static let openD = TuningPreset(
        id: "open_d",
        strings: [
            GuitarString(id: 1, noteName: "D4", noteLetter: "D", octave: 4, solfege: "Re", semitonesFromA4: -7),
            GuitarString(id: 2, noteName: "A3", noteLetter: "A", octave: 3, solfege: "La", semitonesFromA4: -12),
            GuitarString(id: 3, noteName: "F#3", noteLetter: "F#", octave: 3, solfege: "Fa#", semitonesFromA4: -15),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", semitonesFromA4: -31)
        ]
    )

    // Open G: D G D G B D
    public static let openG = TuningPreset(
        id: "open_g",
        strings: [
            GuitarString(id: 1, noteName: "D4", noteLetter: "D", octave: 4, solfege: "Re", semitonesFromA4: -7),
            GuitarString(id: 2, noteName: "B3", noteLetter: "B", octave: 3, solfege: "Si", semitonesFromA4: -10),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "G2", noteLetter: "G", octave: 2, solfege: "Sol", semitonesFromA4: -26),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", semitonesFromA4: -31)
        ]
    )

    public static let allPresets: [TuningPreset] = [
        .standard,
        .dropD,
        .halfStepDown,
        .dadgad,
        .openD,
        .openG
    ]
}

// MARK: - Tuning Status
public enum TuningStatus: Equatable {
    case silent
    case inTune
    case slightlyFlat
    case slightlySharp
    case flat
    case sharp

    public static func evaluate(cents: Double, tolerance: Double = 3.0) -> TuningStatus {
        if abs(cents) <= tolerance {
            return .inTune
        } else if cents > tolerance && cents <= 10.0 {
            return .slightlySharp
        } else if cents < -tolerance && cents >= -10.0 {
            return .slightlyFlat
        } else if cents > 10.0 {
            return .sharp
        } else {
            return .flat
        }
    }

    public var label: String {
        switch self {
        case .silent:
            return String(localized: "tuning_status.silent", defaultValue: "Ses Bekleniyor...")
        case .inTune:
            return String(localized: "tuning_status.in_tune", defaultValue: "TAM AKORT")
        case .slightlyFlat:
            return String(localized: "tuning_status.slightly_flat", defaultValue: "Biraz Pes (Sık)")
        case .flat:
            return String(localized: "tuning_status.flat", defaultValue: "Çok Pes (Sık)")
        case .slightlySharp:
            return String(localized: "tuning_status.slightly_sharp", defaultValue: "Biraz Tiz (Gevşet)")
        case .sharp:
            return String(localized: "tuning_status.sharp", defaultValue: "Çok Tiz (Gevşet)")
        }
    }

    public var color: Color {
        switch self {
        case .silent:
            return Color(white: 0.5)
        case .inTune:
            return Color(red: 0.15, green: 0.85, blue: 0.40)
        case .slightlyFlat:
            return Color(red: 0.95, green: 0.70, blue: 0.15)
        case .slightlySharp:
            return Color(red: 0.25, green: 0.75, blue: 0.95)
        case .flat:
            return Color(red: 0.95, green: 0.45, blue: 0.15)
        case .sharp:
            return Color(red: 0.85, green: 0.35, blue: 0.95)
        }
    }

    public var indicatorIcon: String {
        switch self {
        case .silent:
            return "waveform"
        case .inTune:
            return "checkmark.circle.fill"
        case .slightlyFlat, .flat:
            return "arrow.up.circle.fill" // tighten = increase pitch
        case .slightlySharp, .sharp:
            return "arrow.down.circle.fill" // loosen = decrease pitch
        }
    }
}

// MARK: - Musical Note Utilities
public struct MusicPitchHelper {
    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    public static let solfegeNames = ["Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"]

    /// Returns note name, octave, and cents offset for an arbitrary frequency with given A4 calibration
    public static func noteInfo(for frequency: Double, a4: Double = 440.0) -> (noteName: String, solfege: String, octave: Int, cents: Double, nominalFreq: Double)? {
        guard frequency > 30.0 && frequency < 2000.0 else { return nil }

        let semitones = 12.0 * log2(frequency / a4)
        let roundedSemitones = round(semitones)
        let cents = (semitones - roundedSemitones) * 100.0
        let nominalFreq = a4 * pow(2.0, roundedSemitones / 12.0)

        // A4 is MIDI note 69
        let midiNote = Int(roundedSemitones) + 69
        guard midiNote >= 0 else { return nil }

        let noteIndex = midiNote % 12
        let octave = (midiNote / 12) - 1

        let noteName = "\(noteNames[noteIndex])\(octave)"
        let solfege = "\(solfegeNames[noteIndex])\(octave)"

        return (noteName, solfege, octave, cents, nominalFreq)
    }

    /// Calculate cents deviation between measured frequency and target frequency
    public static func centsDifference(frequency: Double, target: Double) -> Double {
        guard frequency > 0, target > 0 else { return 0 }
        return 1200.0 * log2(frequency / target)
    }
}
