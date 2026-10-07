import SwiftUI

public struct CourseRoadmapView: View {
    public let course: GuitarCourse
    public var onOpenTuner: (() -> Void)? = nil

    @State private var selectedDayNumber: Int = 1
    @State private var activeLessonDay: CourseDay? = nil

    private var progressStore: CourseProgressStore {
        CourseProgressStore.shared
    }

    public init(course: GuitarCourse, onOpenTuner: (() -> Void)? = nil) {
        self.course = course
        self.onOpenTuner = onOpenTuner
    }

    private var completedDays: Set<Int> {
        progressStore.completedDaysByCourse[course.id] ?? Set<Int>()
    }

    private var selectedDay: CourseDay {
        course.days.first { $0.dayNumber == selectedDayNumber } ?? course.days[0]
    }

    public var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Course Header Card
                headerCard

                // Interactive Fretboard Roadmap (30 Days)
                FretboardRoadmapView(
                    completedDays: completedDays,
                    selectedDay: $selectedDayNumber
                )
                .padding(.horizontal, 16)

                // Active Day Summary Card (Quick Jump)
                selectedDayCard
                    .padding(.horizontal, 16)

                // Practice Example & Tab
                if let pe = course.practiceExample {
                    practiceExampleCard(pe)
                        .padding(.horizontal, 16)
                }

                // 4-Week Curriculum List
                weeksCurriculumSection
                    .padding(.horizontal, 16)

                // Glossary Accordion
                glossarySection
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.09), for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $activeLessonDay) { day in
            NavigationStack {
                DayLessonDetailView(course: course, day: day, onOpenTuner: onOpenTuner)
                    .navigationTitle("Gün \(day.dayNumber) Dersi")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Kapat") { activeLessonDay = nil }
                                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                        }
                    }
            }
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(course.level, systemImage: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                Spacer()
                Text(course.dailyMinutes.displayString)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(white: 0.18))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            Text(course.subtitle)
                .font(.subheadline)
                .foregroundColor(Color(white: 0.8))

            // Month goal
            VStack(alignment: .leading, spacing: 4) {
                Text("Ay Sonu Hedefi:")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                Text(course.monthGoal)
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.75))
                    .lineSpacing(2)
            }
            .padding(12)
            .background(Color(white: 0.08))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(red: 0.12, green: 0.11, blue: 0.14))
        .cornerRadius(14)
        .padding(.horizontal, 16)
    }

    private var selectedDayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEÇİLİ GÜN: \(selectedDay.dayNumber)")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.5)
                        .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                    Text(selectedDay.title)
                        .font(.headline.weight(.bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    activeLessonDay = selectedDay
                } label: {
                    HStack(spacing: 4) {
                        Text("Dersi Aç")
                        Image(systemName: "chevron.right")
                    }
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.85, green: 0.72, blue: 0.35))
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Text(selectedDay.goal)
                .font(.footnote)
                .foregroundColor(Color(white: 0.75))

            // Progress status tag
            HStack {
                if completedDays.contains(selectedDay.dayNumber) {
                    Label("Tamamlandı", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color(red: 0.25, green: 0.80, blue: 0.45))
                } else {
                    Label("Henüz Başlanmadı", systemImage: "circle")
                        .font(.caption)
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Text("\(selectedDay.totalMinutes) Dakika")
                    .font(.caption)
                    .foregroundColor(Color(white: 0.5))
            }
        }
        .padding(14)
        .background(Color(red: 0.14, green: 0.13, blue: 0.17))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.4), lineWidth: 1)
        )
    }

    private func practiceExampleCard(_ pe: PracticeExample) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Örnek Alıştırma & Tab", systemImage: "music.note")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                Spacer()
            }

            Text(pe.title)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.white)

            ScrollView(.horizontal, showsIndicators: true) {
                Text(pe.notation)
                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.90, blue: 0.82))
                    .padding(12)
                    .background(Color(red: 0.09, green: 0.08, blue: 0.10))
                    .cornerRadius(8)
            }

            Text(pe.howTo)
                .font(.caption)
                .foregroundColor(Color(white: 0.75))
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.11, blue: 0.14))
        .cornerRadius(12)
    }

    private var weeksCurriculumSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Haftalık Öğrenim Planı")
                .font(.headline.weight(.bold))
                .foregroundColor(.white)

            let ranges = [[1, 7], [8, 14], [15, 21], [22, 30]]
            ForEach(0..<min(course.weeks.count, 4), id: \.self) { weekIdx in
                let w = course.weeks[weekIdx]
                let start = ranges[weekIdx][0]
                let end = ranges[weekIdx][1]
                let daysInWeek = course.days.filter { ($0.dayNumber >= start) && ($0.dayNumber <= end) }

                DisclosureGroup {
                    VStack(spacing: 8) {
                        ForEach(daysInWeek) { day in
                            dayRow(day: day)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(weekIdx + 1). Hafta")
                                .font(.subheadline.weight(.bold))
                                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                            Spacer()
                            Text("\(daysInWeek.filter { completedDays.contains($0.dayNumber) }.count)/\(daysInWeek.count)")
                                .font(.caption.weight(.bold))
                                .foregroundColor(Color(white: 0.6))
                        }
                        Text(w.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(14)
                .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                .cornerRadius(10)
            }
        }
    }

    private func dayRow(day: CourseDay) -> some View {
        let isDone = completedDays.contains(day.dayNumber)
        return Button {
            activeLessonDay = day
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isDone ? Color(red: 0.25, green: 0.80, blue: 0.45) : Color(white: 0.35))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Gün \(day.dayNumber) · \(day.title)")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                    Text("\(day.totalMinutes) dk")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.5))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.4))
            }
            .padding(10)
            .background(Color(white: 0.08))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var glossarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Müzikal Terimler Sözlüğü")
                .font(.headline.weight(.bold))
                .foregroundColor(.white)

            ForEach(course.glossary) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.term)
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                    Text(item.meaning)
                        .font(.footnote)
                        .foregroundColor(Color(white: 0.8))
                    HStack(spacing: 4) {
                        Text("Mini Deneme:")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))
                        Text(item.exercise)
                            .font(.caption2)
                            .foregroundColor(Color(white: 0.7))
                    }
                    .padding(.top, 2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(white: 0.09))
                .cornerRadius(8)
            }
        }
    }
}
