import SwiftUI
import Combine

public struct PracticeSessionView: View {
    public let day: CourseDay
    public let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var secondsRemaining: Int
    @State private var totalSeconds: Int
    @State private var isPaused: Bool = false
    @State private var timerSubscription: AnyCancellable? = nil
    @State private var isCompleted: Bool = false
    @State private var showConfetti: Bool = false

    public init(day: CourseDay, onComplete: @escaping () -> Void) {
        self.day = day
        self.onComplete = onComplete
        let total = day.totalMinutes * 60
        self._secondsRemaining = State(initialValue: max(60, total))
        self._totalSeconds = State(initialValue: max(60, total))
    }

    private var progress: Double {
        guard totalSeconds > 0 else { return 1.0 }
        return 1.0 - (Double(secondsRemaining) / Double(totalSeconds))
    }

    private var currentBlock: (index: Int, block: DayBlock)? {
        var elapsed = totalSeconds - secondsRemaining
        for (i, b) in day.blocks.enumerated() {
            let blockSecs = b.min * 60
            if elapsed < blockSecs {
                return (i, b)
            }
            elapsed -= blockSecs
        }
        return day.blocks.indices.contains(0) ? (0, day.blocks[0]) : nil
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Top close button & Day title
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GÜN \(day.dayNumber) PRATİK SEANSI")
                            .font(.caption2.weight(.heavy))
                            .tracking(1.5)
                            .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                        Text(day.title)
                            .font(.headline.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(white: 0.4))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Circular Progress Timer
                ZStack {
                    Circle()
                        .stroke(Color(white: 0.15), lineWidth: 14)
                        .frame(width: 230, height: 230)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.72, blue: 0.35), Color(red: 0.95, green: 0.45, blue: 0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .frame(width: 230, height: 230)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.0), value: progress)

                    VStack(spacing: 6) {
                        Text(timeString(from: secondsRemaining))
                            .font(.system(size: 46, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        Text(isPaused ? "DURAKLATILDI" : "ODAKLAN")
                            .font(.caption.weight(.bold))
                            .foregroundColor(isPaused ? Color(red: 0.85, green: 0.4, blue: 0.3) : Color(red: 0.85, green: 0.72, blue: 0.35))
                    }
                }

                // Current Activity Block Info
                if let current = currentBlock {
                    VStack(spacing: 6) {
                        Text("Adım \(current.index + 1) / \(day.blocks.count)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(white: 0.6))
                        Text(current.block.text)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .background(Color(white: 0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                }

                Spacer()

                // Controls
                HStack(spacing: 20) {
                    Button {
                        togglePause()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isPaused ? "play.fill" : "pause.fill")
                            Text(isPaused ? "Devam Et" : "Duraklat")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(white: 0.2))
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)

                    Button {
                        finishEarly()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Tamamla")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 0.25, green: 0.80, blue: 0.45))
                        .foregroundColor(.black)
                        .cornerRadius(14)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }

            // Confetti Overlay when completed
            if showConfetti {
                celebrationOverlay
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    private var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 72))
                Text("Harika İş Çıkardın!")
                    .font(.title.weight(.bold))
                    .foregroundColor(.white)
                Text("Günün çalışmasını başarıyla tamamladın.")
                    .font(.body)
                    .foregroundColor(Color(white: 0.7))

                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text("Günü İşaretle ve Kapat")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.85, green: 0.72, blue: 0.35))
                        .cornerRadius(12)
                }
                .padding(.top, 10)
            }
        }
        .transition(.opacity)
    }

    private func timeString(from totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimer() {
        stopTimer()
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if !isPaused && secondsRemaining > 0 {
                    secondsRemaining -= 1
                    if secondsRemaining == 0 {
                        completeSession()
                    }
                }
            }
    }

    private func stopTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }

    private func togglePause() {
        isPaused.toggle()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func finishEarly() {
        completeSession()
    }

    private func completeSession() {
        stopTimer()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation {
            showConfetti = true
        }
    }
}
