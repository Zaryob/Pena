import SwiftUI

public struct DayLessonDetailView: View {
    public let course: GuitarCourse
    public let day: CourseDay
    public var onOpenTuner: (() -> Void)? = nil

    @State private var showPracticeSession = false
    @State private var userNote: String = ""
    @State private var checkedItems: Set<Int> = []

    private var progressStore: CourseProgressStore {
        CourseProgressStore.shared
    }

    public init(course: GuitarCourse, day: CourseDay, onOpenTuner: (() -> Void)? = nil) {
        self.course = course
        self.day = day
        self.onOpenTuner = onOpenTuner
    }

    private var isCompleted: Bool {
        progressStore.isDayCompleted(courseId: course.id, day: day.dayNumber)
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Header card
                headerCard

                // Action buttons: Start Timer & Quick Tune
                actionButtons

                // Activity breakdown blocks
                activityBlocksSection

                // Why box
                whySection

                // Step-by-step
                stepsSection

                // Watch out
                watchSection

                // Self-check checklist
                checklistSection

                // Daily Note Journal
                noteJournalSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        .sheet(isPresented: $showPracticeSession) {
            PracticeSessionView(day: day) {
                progressStore.setDayCompleted(courseId: course.id, day: day.dayNumber, completed: true)
            }
        }
        .onAppear {
            userNote = progressStore.getNote(courseId: course.id, day: day.dayNumber)
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GÜN \(day.dayNumber)")
                    .font(.caption.weight(.heavy))
                    .tracking(1.5)
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                Spacer()
                Text("\(day.totalMinutes) Dakika")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.18))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            Text(day.title)
                .font(.title2.weight(.bold))
                .foregroundColor(.white)

            HStack(spacing: 8) {
                Image(systemName: "target")
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                Text(day.goal)
                    .font(.subheadline)
                    .foregroundColor(Color(white: 0.8))
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.12, green: 0.11, blue: 0.14))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(white: 0.2), lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Start practice button
            Button {
                showPracticeSession = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    Text("Pratiği Başlat (\(day.totalMinutes) dk)")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(red: 0.85, green: 0.72, blue: 0.35))
                .foregroundColor(.black)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            // Quick Tune link
            if let onOpenTuner = onOpenTuner {
                Button {
                    onOpenTuner()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "tuningfork")
                        Text("Akortla")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.16))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Completion checkmark toggle
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                progressStore.toggleDay(courseId: course.id, day: day.dayNumber)
            } label: {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? Color(red: 0.25, green: 0.80, blue: 0.45) : Color(white: 0.4))
                    .frame(width: 44, height: 44)
                    .background(Color(white: 0.14))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }

    private var activityBlocksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Zaman Planı")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))

            VStack(spacing: 8) {
                ForEach(Array(day.blocks.enumerated()), id: \.offset) { idx, block in
                    HStack(spacing: 12) {
                        Text("\(block.min) dk")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 0.85, green: 0.72, blue: 0.35))
                            .cornerRadius(6)

                        Text(block.text)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(white: 0.11))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var whySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Neden Bunu Yapıyoruz?", systemImage: "lightbulb.fill")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color(red: 0.95, green: 0.75, blue: 0.3))

            Text(day.why)
                .font(.subheadline)
                .foregroundColor(Color(white: 0.85))
                .lineSpacing(3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.12))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.35), lineWidth: 1)
        )
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Adım Adım Rehber")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)

            ForEach(Array(day.steps.enumerated()), id: \.offset) { idx, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1).")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                    Text(step)
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.85))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11))
        .cornerRadius(10)
    }

    private var watchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Dikkat Edilecek Noktalar", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))

            ForEach(day.watch, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))
                    Text(item)
                        .font(.subheadline)
                        .foregroundColor(Color(white: 0.85))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.95, green: 0.45, blue: 0.25).opacity(0.1))
        .cornerRadius(10)
    }

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bitirdiğinde Kontrol Et (Öz Değerlendirme)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.white)

            ForEach(Array(day.check.enumerated()), id: \.offset) { idx, check in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if checkedItems.contains(idx) {
                        checkedItems.remove(idx)
                    } else {
                        checkedItems.insert(idx)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: checkedItems.contains(idx) ? "checkmark.square.fill" : "square")
                            .font(.body)
                            .foregroundColor(checkedItems.contains(idx) ? Color(red: 0.25, green: 0.80, blue: 0.45) : Color(white: 0.4))

                        Text(check)
                            .font(.subheadline)
                            .foregroundColor(Color(white: 0.85))
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.11))
        .cornerRadius(10)
    }

    private var noteJournalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Günün Not Defteri", systemImage: "pencil.and.list.clipboard")
                .font(.subheadline.weight(.bold))
                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))

            TextField("Bugün nasıl hissettin? Hangi akor veya vuruş zorladı?...", text: $userNote, axis: .vertical)
                .lineLimit(2...5)
                .font(.subheadline)
                .padding(12)
                .background(Color(white: 0.14))
                .foregroundColor(.white)
                .cornerRadius(8)
                .onChange(of: userNote) { _, newValue in
                    progressStore.saveNote(courseId: course.id, day: day.dayNumber, text: newValue)
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.09))
        .cornerRadius(10)
    }
}
