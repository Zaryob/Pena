import SwiftUI
import Combine

public struct HapticMetronomeView: View {
    @State private var bpm: Int = 72
    @State private var timeSignature: Int = 4 // 2, 3, 4, 6
    @State private var isRunning = false
    @State private var currentBeat: Int = 0
    @State private var tapTimes: [Date] = []

    // Audio and haptics
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    @State private var timerSubscription: AnyCancellable? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header & BPM display
            VStack(spacing: 6) {
                Text("PRATİK METRONOMU")
                    .font(.caption.weight(.heavy))
                    .tracking(2)
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text("\(bpm)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("BPM")
                        .font(.headline.weight(.semibold))
                        .foregroundColor(Color(white: 0.6))
                }
            }
            .padding(.top, 10)

            // Beat Indicator Dots
            HStack(spacing: 14) {
                ForEach(0..<timeSignature, id: \.self) { beat in
                    Circle()
                        .fill(beatColor(for: beat))
                        .frame(width: beatSize(for: beat), height: beatSize(for: beat))
                        .animation(.spring(response: 0.15, dampingFraction: 0.5), value: currentBeat)
                }
            }
            .frame(height: 30)

            // BPM Slider & Step buttons
            HStack(spacing: 12) {
                stepButton(label: "-5", delta: -5)
                stepButton(label: "-1", delta: -1)

                Slider(value: Binding(
                    get: { Double(bpm) },
                    set: { bpm = Int($0) }
                ), in: 40...208, step: 1)
                .tint(Color(red: 0.85, green: 0.72, blue: 0.35))

                stepButton(label: "+1", delta: 1)
                stepButton(label: "+5", delta: 5)
            }
            .padding(.horizontal, 16)

            // Controls & Tap Tempo
            HStack(spacing: 16) {
                // Play / Pause button
                Button {
                    togglePlayback()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            .font(.title3)
                        Text(isRunning ? "Durdur" : "Başlat")
                            .font(.headline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isRunning ? Color(red: 0.85, green: 0.35, blue: 0.25) : Color(red: 0.85, green: 0.72, blue: 0.35))
                    .foregroundColor(.black)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Tap Tempo button
                Button {
                    handleTap()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "hand.tap.fill")
                            .font(.body)
                        Text("Tap")
                            .font(.caption.weight(.bold))
                    }
                    .frame(width: 65, height: 50)
                    .background(Color(white: 0.15))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(white: 0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)

            // Time Signature Picker
            HStack(spacing: 10) {
                Text("Ölçü:")
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.6))

                ForEach([2, 3, 4, 6], id: \.self) { sig in
                    Button {
                        timeSignature = sig
                        currentBeat = 0
                    } label: {
                        Text("\(sig)/\(sig == 6 ? 8 : 4)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(timeSignature == sig ? Color(red: 0.85, green: 0.72, blue: 0.35) : Color(white: 0.15))
                            .foregroundColor(timeSignature == sig ? .black : .white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
        .onDisappear {
            stopMetronome()
        }
        .onChange(of: bpm) { _, _ in
            if isRunning {
                startMetronome()
            }
        }
    }

    private func stepButton(label: String, delta: Int) -> some View {
        Button {
            bpm = max(40, min(208, bpm + delta))
        } label: {
            Text(label)
                .font(.caption.weight(.bold))
                .frame(width: 34, height: 34)
                .background(Color(white: 0.18))
                .foregroundColor(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func beatColor(for beat: Int) -> Color {
        guard isRunning && currentBeat == beat else {
            return Color(white: 0.25)
        }
        return beat == 0 ? Color(red: 0.95, green: 0.45, blue: 0.25) : Color(red: 0.85, green: 0.72, blue: 0.35)
    }

    private func beatSize(for beat: Int) -> CGFloat {
        if isRunning && currentBeat == beat {
            return beat == 0 ? 18 : 15
        }
        return 11
    }

    private func togglePlayback() {
        if isRunning {
            stopMetronome()
        } else {
            startMetronome()
        }
    }

    private func startMetronome() {
        stopMetronome()
        isRunning = true
        currentBeat = 0
        heavyHaptic.prepare()
        lightHaptic.prepare()

        let interval = 60.0 / Double(bpm)
        timerSubscription = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                tick()
            }
    }

    private func stopMetronome() {
        isRunning = false
        timerSubscription?.cancel()
        timerSubscription = nil
        currentBeat = 0
    }

    private func tick() {
        let isAccent = (currentBeat == 0)
        if isAccent {
            heavyHaptic.impactOccurred()
        } else {
            lightHaptic.impactOccurred()
        }

        currentBeat = (currentBeat + 1) % timeSignature
    }

    private func handleTap() {
        let now = Date()
        tapTimes.append(now)
        if tapTimes.count > 5 { tapTimes.removeFirst() }

        if tapTimes.count >= 2 {
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                let diff = tapTimes[i].timeIntervalSince(tapTimes[i - 1])
                if diff < 2.5 { intervals.append(diff) }
            }
            if !intervals.isEmpty {
                let avg = intervals.reduce(0, +) / Double(intervals.count)
                let calculatedBpm = Int(round(60.0 / avg))
                if (40...208).contains(calculatedBpm) {
                    bpm = calculatedBpm
                }
            }
        }
    }
}
