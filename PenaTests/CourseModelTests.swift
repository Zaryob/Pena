import Foundation
import Testing
@testable import Pena

@Suite("Course Model & Progress Tests")
struct CourseModelTests {

    @Test("ChordDatabase has valid guitar string structures")
    func chordDatabaseIntegrity() {
        let chords = ChordDatabase.allChords
        #expect(!chords.isEmpty)

        for chord in chords {
            #expect(chord.frets.count == 6)
            #expect(!chord.name.isEmpty)
            #expect(chord.baseFret >= 1)
        }

        let e9 = chords.first { $0.name == "E9" }
        #expect(e9 != nil)
        #expect(e9?.baseFret ?? 1 > 1) // Should have offset base fret
    }

    @Test("CourseProgressStore tracks completed days, percentage, streaks, and notes")
    func progressStoreCalculations() {
        let store = CourseProgressStore()
        let testCourse = "test_course"

        // Initially zero
        #expect(store.completedCount(courseId: testCourse) == 0)
        #expect(store.progressPercentage(courseId: testCourse) == 0.0)
        #expect(store.currentStreak(courseId: testCourse) == 0)

        // Complete days 1, 2, 3
        store.setDayCompleted(courseId: testCourse, day: 1, completed: true)
        store.setDayCompleted(courseId: testCourse, day: 2, completed: true)
        store.setDayCompleted(courseId: testCourse, day: 3, completed: true)

        #expect(store.isDayCompleted(courseId: testCourse, day: 1))
        #expect(store.isDayCompleted(courseId: testCourse, day: 2))
        #expect(store.isDayCompleted(courseId: testCourse, day: 3))
        #expect(!store.isDayCompleted(courseId: testCourse, day: 4))
        #expect(store.completedCount(courseId: testCourse) == 3)
        #expect(store.progressPercentage(courseId: testCourse) == 0.1) // 3 / 30
        #expect(store.currentStreak(courseId: testCourse) == 3)

        // Toggle day 2 off
        store.toggleDay(courseId: testCourse, day: 2)
        #expect(!store.isDayCompleted(courseId: testCourse, day: 2))
        #expect(store.completedCount(courseId: testCourse) == 2)
        #expect(store.currentStreak(courseId: testCourse) == 1) // Streak broken at day 2

        // User notes
        store.saveNote(courseId: testCourse, day: 1, text: "Harika bir gündü!")
        #expect(store.getNote(courseId: testCourse, day: 1) == "Harika bir gündü!")
    }

    @Test("GuitarCourse decodes correctly from JSON")
    func courseDecodingFromData() throws {
        let sampleJSON = """
        {
          "id": "sample",
          "title": "Örnek Kurs",
          "subtitle": "Alt başlık",
          "instrument": "Klasik Gitar",
          "level": "Başlangıç",
          "dailyMinutes": 20,
          "monthGoal": "Hedef",
          "prerequisites": "Ön bilgi yok",
          "materials": ["Gitar", "Metronom"],
          "weeks": [
            {
              "title": "1. Hafta",
              "focus": "Temel",
              "exitCriteria": "Kriter"
            }
          ],
          "days": [
            {
              "title": "1. Gün",
              "goal": "Hedef 1",
              "blocks": [
                { "min": 5, "text": "Isınma" },
                { "min": 15, "text": "Çalışma" }
              ],
              "why": "Neden",
              "steps": ["Adım 1"],
              "watch": ["Dikkat 1"],
              "check": ["Kontrol 1"]
            }
          ],
          "glossary": [
            { "term": "Akor", "meaning": "Sesler", "exercise": "Bas" }
          ],
          "nextMonth": ["Devam"],
          "sources": [
            { "title": "Kaynak", "url": "https://example.com", "usedFor": "Eğitim" }
          ],
          "practiceExample": {
            "title": "Alıştırma",
            "notation": "Tab",
            "howTo": "Rehber"
          }
        }
        """

        let data = sampleJSON.data(using: .utf8)!
        let course = try JSONDecoder().decode(GuitarCourse.self, from: data)

        #expect(course.id == "sample")
        #expect(course.title == "Örnek Kurs")
        #expect(course.days.count == 1)
        #expect(course.days[0].totalMinutes == 20)
        #expect(course.iconName == "music.note")
    }
}
