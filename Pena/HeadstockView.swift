import SwiftUI

public struct HeadstockView: View {
    public let preset: TuningPreset
    public let activeString: GuitarString
    public let status: TuningStatus
    public let isPlayingTone: Bool
    public let tunedStringIDs: Set<Int>
    public let onSelectString: (GuitarString) -> Void
    public let onPlayTone: (GuitarString) -> Void

    public init(
        preset: TuningPreset,
        activeString: GuitarString,
        status: TuningStatus,
        isPlayingTone: Bool,
        tunedStringIDs: Set<Int> = [],
        onSelectString: @escaping (GuitarString) -> Void,
        onPlayTone: @escaping (GuitarString) -> Void
    ) {
        self.preset = preset
        self.activeString = activeString
        self.status = status
        self.isPlayingTone = isPlayingTone
        self.tunedStringIDs = tunedStringIDs
        self.onSelectString = onSelectString
        self.onPlayTone = onPlayTone
    }
    
    // Left side: strings 6, 5, 4 (ordered from bottom to top or top to bottom)
    // On classical guitar headstock:
    // Left side (top to bottom): 4th string (D3), 5th string (A2), 6th string (E2)
    // Right side (top to bottom): 3rd string (G3), 2nd string (B3), 1st string (E4)
    private var leftStrings: [GuitarString] {
        let s4 = preset.strings.first { $0.id == 4 }
        let s5 = preset.strings.first { $0.id == 5 }
        let s6 = preset.strings.first { $0.id == 6 }
        return [s4, s5, s6].compactMap { $0 }
    }
    
    private var rightStrings: [GuitarString] {
        let s3 = preset.strings.first { $0.id == 3 }
        let s2 = preset.strings.first { $0.id == 2 }
        let s1 = preset.strings.first { $0.id == 1 }
        return [s3, s2, s1].compactMap { $0 }
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Left Pegs (Strings 4, 5, 6)
            VStack(spacing: 24) {
                ForEach(leftStrings) { string in
                    PegButton(
                        string: string,
                        isActive: activeString.id == string.id,
                        status: activeString.id == string.id ? status : .silent,
                        isLeftSide: true,
                        isPlayingTone: activeString.id == string.id && isPlayingTone,
                        isTuned: tunedStringIDs.contains(string.id),
                        onTap: { onSelectString(string) },
                        onPlayTone: { onPlayTone(string) }
                    )
                }
            }
            .frame(width: 100)
            
            // Classical Guitar Headstock Body
            ZStack {
                // Wooden Headstock Silhouette
                ClassicalHeadstockShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.12, blue: 0.08), // Dark Brazilian rosewood
                                Color(red: 0.14, green: 0.08, blue: 0.05),
                                Color(red: 0.10, green: 0.05, blue: 0.03)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        ClassicalHeadstockShape()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.55, green: 0.38, blue: 0.22).opacity(0.8),
                                        Color(white: 0.1)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.6), radius: 10, y: 5)
                
                // Slotted Cutouts (Left & Right vertical tuner slots)
                HStack(spacing: 24) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.28, blue: 0.18).opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 18, height: 160)
                        .overlay(
                            // 3 brass rollers inside slot
                            VStack(spacing: 38) {
                                ForEach(0..<3) { _ in
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.85, green: 0.72, blue: 0.35), Color(red: 0.45, green: 0.35, blue: 0.15)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 14, height: 10)
                                }
                            }
                        )
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(red: 0.4, green: 0.28, blue: 0.18).opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 18, height: 160)
                        .overlay(
                            // 3 brass rollers inside slot
                            VStack(spacing: 38) {
                                ForEach(0..<3) { _ in
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color(red: 0.85, green: 0.72, blue: 0.35), Color(red: 0.45, green: 0.35, blue: 0.15)],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                        .frame(width: 14, height: 10)
                                }
                            }
                        )
                }
                
                // Pena Brand Inlay Badge at Headstock Crown
                VStack {
                    ZStack {
                        Capsule()
                            .fill(Color(red: 0.12, green: 0.07, blue: 0.04))
                            .frame(width: 60, height: 18)
                            .overlay(
                                Capsule().stroke(Color(red: 0.8, green: 0.65, blue: 0.3).opacity(0.5), lineWidth: 1)
                            )
                        Text("P E N A")
                            .font(.system(size: 9, weight: .bold, design: .serif))
                            .foregroundStyle(Color(red: 0.9, green: 0.78, blue: 0.45))
                    }
                    .offset(y: 22)
                    
                    Spacer()
                    
                    // Bone Nut at base of headstock
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.92), Color(white: 0.78)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 10)
                        .cornerRadius(2)
                        .padding(.horizontal, 10)
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                        .overlay(
                            // 6 string notches on nut
                            HStack(spacing: 12) {
                                ForEach(1...6, id: \.self) { num in
                                    Rectangle()
                                        .fill(Color.black.opacity(0.6))
                                        .frame(width: 1.5, height: 10)
                                }
                            }
                        )
                        .offset(y: -4)
                }
            }
            .frame(width: 140, height: 230)
            
            // Right Pegs (Strings 3, 2, 1)
            VStack(spacing: 24) {
                ForEach(rightStrings) { string in
                    PegButton(
                        string: string,
                        isActive: activeString.id == string.id,
                        status: activeString.id == string.id ? status : .silent,
                        isLeftSide: false,
                        isPlayingTone: activeString.id == string.id && isPlayingTone,
                        isTuned: tunedStringIDs.contains(string.id),
                        onTap: { onSelectString(string) },
                        onPlayTone: { onPlayTone(string) }
                    )
                }
            }
            .frame(width: 100)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Peg Button
