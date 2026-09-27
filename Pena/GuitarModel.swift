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
    public var turkishName: String   // "1. Tel (İnce Mi)", "6. Tel (Kalın Mi)"
    public var semitonesFromA4: Double // semitone offset relative to A4 (440Hz)
    
    public func targetFrequency(a4: Double = 440.0) -> Double {
        return a4 * pow(2.0, semitonesFromA4 / 12.0)
    }
    
    public var displayTitle: String {
        return "\(id). Tel (\(noteLetter)\(octave))"
    }
}

// MARK: - Tuning Presets
public struct TuningPreset: Identifiable, Hashable, Equatable {
    public let id: String
    public let name: String
    public let turkishDescription: String
    public let strings: [GuitarString]
    
    // Standard Tuning: E4 (1), B3 (2), G3 (3), D3 (4), A2 (5), E2 (6)
    // A4 = 440Hz
    // E4 = -5 semitones -> 329.63 Hz
    // B3 = -10 semitones -> 246.94 Hz
    // G3 = -14 semitones -> 196.00 Hz
    // D3 = -19 semitones -> 146.83 Hz
    // A2 = -24 semitones -> 110.00 Hz
    // E2 = -29 semitones -> 82.41 Hz
    public static let standard = TuningPreset(
        id: "standard",
        name: "Standart Akort",
        turkishDescription: "Klasik gitar için evrensel standart (E A D G B E)",
        strings: [
            GuitarString(id: 1, noteName: "E4", noteLetter: "E", octave: 4, solfege: "Mi", turkishName: "1. Tel - İnce Mi", semitonesFromA4: -5),
            GuitarString(id: 2, noteName: "B3", noteLetter: "B", octave: 3, solfege: "Si", turkishName: "2. Tel - Si", semitonesFromA4: -10),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", turkishName: "3. Tel - Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", turkishName: "4. Tel - Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", turkishName: "5. Tel - La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "E2", noteLetter: "E", octave: 2, solfege: "Mi", turkishName: "6. Tel - Kalın Mi", semitonesFromA4: -29)
        ]
    )
    
    // Drop D: 6th string tuned down to D2 (-31 semitones)
    public static let dropD = TuningPreset(
        id: "drop_d",
        name: "Drop D",
        turkishDescription: "6. tel D2 sesine düşürülür (D A D G B E)",
        strings: [
            GuitarString(id: 1, noteName: "E4", noteLetter: "E", octave: 4, solfege: "Mi", turkishName: "1. Tel - İnce Mi", semitonesFromA4: -5),
            GuitarString(id: 2, noteName: "B3", noteLetter: "B", octave: 3, solfege: "Si", turkishName: "2. Tel - Si", semitonesFromA4: -10),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", turkishName: "3. Tel - Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", turkishName: "4. Tel - Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", turkishName: "5. Tel - La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", turkishName: "6. Tel - Re (Drop)", semitonesFromA4: -31)
        ]
    )
    
    // Half Step Down / Eb Tuning
    public static let halfStepDown = TuningPreset(
        id: "half_step_down",
        name: "Yarım Ses Pes (D# / E♭)",
        turkishDescription: "Tüm teller yarım ses pestir (E♭ A♭ D♭ G♭ B♭ E♭)",
        strings: [
            GuitarString(id: 1, noteName: "D#4", noteLetter: "D#", octave: 4, solfege: "Re#", turkishName: "1. Tel - D#4", semitonesFromA4: -6),
            GuitarString(id: 2, noteName: "A#3", noteLetter: "A#", octave: 3, solfege: "La#", turkishName: "2. Tel - A#3", semitonesFromA4: -11),
            GuitarString(id: 3, noteName: "F#3", noteLetter: "F#", octave: 3, solfege: "Fa#", turkishName: "3. Tel - F#3", semitonesFromA4: -15),
            GuitarString(id: 4, noteName: "C#3", noteLetter: "C#", octave: 3, solfege: "Do#", turkishName: "4. Tel - C#3", semitonesFromA4: -20),
            GuitarString(id: 5, noteName: "G#2", noteLetter: "G#", octave: 2, solfege: "Sol#", turkishName: "5. Tel - G#2", semitonesFromA4: -25),
            GuitarString(id: 6, noteName: "D#2", noteLetter: "D#", octave: 2, solfege: "Re#", turkishName: "6. Tel - D#2", semitonesFromA4: -30)
        ]
    )
    
    // DADGAD: Celtic / fingerstyle favorite
    public static let dadgad = TuningPreset(
        id: "dadgad",
        name: "DADGAD",
        turkishDescription: "Geleneksel ve parmak stili akort (D A D G A D)",
        strings: [
            GuitarString(id: 1, noteName: "D4", noteLetter: "D", octave: 4, solfege: "Re", turkishName: "1. Tel - Re", semitonesFromA4: -7),
            GuitarString(id: 2, noteName: "A3", noteLetter: "A", octave: 3, solfege: "La", turkishName: "2. Tel - La", semitonesFromA4: -12),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", turkishName: "3. Tel - Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", turkishName: "4. Tel - Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", turkishName: "5. Tel - La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", turkishName: "6. Tel - Re", semitonesFromA4: -31)
        ]
    )
    
    // Open D: D A D F# A D
    public static let openD = TuningPreset(
        id: "open_d",
        name: "Açık D (Open D)",
        turkishDescription: "Boş teller Re majör akoru verir (D A D F# A D)",
        strings: [
            GuitarString(id: 1, noteName: "D4", noteLetter: "D", octave: 4, solfege: "Re", turkishName: "1. Tel - Re", semitonesFromA4: -7),
            GuitarString(id: 2, noteName: "A3", noteLetter: "A", octave: 3, solfege: "La", turkishName: "2. Tel - La", semitonesFromA4: -12),
            GuitarString(id: 3, noteName: "F#3", noteLetter: "F#", octave: 3, solfege: "Fa#", turkishName: "3. Tel - Fa#", semitonesFromA4: -15),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", turkishName: "4. Tel - Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "A2", noteLetter: "A", octave: 2, solfege: "La", turkishName: "5. Tel - La", semitonesFromA4: -24),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", turkishName: "6. Tel - Re", semitonesFromA4: -31)
        ]
    )
    
    // Open G: D G D G B D
    public static let openG = TuningPreset(
        id: "open_g",
        name: "Açık G (Open G)",
        turkishDescription: "Boş teller Sol majör akoru verir (D G D G B D)",
        strings: [
            GuitarString(id: 1, noteName: "D4", noteLetter: "D", octave: 4, solfege: "Re", turkishName: "1. Tel - Re", semitonesFromA4: -7),
            GuitarString(id: 2, noteName: "B3", noteLetter: "B", octave: 3, solfege: "Si", turkishName: "2. Tel - Si", semitonesFromA4: -10),
            GuitarString(id: 3, noteName: "G3", noteLetter: "G", octave: 3, solfege: "Sol", turkishName: "3. Tel - Sol", semitonesFromA4: -14),
            GuitarString(id: 4, noteName: "D3", noteLetter: "D", octave: 3, solfege: "Re", turkishName: "4. Tel - Re", semitonesFromA4: -19),
            GuitarString(id: 5, noteName: "G2", noteLetter: "G", octave: 2, solfege: "Sol", turkishName: "5. Tel - Sol", semitonesFromA4: -26),
            GuitarString(id: 6, noteName: "D2", noteLetter: "D", octave: 2, solfege: "Re", turkishName: "6. Tel - Re", semitonesFromA4: -31)
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
            return "Ses Bekleniyor..."
        case .inTune:
            return "TAM AKORT"
        case .slightlyFlat, .flat:
            return "ÇOK PES (SIK)"
        case .slightlySharp, .sharp:
            return "ÇOK TİZ (GEVŞET)"
        }
    }
    
    public var englishLabel: String {
        switch self {
        case .silent:
            return "Listening..."
        case .inTune:
            return "IN TUNE"
        case .slightlyFlat, .flat:
            return "TOO FLAT (TIGHTEN)"
        case .slightlySharp, .sharp:
            return "TOO SHARP (LOOSEN)"
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
