import Foundation
import Observation

@Observable
public final class CourseProgressStore {
    public static let shared = CourseProgressStore()

    public var completedDaysByCourse: [String: Set<Int>] = [:]
    public var userNotesByCourse: [String: [String: String]] = [:] // courseId -> "day_N" -> note
    public var activeCourseId: String = "turku"

    private let completedKey = "pena_completed_days_v1"
    private let notesKey = "pena_user_notes_v1"
    private let activeCourseKey = "pena_active_course_v1"

    public init() {
        loadFromDefaults()
    }

    public func isDayCompleted(courseId: String, day: Int) -> Bool {
        completedDaysByCourse[courseId]?.contains(day) ?? false
    }

    public func toggleDay(courseId: String, day: Int) {
        var set = completedDaysByCourse[courseId] ?? Set<Int>()
        if set.contains(day) {
            set.remove(day)
        } else {
            set.insert(day)
        }
        completedDaysByCourse[courseId] = set
        saveToDefaults()
    }

    public func setDayCompleted(courseId: String, day: Int, completed: Bool) {
        var set = completedDaysByCourse[courseId] ?? Set<Int>()
        if completed {
            set.insert(day)
        } else {
            set.remove(day)
        }
        completedDaysByCourse[courseId] = set
        saveToDefaults()
    }

    public func completedCount(courseId: String) -> Int {
        completedDaysByCourse[courseId]?.count ?? 0
    }

    public func progressPercentage(courseId: String) -> Double {
        let count = Double(completedCount(courseId: courseId))
        return min(1.0, count / 30.0)
    }

    public func currentStreak(courseId: String) -> Int {
        guard let set = completedDaysByCourse[courseId] else { return 0 }
        var streak = 0
        for day in 1...30 {
            if set.contains(day) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    public func getNote(courseId: String, day: Int) -> String {
        userNotesByCourse[courseId]?["day_\(day)"] ?? ""
    }

    public func saveNote(courseId: String, day: Int, text: String) {
        var courseNotes = userNotesByCourse[courseId] ?? [:]
        courseNotes["day_\(day)"] = text
        userNotesByCourse[courseId] = courseNotes
        saveToDefaults()
    }

    // MARK: - Persistence
    private func saveToDefaults() {
        let defaults = UserDefaults.standard

        // Convert [String: Set<Int>] to [String: [Int]]
        let serializedDays = completedDaysByCourse.mapValues { Array($0) }
        if let daysData = try? JSONEncoder().encode(serializedDays) {
            defaults.set(daysData, forKey: completedKey)
        }

        if let notesData = try? JSONEncoder().encode(userNotesByCourse) {
            defaults.set(notesData, forKey: notesKey)
        }

        defaults.set(activeCourseId, forKey: activeCourseKey)
    }

    private func loadFromDefaults() {
        let defaults = UserDefaults.standard

        if let daysData = defaults.data(forKey: completedKey),
           let decoded = try? JSONDecoder().decode([String: [Int]].self, from: daysData) {
            completedDaysByCourse = decoded.mapValues { Set($0) }
        }

        if let notesData = defaults.data(forKey: notesKey),
           let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: notesData) {
            userNotesByCourse = decoded
        }

        if let active = defaults.string(forKey: activeCourseKey) {
            activeCourseId = active
        }
    }
}