private struct PegButton: View {
    let string: GuitarString
    let isActive: Bool
    let status: TuningStatus
    let isLeftSide: Bool
    let isPlayingTone: Bool
    let isTuned: Bool
    let onTap: () -> Void
    let onPlayTone: () -> Void

    private var accessibilityHint: String {
        if isTuned {
            return String(localized: "headstock.a11y.hint_tuned", defaultValue: "Akortlandı. Seçmek için dokunun.")
        }
        return String(localized: "headstock.a11y.hint", defaultValue: "Bu teli seçmek için dokunun, referans sesini duymak için basılı tutun.")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if !isLeftSide {
                    pegHandle
                }

                // String details container
                ZStack(alignment: isLeftSide ? .topLeading : .topTrailing) {
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            Text(string.noteLetter)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(isActive ? (status == .silent ? .white : status.color) : .secondary)

                            Text("\(string.octave)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.secondary)
                        }

                        Text(String(localized: "headstock.string_number", defaultValue: "\(string.id). Tel"))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary.opacity(0.6))
                    }
                    .frame(width: 50, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isActive ? Color(white: 0.18) : Color(white: 0.10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        isActive ? (status == .silent ? Color(red: 0.85, green: 0.72, blue: 0.35) : status.color) : Color(white: 0.18),
                                        lineWidth: isActive ? 2 : 1
                                    )
                            )
                            .shadow(
                                color: isActive ? (status == .silent ? Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.3) : status.color.opacity(0.4)) : .clear,
                                radius: 8
                            )
                    )

                    if isTuned {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 0.15, green: 0.85, blue: 0.40))
                            .background(Circle().fill(Color(white: 0.10)))
                            .offset(x: isLeftSide ? -4 : 4, y: -4)
                    }
                }

                if isLeftSide {
                    pegHandle
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(string.stringLabel))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .contextMenu {
            Button {
                onPlayTone()
            } label: {
                Label(
                    String(localized: "headstock.play_string_tone", defaultValue: "\(string.displayTitle) Sesini Çal"),
                    systemImage: "speaker.wave.2.fill"
                )
            }
        }
    }
    
    // Pearloid / White Tuning Peg Handle
    private var pegHandle: some View {
        ZStack {
            // Brass connector post
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.8, green: 0.65, blue: 0.3), Color(red: 0.5, green: 0.38, blue: 0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 10, height: 4)
            
            // Pearloid Peg Knob
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.94),
                            Color(white: 0.82),
                            Color(white: 0.70)
                        ],
                        startPoint: isLeftSide ? .leading : .trailing,
                        endPoint: isLeftSide ? .trailing : .leading
                    )
                )
                .frame(width: 14, height: 26)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.4), radius: 2, x: isLeftSide ? -1 : 1, y: 1)
                .overlay(
                    // Ripple effect if playing tone
                    Group {
                        if isPlayingTone {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color(red: 0.85, green: 0.72, blue: 0.35), lineWidth: 1.5)
                                .scaleEffect(1.4)
                                .opacity(0.8)
                        }
                    }
                )
        }
    }
}

// MARK: - Classical Spanish Headstock Shape
private struct ClassicalHeadstockShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Base corners at nut
        path.move(to: CGPoint(x: 10, y: h))
        // Left side going up, slight flare outward
        path.addLine(to: CGPoint(x: 4, y: h * 0.4))
        path.addLine(to: CGPoint(x: 0, y: 30))
        
        // Classical Spanish curved crest crown top (traditional 3-lobe curve)
        path.addQuadCurve(to: CGPoint(x: w * 0.3, y: 14), control: CGPoint(x: 2, y: 8))
        path.addQuadCurve(to: CGPoint(x: w * 0.5, y: 0), control: CGPoint(x: w * 0.4, y: 20))
        path.addQuadCurve(to: CGPoint(x: w * 0.7, y: 14), control: CGPoint(x: w * 0.6, y: 20))
        path.addQuadCurve(to: CGPoint(x: w, y: 30), control: CGPoint(x: w - 2, y: 8))
        
        // Right side going down
        path.addLine(to: CGPoint(x: w - 4, y: h * 0.4))
        path.addLine(to: CGPoint(x: w - 10, y: h))
        
        path.closeSubpath()
        return path
    }
}
