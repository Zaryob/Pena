import SwiftUI

public struct GaugeMeterView: View {
    public let cents: Double            // -50.0 to +50.0, clamped
    public let status: TuningStatus
    public let tolerance: Double        // in-tune band half-width, in cents
    public let noteLetter: String       // e.g. "E"
    public let octave: String           // e.g. "2"
    public let detectedHz: Double?
    public let targetHz: Double
    public let stringName: String       // e.g. "6. Tel - Kalın Mi"
    public let amplitude: Float         // Live RMS amplitude
    public let isPluckDetected: Bool

    public init(
        cents: Double,
        status: TuningStatus,
        tolerance: Double = 3.0,
        noteLetter: String,
        octave: String,
        detectedHz: Double?,
        targetHz: Double,
        stringName: String,
        amplitude: Float = 0.0,
        isPluckDetected: Bool = false
    ) {
        self.cents = cents
        self.status = status
        self.tolerance = tolerance
        self.noteLetter = noteLetter
        self.octave = octave
        self.detectedHz = detectedHz
        self.targetHz = targetHz
        self.stringName = stringName
        self.amplitude = amplitude
        self.isPluckDetected = isPluckDetected
    }

    // Normalized amplitude for level meter (0.0 to 1.0)
    private var normalizedLevel: CGFloat {
        let normalized = CGFloat(min(1.0, max(0.0, amplitude * 25.0)))
        return normalized
    }

    private var isOffScale: Bool {
        detectedHz != nil && abs(cents) >= 49.5
    }

    private var accessibilityValueText: String {
        guard detectedHz != nil else {
            return amplitude > 0.002
                ? String(localized: "gauge.a11y.hearing_sound", defaultValue: "Ses algılanıyor, nota bekleniyor")
                : String(localized: "gauge.a11y.waiting", defaultValue: "Ses bekleniyor")
        }
        if status == .inTune {
            return String(localized: "gauge.a11y.in_tune", defaultValue: "Tam akort")
        }
        let centsText = abs(cents).formatted(.number.precision(.fractionLength(0)))
        return String(localized: "gauge.a11y.off_tune", defaultValue: "\(centsText) cent, \(status.label)")
    }

    public var body: some View {
        VStack(spacing: 12) {
            // String title & Target Hz header
            ViewThatFits(in: .horizontal) {
                HStack {
                    gaugeHeader
                }
                VStack(alignment: .leading, spacing: 4) {
                    gaugeHeader
                }
            }
            .padding(.horizontal, 24)
            .accessibilityHidden(true)

            // Main Dial / Arc Meter
            ZStack {
                // Background Glow when In Tune
                if status == .inTune {
                    Circle()
                        .fill(status.color.opacity(0.25))
                        .frame(width: 220, height: 220)
                        .blur(radius: 30)
                }

                // Dial Gauge Arc
                GaugeArcShape(cents: cents, status: status, tolerance: tolerance)
                    .frame(height: 140)
                    .padding(.horizontal, 16)

                // Off-scale indicator: the reading is clamped at the edge of the dial, so a
                // chevron communicates "keep going" beyond what the needle position alone can.
                if isOffScale {
                    Image(systemName: cents < 0 ? "chevron.left.2" : "chevron.right.2")
                        .font(.subheadline.bold())
                        .foregroundStyle(status.color)
                        .offset(x: cents < 0 ? -90 : 90, y: 8)
                        .transition(.opacity)
                }

                // Central Note Info Display
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(noteLetter)
                            .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                            .foregroundStyle(status == .silent ? Color.white.opacity(0.8) : status.color)
                            .shadow(color: status.color.opacity(status == .inTune ? 0.6 : 0.2), radius: 10)

                        Text(octave)
                            .font(.title.bold())
                            .foregroundStyle(.secondary)
                            .offset(y: -10)
                    }
                    .scaleEffect(isPluckDetected ? 1.08 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isPluckDetected)

                    // Detected Frequency readout
                    if let hz = detectedHz {
                        Text("\(hz, format: .number.precision(.fractionLength(1))) Hz")
                            .font(.body.weight(.semibold).monospaced())
                            .foregroundStyle(.white)
                    } else if amplitude > 0.002 {
                        HStack(spacing: 4) {
                            Circle().fill(Color(red: 0.85, green: 0.72, blue: 0.35)).frame(width: 6, height: 6)
                            Text(String(localized: "gauge.listening", defaultValue: "Dinleniyor..."))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(red: 0.85, green: 0.72, blue: 0.35))
                        }
                    } else {
                        Text("--.- Hz")
                            .font(.body.monospaced())
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                }
                .offset(y: 12)
            }
            .frame(minHeight: 170)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(noteLetter)\(octave)"))
            .accessibilityValue(Text(accessibilityValueText))
            .accessibilityAddTraits(.updatesFrequently)

            // Cents Deviation & Status Pills
            HStack(spacing: 12) {
                // Cents pill
                HStack(spacing: 4) {
                    Text(detectedHz != nil ? cents.formatted(.number.sign(strategy: .always()).precision(.fractionLength(0))) : "—")
                        .font(.subheadline.bold().monospaced())
                    Text(String(localized: "gauge.cent_unit", defaultValue: "cent"))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(white: 0.16))
                        .overlay(
                            Capsule()
                                .stroke(status.color.opacity(0.3), lineWidth: 1)
                        )
                )

