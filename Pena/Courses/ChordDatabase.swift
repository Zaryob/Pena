import SwiftUI

public struct ChordDefinition: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public let name: String
    public let frets: [Int] // 6 elements: string 6 (low E) to string 1 (high e). -1 = mute, 0 = open
    public let category: String

    public init(name: String, frets: [Int], category: String = "Temel") {
        self.name = name
        self.frets = frets
        self.category = category
    }

    public var positiveFrets: [Int] {
        frets.filter { $0 > 0 }
    }

    public var maxFret: Int {
        positiveFrets.max() ?? 0
    }

    public var minFret: Int {
        positiveFrets.min() ?? 1
    }

    public var baseFret: Int {
        maxFret > 5 ? minFret : 1
    }

    public var isNut: Bool {
        baseFret == 1
    }
}

public enum ChordDatabase {
    public static let allChords: [ChordDefinition] = [
        // Temel Açık Akorlar
        ChordDefinition(name: "Em", frets: [0, 2, 2, 0, 0, 0], category: "Açık"),
        ChordDefinition(name: "Am", frets: [-1, 0, 2, 2, 1, 0], category: "Açık"),
        ChordDefinition(name: "C", frets: [-1, 3, 2, 0, 1, 0], category: "Açık"),
        ChordDefinition(name: "G", frets: [3, 2, 0, 0, 0, 3], category: "Açık"),
        ChordDefinition(name: "D", frets: [-1, -1, 0, 2, 3, 2], category: "Açık"),
        ChordDefinition(name: "Dm", frets: [-1, -1, 0, 2, 3, 1], category: "Açık"),
        ChordDefinition(name: "E", frets: [0, 2, 2, 1, 0, 0], category: "Açık"),
        ChordDefinition(name: "A", frets: [-1, 0, 2, 2, 2, 0], category: "Açık"),
        ChordDefinition(name: "F (kolay)", frets: [-1, -1, 3, 2, 1, 1], category: "Açık"),
        ChordDefinition(name: "Fmaj7", frets: [-1, -1, 3, 2, 1, 0], category: "Açık"),

        // Yedili ve Dokuzlular
        ChordDefinition(name: "A7", frets: [-1, 0, 2, 0, 2, 0], category: "Yedili"),
        ChordDefinition(name: "D7", frets: [-1, -1, 0, 2, 1, 2], category: "Yedili"),
        ChordDefinition(name: "E7", frets: [0, 2, 0, 1, 0, 0], category: "Yedili"),
        ChordDefinition(name: "B7", frets: [-1, 2, 1, 2, 0, 2], category: "Yedili"),
        ChordDefinition(name: "Em7", frets: [0, 2, 0, 0, 0, 0], category: "Yedili"),
        ChordDefinition(name: "Am7", frets: [-1, 0, 2, 0, 1, 0], category: "Yedili"),
        ChordDefinition(name: "Dm7", frets: [-1, -1, 0, 2, 1, 1], category: "Yedili"),
        ChordDefinition(name: "G7", frets: [3, 2, 0, 0, 0, 1], category: "Yedili"),
        ChordDefinition(name: "Cmaj7", frets: [-1, 3, 2, 0, 0, 0], category: "Yedili"),
        ChordDefinition(name: "E9", frets: [-1, 7, 6, 7, 7, -1], category: "Funk / Caz"),
        ChordDefinition(name: "D9", frets: [-1, 5, 4, 5, 5, -1], category: "Funk / Caz"),
        ChordDefinition(name: "E7#9 (Funk)", frets: [0, 7, 6, 7, 8, -1], category: "Funk"),

        // Bossa Nova ve Kabuk Akorlar
        ChordDefinition(name: "Cmaj7 (Bossa)", frets: [-1, 3, 5, 4, 5, -1], category: "Bossa"),
        ChordDefinition(name: "Dm7 (Bossa)", frets: [-1, 5, 7, 5, 6, -1], category: "Bossa"),
        ChordDefinition(name: "G13 (Bossa)", frets: [3, -1, 3, 4, 5, -1], category: "Bossa"),
        ChordDefinition(name: "Am7 (Bossa)", frets: [5, -1, 5, 5, 5, -1], category: "Bossa"),
        ChordDefinition(name: "Dm7 kabuk", frets: [-1, 5, 3, 5, -1, -1], category: "Caz"),
        ChordDefinition(name: "G7 kabuk", frets: [3, -1, 3, 4, -1, -1], category: "Caz"),
        ChordDefinition(name: "Cmaj7 kabuk", frets: [-1, 3, 2, 4, -1, -1], category: "Caz"),

        // Flamenko & Rock
        ChordDefinition(name: "F (Flamenko)", frets: [1, 3, 3, 2, 0, 0], category: "Flamenko"),
        ChordDefinition(name: "E5", frets: [0, 2, 2, -1, -1, -1], category: "Rock"),
        ChordDefinition(name: "A5", frets: [-1, 0, 2, 2, -1, -1], category: "Rock"),
        ChordDefinition(name: "G5", frets: [3, 5, 5, -1, -1, -1], category: "Rock"),
        ChordDefinition(name: "D5", frets: [-1, -1, 0, 2, 3, -1], category: "Rock"),
        ChordDefinition(name: "C5", frets: [-1, 3, 5, 5, -1, -1], category: "Rock")
    ]

