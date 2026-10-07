import Foundation

// MARK: - Flexible Decoders for Robust JSON Parsing

public enum StringOrArray: Codable, Hashable, Sendable {
    case single(String)
    case multiple([String])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .single(string)
        } else if let array = try? container.decode([String].self) {
            self = .multiple(array)
        } else {
            throw DecodingError.typeMismatch(
                StringOrArray.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or [String]")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let str):
            try container.encode(str)
        case .multiple(let arr):
            try container.encode(arr)
        }
    }

    public var asList: [String] {
        switch self {
        case .single(let str): return [str]
        case .multiple(let arr): return arr
        }
    }

    public var asText: String {
        switch self {
        case .single(let str): return str
        case .multiple(let arr): return arr.joined(separator: " · ")
        }
    }
}

public enum StringOrInt: Codable, Hashable, Sendable {
    case string(String)
    case int(Int)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else {
            throw DecodingError.typeMismatch(
                StringOrInt.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int")
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        }
    }

    public var displayString: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return "\(i) dakika"
        }
    }
}

// MARK: - Course Data Structures

public struct DayBlock: Codable, Hashable, Sendable {
    public let min: Int
    public let text: String

    public init(min: Int, text: String) {
        self.min = min
        self.text = text
    }
}

public struct CourseDay: Identifiable, Codable, Hashable, Sendable {
    public var id: Int { dayNumber }
    public var dayNumber: Int = 0 // assigned upon loading if missing in JSON
    public let title: String
    public let goal: String
    public let blocks: [DayBlock]
    public let why: String
    public let steps: [String]
    public let watch: [String]
    public let check: [String]

    enum CodingKeys: String, CodingKey {
        case dayNumber = "day"
        case title, goal, blocks, why, steps, watch, check
    }

    public init(
        dayNumber: Int = 0,
        title: String,
        goal: String,
        blocks: [DayBlock],
        why: String,
        steps: [String],
        watch: [String],
        check: [String]
    ) {
        self.dayNumber = dayNumber
        self.title = title
        self.goal = goal
        self.blocks = blocks
        self.why = why
        self.steps = steps
        self.watch = watch
        self.check = check
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.dayNumber = try container.decodeIfPresent(Int.self, forKey: .dayNumber) ?? 0
        self.title = try container.decode(String.self, forKey: .title)
        self.goal = try container.decode(String.self, forKey: .goal)
        self.blocks = try container.decode([DayBlock].self, forKey: .blocks)
        self.why = try container.decode(String.self, forKey: .why)
        self.steps = try container.decode([String].self, forKey: .steps)
        self.watch = try container.decode([String].self, forKey: .watch)
        self.check = try container.decode([String].self, forKey: .check)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if dayNumber > 0 {
            try container.encode(dayNumber, forKey: .dayNumber)
        }
        try container.encode(title, forKey: .title)
        try container.encode(goal, forKey: .goal)
        try container.encode(blocks, forKey: .blocks)
        try container.encode(why, forKey: .why)
        try container.encode(steps, forKey: .steps)
        try container.encode(watch, forKey: .watch)
        try container.encode(check, forKey: .check)
    }

    public var totalMinutes: Int {
        blocks.reduce(0) { $0 + $1.min }
    }
}

public struct CourseWeek: Identifiable, Codable, Hashable, Sendable {
    public var id: String { title }
    public let title: String
    public let focus: String
    public let exitCriteria: StringOrArray?
}

public struct PracticeExample: Codable, Hashable, Sendable {
    public let title: String
    public let notation: String
    public let howTo: String
}

public struct GlossaryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { term }
    public let term: String
    public let meaning: String
    public let exercise: String
}

public struct CourseSource: Identifiable, Codable, Hashable, Sendable {
    public var id: String { url }
    public let title: String
    public let url: String
    public let usedFor: String
}