                // Status guidance pill
                HStack(spacing: 6) {
                    Image(systemName: status.indicatorIcon)
                        .font(.subheadline.bold())
                    Text(status == .silent && amplitude > 0.002 ? String(localized: "gauge.receiving_sound", defaultValue: "SES ALINIYOR") : status.label)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .foregroundStyle(status == .silent ? Color.secondary : Color.black)
                .background(
                    Capsule()
                        .fill(status == .silent ? Color(white: 0.18) : status.color)
                )
                .animation(.easeInOut(duration: 0.2), value: status)
            }
            .padding(.top, 4)
            .accessibilityHidden(true)

            // Live Mic Level Indicator
            HStack(spacing: 8) {
                Image(systemName: amplitude > 0.002 ? "waveform" : "waveform.slash")
                    .font(.caption2)
                    .foregroundStyle(amplitude > 0.002 ? Color(red: 0.15, green: 0.85, blue: 0.40) : .secondary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(white: 0.14))

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.15, green: 0.85, blue: 0.40),
                                        Color(red: 0.85, green: 0.72, blue: 0.35)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * normalizedLevel)))
                            .animation(.easeOut(duration: 0.08), value: normalizedLevel)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 28)
            .padding(.top, 2)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    status == .inTune ? status.color.opacity(0.6) : Color(white: 0.25),
                                    Color(white: 0.12)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var gaugeHeader: some View {
        Text(stringName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)

        Spacer()

        Text(String(localized: "gauge.target_hz", defaultValue: "Hedef: \(targetHz.formatted(.number.precision(.fractionLength(1)))) Hz"))
            .font(.caption.weight(.medium).monospaced())
            .foregroundStyle(.secondary.opacity(0.8))
    }
}

// MARK: - Gauge Arc with Needle and Ticks
private struct GaugeArcShape: View {
    let cents: Double
    let status: TuningStatus
    let tolerance: Double

    // Angle range: -60 degrees (left, -50 cents) to +60 degrees (right, +50 cents)
    private var needleAngle: Angle {
        let clampedCents = max(-50.0, min(50.0, cents))
        let degrees = (clampedCents / 50.0) * 55.0
        return .degrees(degrees)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let center = CGPoint(x: width / 2.0, y: height + 30)
            let radius = width * 0.46

            ZStack {
                // Background Track Arc
                Path { path in
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(180 + 35),
                        endAngle: .degrees(360 - 35),
                        clockwise: false
                    )
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.5, blue: 0.15),
                            Color(red: 0.15, green: 0.85, blue: 0.4),
                            Color(red: 0.35, green: 0.65, blue: 0.95)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .opacity(0.45)

                // In-tune Center Sweet-Spot Arc Segment, sized to the actual tolerance setting
                Path { path in
                    let sweetDegrees = (min(tolerance, 50.0) / 50.0) * 55.0
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(270 - sweetDegrees),
                        endAngle: .degrees(270 + sweetDegrees),
                        clockwise: false
                    )
                }
                .stroke(
                    Color(red: 0.15, green: 0.85, blue: 0.40),
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .shadow(color: Color(red: 0.15, green: 0.85, blue: 0.40), radius: 4)

                // Tick Marks
                ForEach([-50, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50], id: \.self) { tickCents in
                    let tickAngle = ((Double(tickCents) / 50.0) * 55.0) - 90.0
                    let rad = tickAngle * .pi / 180.0
                    let isMajor = (tickCents == 0 || abs(tickCents) == 50 || abs(tickCents) == 20)
                    let innerR = radius - (isMajor ? 12 : 7)
                    let outerR = radius + 3

                    let p1 = CGPoint(
                        x: center.x + innerR * cos(rad),
                        y: center.y + innerR * sin(rad)
                    )
                    let p2 = CGPoint(
                        x: center.x + outerR * cos(rad),
                        y: center.y + outerR * sin(rad)
                    )

                    Path { p in
                        p.move(to: p1)
                        p.addLine(to: p2)
                    }
                    .stroke(
                        tickCents == 0 ? Color(red: 0.15, green: 0.85, blue: 0.40) : Color(white: 0.4),
                        lineWidth: isMajor ? 2.0 : 1.0
                    )
                }

                // Needle Indicator
                NeedleView(angle: needleAngle, length: radius - 6, status: status)
                    .position(center)
                    .animation(.spring(response: 0.22, dampingFraction: 0.72), value: cents)
            }
        }
    }
}

// MARK: - Needle
private struct NeedleView: View {
    let angle: Angle
    let length: CGFloat
    let status: TuningStatus

    var body: some View {
        ZStack {
            // Glowing Needle Line
            VStack(spacing: 0) {
                // Needle tip dot
                Circle()
                    .fill(status.color)
                    .frame(width: 8, height: 8)
                    .shadow(color: status.color, radius: 6)

                // Needle shaft
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [status.color, status.color.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: length)
            }
            .offset(y: -length / 2)

            // Center Pivot
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                )
        }
        .rotationEffect(angle)
    }
}
