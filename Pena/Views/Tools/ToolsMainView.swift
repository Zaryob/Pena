import SwiftUI

public struct ToolsMainView: View {
    @State private var selectedSegment: Int = 0 // 0 = Metronome, 1 = Chords

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Custom segment picker
                        Picker("Araç Seçimi", selection: $selectedSegment) {
                            Text("Metronom").tag(0)
                            Text("Akor Kütüphanesi").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        if selectedSegment == 0 {
                            HapticMetronomeView()
                                .padding(.horizontal, 16)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        } else {
                            InteractiveChordLibraryView()
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Gitar Araçları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.09), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