public struct GuitarCourse: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let instrument: String
    public let level: String
    public let dailyMinutes: StringOrInt
    public let monthGoal: String
    public let prerequisites: StringOrArray
    public let materials: [String]
    public var weeks: [CourseWeek]
    public var days: [CourseDay]
    public let glossary: [GlossaryItem]
    public let nextMonth: [String]
    public let sources: [CourseSource]
    public let practiceExample: PracticeExample?

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, instrument, level, dailyMinutes, monthGoal
        case prerequisites, materials, weeks, days, glossary, nextMonth, sources, practiceExample
    }

    public init(
        id: String,
        title: String,
        subtitle: String,
        instrument: String,
        level: String,
        dailyMinutes: StringOrInt,
        monthGoal: String,
        prerequisites: StringOrArray,
        materials: [String],
        weeks: [CourseWeek],
        days: [CourseDay],
        glossary: [GlossaryItem],
        nextMonth: [String],
        sources: [CourseSource],
        practiceExample: PracticeExample? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.instrument = instrument
        self.level = level
        self.dailyMinutes = dailyMinutes
        self.monthGoal = monthGoal
        self.prerequisites = prerequisites
        self.materials = materials
        self.weeks = weeks
        var indexedDays = days
        for i in 0..<indexedDays.count {
            if indexedDays[i].dayNumber == 0 {
                indexedDays[i].dayNumber = i + 1
            }
        }
        self.days = indexedDays
        self.glossary = glossary
        self.nextMonth = nextMonth
        self.sources = sources
        self.practiceExample = practiceExample
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.subtitle = try container.decode(String.self, forKey: .subtitle)
        self.instrument = try container.decode(String.self, forKey: .instrument)
        self.level = try container.decode(String.self, forKey: .level)
        self.dailyMinutes = try container.decode(StringOrInt.self, forKey: .dailyMinutes)
        self.monthGoal = try container.decode(String.self, forKey: .monthGoal)
        self.prerequisites = try container.decode(StringOrArray.self, forKey: .prerequisites)
        self.materials = try container.decode([String].self, forKey: .materials)
        self.weeks = try container.decode([CourseWeek].self, forKey: .weeks)
        var decodedDays = try container.decode([CourseDay].self, forKey: .days)
        for i in 0..<decodedDays.count {
            if decodedDays[i].dayNumber == 0 {
                decodedDays[i].dayNumber = i + 1
            }
        }
        self.days = decodedDays
        self.glossary = try container.decode([GlossaryItem].self, forKey: .glossary)
        self.nextMonth = try container.decode([String].self, forKey: .nextMonth)
        self.sources = try container.decode([CourseSource].self, forKey: .sources)
        self.practiceExample = try container.decodeIfPresent(PracticeExample.self, forKey: .practiceExample)
    }

    public var iconName: String {
        switch id {
        case "turku": return "music.note"
        case "fingerstyle": return "hand.point.up.left.fill"
        case "blues": return "guitars.fill"
        case "rock": return "bolt.fill"
        case "klasik": return "tuningfork"
        case "flamenko": return "flame.fill"
        case "funk": return "waveform.path"
        case "caz": return "music.quarternote.3"
        case "country": return "star.fill"
        case "bossa": return "sun.max.fill"
        default: return "music.note"
        }
    }

    public var categoryColorHex: String {
        switch id {
        case "turku": return "#2E7D32"     // Deep Folk Green
        case "fingerstyle": return "#1565C0" // Acoustic Blue
        case "blues": return "#4527A0"       // Midnight Indigo
        case "rock": return "#C62828"        // Crimson Red
        case "klasik": return "#8D6E63"      // Warm Rosewood
        case "flamenko": return "#E65100"    // Andalusian Amber
        case "funk": return "#F9A825"        // Groove Gold
        case "caz": return "#00838F"         // Cool Teal
        case "country": return "#D84315"     // Rust Orange
        case "bossa": return "#00897B"       // Ipanema Turquoise
        default: return "#1E6B60"
        }
    }
}

// MARK: - Course Repository (Singleton Loader)

public final class CourseRepository: Sendable {
    public static let shared = CourseRepository()

    public static let courseIDs = [
        "turku", "fingerstyle", "blues", "rock", "klasik",
        "flamenko", "funk", "caz", "country", "bossa"
    ]

    private init() {}

    public func loadAllCourses() -> [GuitarCourse] {
        var results: [GuitarCourse] = []
        for id in Self.courseIDs {
            if let course = loadCourse(id: id) {
                results.append(course)
            }
        }
        return results
    }

    public func loadCourse(id: String) -> GuitarCourse? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json", subdirectory: "Resources") ??
                        Bundle.main.url(forResource: id, withExtension: "json") else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            var course = try JSONDecoder().decode(GuitarCourse.self, from: data)
            // Ensure day numbers 1 to 30 are indexed
            for i in 0..<course.days.count {
                course.days[i].dayNumber = i + 1
            }
            return course
        } catch {
            print("Error loading course \(id): \(error)")
            return nil
        }
    }
}
