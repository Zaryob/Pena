import SwiftUI

public struct AcademyCatalogView: View {
    public var onOpenTuner: (() -> Void)? = nil

    @State private var courses: [GuitarCourse] = []
    @State private var selectedCourse: GuitarCourse? = nil

    private var progressStore: CourseProgressStore {
        CourseProgressStore.shared
    }

    public init(onOpenTuner: (() -> Void)? = nil) {
        self.onOpenTuner = onOpenTuner
    }

    private var activeCourse: GuitarCourse? {
        courses.first { $0.id == progressStore.activeCourseId } ?? courses.first
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Top Coach & Motivation Banner
                        coachBanner

                        // Active Course Resume Spotlight
                        if let current = activeCourse {
                            activeCourseSpotlight(current)
                        }

                        // 10-Course Catalog Section
                        catalogSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle("Gitar Akademisi")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color(red: 0.07, green: 0.07, blue: 0.09), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear {
                if courses.isEmpty {
                    courses = CourseRepository.shared.loadAllCourses()
                }
            }
        }
    }

    private var coachBanner: some View {
        HStack(spacing: 14) {
            Text("🎸")
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 3) {
                Text("Günün Tavsiyesi")
                    .font(.caption.weight(.heavy))
                    .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))

                Text("Günde 20 dakika düzenli pratik, haftada bir gün saatlerce çalmaktan 10 kat daha hızlı kas hafızası kazandırır.")
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.85))
                    .lineSpacing(2)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(red: 0.95, green: 0.45, blue: 0.25).opacity(0.12))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.95, green: 0.45, blue: 0.25).opacity(0.35), lineWidth: 1)
        )
    }

    private func activeCourseSpotlight(_ course: GuitarCourse) -> some View {
        let percent = progressStore.progressPercentage(courseId: course.id)
        let count = progressStore.completedCount(courseId: course.id)
        let streak = progressStore.currentStreak(courseId: course.id)

        return NavigationLink(destination: CourseRoadmapView(course: course, onOpenTuner: onOpenTuner)) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DEVAM EDEN YOLCULUK")
                            .font(.caption2.weight(.heavy))
                            .tracking(1.5)
                            .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                        Text(course.title)
                            .font(.title3.weight(.bold))
                            .foregroundColor(.white)
                    }
                    Spacer()

                    if streak > 0 {
                        HStack(spacing: 4) {
                            Text("🔥")
                            Text("\(streak) Gün")
                                .font(.caption.weight(.heavy))
                                .foregroundColor(Color(red: 0.95, green: 0.45, blue: 0.25))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(white: 0.14))
                        .cornerRadius(6)
                    }
                }

                Text(course.subtitle)
                    .font(.footnote)
                    .foregroundColor(Color(white: 0.75))
                    .lineLimit(2)

                HStack {
                    // Progress bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(count)/30 Gün")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Color(white: 0.6))
                            Spacer()
                            Text("%\(Int(percent * 100))")
                                .font(.caption2.weight(.heavy))
                                .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                        }
                        ProgressView(value: percent)
                            .tint(Color(red: 0.85, green: 0.72, blue: 0.35))
                    }

                    Spacer(minLength: 16)

                    HStack(spacing: 4) {
                        Text("Devam Et")
                            .font(.caption.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.85, green: 0.72, blue: 0.35))
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.16, green: 0.14, blue: 0.19), Color(red: 0.11, green: 0.10, blue: 0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(red: 0.85, green: 0.72, blue: 0.35).opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tüm Öğrenim Tarzları (10 Tarz)")
                .font(.headline.weight(.bold))
                .foregroundColor(.white)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(courses) { course in
                    courseCard(course)
                }
            }
        }
    }

    private func courseCard(_ course: GuitarCourse) -> some View {
        let count = progressStore.completedCount(courseId: course.id)
        let percent = progressStore.progressPercentage(courseId: course.id)

        return NavigationLink(destination: CourseRoadmapView(course: course, onOpenTuner: onOpenTuner)) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: course.iconName)
                        .font(.title3)
                        .foregroundColor(Color(red: 0.85, green: 0.72, blue: 0.35))
                    Spacer()

                    // Circular mini progress
                    ZStack {
                        Circle()
                            .stroke(Color(white: 0.2), lineWidth: 3)
                            .frame(width: 24, height: 24)
                        Circle()
                            .trim(from: 0, to: CGFloat(percent))
                            .stroke(Color(red: 0.85, green: 0.72, blue: 0.35), lineWidth: 3)
                            .frame(width: 24, height: 24)
                            .rotationEffect(.degrees(-90))
                    }
                }

                Text(course.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(course.subtitle)
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                HStack {
                    Text(course.level)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(white: 0.16))
                        .foregroundColor(Color(white: 0.8))
                        .cornerRadius(4)

                    Spacer()

                    Text("\(count)/30")
                        .font(.caption2.weight(.heavy))
                        .foregroundColor(count > 0 ? Color(red: 0.85, green: 0.72, blue: 0.35) : Color(white: 0.4))
                }
            }
            .padding(14)
            .frame(height: 165)
            .background(Color(red: 0.12, green: 0.11, blue: 0.14))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(white: 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
