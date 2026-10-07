import SwiftUI

public enum MainAppTab: Int, Hashable, CaseIterable {
    case tuner = 0
    case academy = 1
    case tools = 2
}

public struct ContentView: View {
    @State private var selectedTab: MainAppTab = .tuner

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Tuner
            TunerMainView()
                .tabItem {
                    Label(
                        String(localized: "tab.tuner", defaultValue: "Akort"),
                        systemImage: "tuningfork"
                    )
                }
                .tag(MainAppTab.tuner)

            // Tab 2: Academy
            AcademyCatalogView(onOpenTuner: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    selectedTab = .tuner
                }
            })
            .tabItem {
                Label(
                    String(localized: "tab.academy", defaultValue: "Akademi"),
                    systemImage: "music.note.house.fill"
                )
            }
            .tag(MainAppTab.academy)

            // Tab 3: Tools (Metronome & Chords)
            ToolsMainView()
                .tabItem {
                    Label(
                        String(localized: "tab.tools", defaultValue: "Araçlar"),
                        systemImage: "metronome.fill"
                    )
                }
                .tag(MainAppTab.tools)
        }
        .tint(Color(red: 0.85, green: 0.72, blue: 0.35)) // Pena Signature Gold
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
