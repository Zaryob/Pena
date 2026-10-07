import SwiftUI

public struct FretboardRoadmapView: View {
    public let totalDays: Int = 30
    public let completedDays: Set<Int>
    @Binding public var selectedDay: Int
    public var onSelectDay: ((Int) -> Void)? = nil

    private let inlayFrets: Set<Int> = [3, 5, 7, 9, 12, 15, 17, 19, 21, 24, 27, 30]
    private let doubleInlayFrets: Set<Int> = [12, 24]

    public init(
        completedDays: Set<Int>,
        selectedDay: Binding<Int>,
        onSelectDay: ((Int) -> Void)? = nil
    ) {
        self.completedDays = completedDays
        self._selectedDay = selectedDay
        self.onSelectDay = onSelectDay
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("30 Günlük Yol Haritası", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                Spacer()
                Text("\(completedDays.count)/30 Gün")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.2))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 4)

            // Horizontal scrolling fretboard
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        // Nut (Eşik)
                        Rectangle()
                            .fill(Color(white: 0.85))
                            .frame(width: 8, height: 90)
                            .shadow(color: .black.opacity(0.5), radius: 2, x: 2, y: 0)

                        // 30 Frets
                        ForEach(1...totalDays, id: \.self) { day in
                            fretView(for: day)
                                .id(day)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                }
                .background(
                    // Rosewood fretboard texture simulation
                    ZStack {
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.12, blue: 0.10),
                                Color(red: 0.22, green: 0.16, blue: 0.13),
                                Color(red: 0.16, green: 0.12, blue: 0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        // 6 Guitar strings running horizontally across the fretboard
                        VStack(spacing: 12) {
                            ForEach(0..<6, id: \.self) { stringIdx in
                                Rectangle()
                                    .fill(stringColor(for: stringIdx))
                                    .frame(height: stringThickness(for: stringIdx))
                                    .shadow(color: .black.opacity(0.6), radius: 1, y: 1)
                            }
                        }
                    }
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 0.32, green: 0.26, blue: 0.22), lineWidth: 1.5)
                )
                .onAppear {
                    proxy.scrollTo(selectedDay, anchor: .center)
                }
                .onChange(of: selectedDay) { _, newDay in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        proxy.scrollTo(newDay, anchor: .center)
                    }
                }
            }
        }
    }

    private func fretView(for day: Int) -> some View {
        let isDone = completedDays.contains(day)
        let isSelected = (selectedDay == day)
        let hasInlay = inlayFrets.contains(day)
        let isDoubleInlay = doubleInlayFrets.contains(day)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedDay = day
            onSelectDay?(day)
        } label: {
            ZStack {
                // Inlay Dots (Mother-of-pearl sedef nokta)
                if hasInlay {
                    if isDoubleInlay {
                        VStack(spacing: 34) {
                            Circle().fill(Color(white: 0.85).opacity(0.85)).frame(width: 7, height: 7)
                            Circle().fill(Color(white: 0.85).opacity(0.85)).frame(width: 7, height: 7)
                        }
                    } else {
                        Circle()
                            .fill(Color(white: 0.85).opacity(0.85))
                            .frame(width: 8, height: 8)
                    }
                }

                // Fret Badge / Day number
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(badgeBackground(isDone: isDone, isSelected: isSelected))
                            .frame(width: 32, height: 32)
                            .shadow(color: isSelected ? Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.6) : .clear, radius: 4)

                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.black)
                        } else {
                            Text("\(day)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(isSelected ? .black : .white)
                        }
                    }

                    Text("Perde \(day)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(white: 0.55))
                }
            }
            .frame(width: 54, height: 90)
            // Silver metal fret wire on the right
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.9), Color(white: 0.5), Color(white: 0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 2.5)
                    .shadow(color: .black.opacity(0.4), radius: 1, x: 1, y: 0),
                alignment: .trailing
            )
        }
        .buttonStyle(.plain)
    }

    private func badgeBackground(isDone: Bool, isSelected: Bool) -> Color {
        if isDone {
            return Color(red: 0.25, green: 0.80, blue: 0.45) // Finished green
        } else if isSelected {
            return Color(red: 0.85, green: 0.72, blue: 0.35) // Active gold
        } else {
            return Color(red: 0.18, green: 0.16, blue: 0.20) // Unfinished
        }
    }

    private func stringThickness(for index: Int) -> CGFloat {
        // String 0 = high E (thin) to String 5 = low E (thick)
        let thicknesses: [CGFloat] = [1.0, 1.2, 1.5, 1.9, 2.3, 2.8]
        return thicknesses[index]
    }

    private func stringColor(for index: Int) -> Color {
        // Nylon/Bronze wound simulation
        if index < 3 {
            return Color(white: 0.85).opacity(0.65)
        } else {
            return Color(red: 0.85, green: 0.72, blue: 0.55).opacity(0.7)
        }
    }
}
