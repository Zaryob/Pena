import SwiftUI

public struct InteractiveChordLibraryView: View {
    @State private var selectedCategory: String = "Tümü"
    private let categories = ["Tümü", "Açık", "Yedili", "Funk / Caz", "Bossa", "Caz", "Flamenko", "Rock"]

    public init() {}

    private var filteredChords: [ChordDefinition] {
        if selectedCategory == "Tümü" {
            return ChordDatabase.allChords
        }
        return ChordDatabase.allChords.filter { $0.category == selectedCategory }
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Category filter chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = cat
                            }
                        } label: {
                            Text(cat)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(selectedCategory == cat ? Color(red: 0.85, green: 0.72, blue: 0.35) : Color(white: 0.15))
                                .foregroundColor(selectedCategory == cat ? .black : .white)
                                .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }

            // Grid of chords
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 14)], spacing: 14) {
                ForEach(filteredChords) { chord in
                    ChordBoxView(chord: chord) {
                        // Play authentic chord pluck via audio engine
                        AudioEngineManager.shared.playChord(frets: chord.frets)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