    public static func chords(for courseId: String) -> [ChordDefinition] {
        let mapping: [String: [String]] = [
            "turku": ["Em", "Am", "Dm", "D", "G", "C", "A7"],
            "fingerstyle": ["C", "Am", "G", "Em", "Fmaj7", "D"],
            "blues": ["A7", "D7", "E7", "B7", "E9", "Am7"],
            "rock": ["E5", "A5", "G5", "D5", "C5"],
            "klasik": ["Am", "Em", "C", "G7", "Dm", "E7", "A"],
            "flamenko": ["E", "F (Flamenko)", "Am", "G", "C", "B7"],
            "funk": ["E9", "D9", "E7#9 (Funk)", "Dm7", "Am7", "Em7"],
            "caz": ["Dm7 kabuk", "G7 kabuk", "Cmaj7 kabuk", "Dm7", "G7", "Cmaj7"],
            "country": ["G", "C", "D", "Em", "A7", "D7"],
            "bossa": ["Cmaj7 (Bossa)", "Dm7 (Bossa)", "G13 (Bossa)", "Am7 (Bossa)", "Cmaj7", "Dm7"]
        ]

        let names = mapping[courseId] ?? ["Em", "Am", "C", "G", "D"]
        return names.compactMap { name in
            allChords.first { $0.name == name }
        }
    }
}

// MARK: - Vector Chord Box View (SwiftUI Canvas & Paths)
public struct ChordBoxView: View {
    public let chord: ChordDefinition
    public var onPluck: (() -> Void)? = nil

    @State private var isPlucking = false

    public init(chord: ChordDefinition, onPluck: (() -> Void)? = nil) {
        self.chord = chord
        self.onPluck = onPluck
    }

    public var body: some View {
        VStack(spacing: 6) {
            Text(chord.name)
                .font(.headline.weight(.bold))
                .foregroundColor(Color(red: 0.92, green: 0.88, blue: 0.82))

            chordCanvas
                .frame(width: 130, height: 145)

            Button {
                triggerPluck()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isPlucking ? "waveform" : "play.fill")
                        .font(.caption2)
                    Text("Dinle")
                        .font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.18))
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.11, blue: 0.14))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.28, green: 0.24, blue: 0.22), lineWidth: 1)
        )
    }

    private func triggerPluck() {
        isPlucking = true
        onPluck?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            isPlucking = false
        }
    }

    private var chordCanvas: some View {
        Canvas { context, size in
            let paddingLeft: CGFloat = 24
            let paddingRight: CGFloat = 16
            let paddingTop: CGFloat = 22
            let fretHeight: CGFloat = 22
            let stringSpacing = (size.width - paddingLeft - paddingRight) / 5

            // Draw base fret number if > 1
            if !chord.isNut {
                let text = Text("\(chord.baseFret).p")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                context.draw(text, at: CGPoint(x: 12, y: paddingTop + 10))
            }

            // Nut or top line
            var topPath = Path()
            topPath.move(to: CGPoint(x: paddingLeft, y: paddingTop))
            topPath.addLine(to: CGPoint(x: size.width - paddingRight, y: paddingTop))
            context.stroke(topPath, with: .color(chord.isNut ? .white : Color(white: 0.5)), lineWidth: chord.isNut ? 3.5 : 1.2)

            // 5 frets
            for f in 1...5 {
                let y = paddingTop + CGFloat(f) * fretHeight
                var fretPath = Path()
                fretPath.move(to: CGPoint(x: paddingLeft, y: y))
                fretPath.addLine(to: CGPoint(x: size.width - paddingRight, y: y))
                context.stroke(fretPath, with: .color(Color(white: 0.35)), lineWidth: 1)
            }

            // 6 strings & open/mute marks & dots
            let stringNames = ["E", "A", "D", "G", "B", "e"]
            for i in 0..<6 {
                let x = paddingLeft + CGFloat(i) * stringSpacing
                var stringPath = Path()
                stringPath.move(to: CGPoint(x: x, y: paddingTop))
                stringPath.addLine(to: CGPoint(x: x, y: paddingTop + 5 * fretHeight))
                context.stroke(stringPath, with: .color(Color(white: 0.45)), lineWidth: 1)

                let fret = chord.frets[i]
                if fret > 0 {
                    let fretOffset = fret - chord.baseFret + 1
                    let cy = paddingTop + (CGFloat(fretOffset) - 0.5) * fretHeight
                    let dotRect = CGRect(x: x - 6, y: cy - 6, width: 12, height: 12)
                    context.fill(Path(ellipseIn: dotRect), with: .color(Color(red: 0.85, green: 0.72, blue: 0.35)))
                } else if fret == 0 {
                    // Open string: draw '○'
                    let text = Text("○")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(white: 0.8))
                    context.draw(text, at: CGPoint(x: x, y: 10))
                } else {
                    // Muted string: draw '×'
                    let text = Text("×")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(white: 0.45))
                    context.draw(text, at: CGPoint(x: x, y: 10))
                }

                // String label at bottom
                let bottomLabel = Text(stringNames[i])
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Color(white: 0.5))
                context.draw(bottomLabel, at: CGPoint(x: x, y: paddingTop + 5 * fretHeight + 10))
            }
        }
    }
}
