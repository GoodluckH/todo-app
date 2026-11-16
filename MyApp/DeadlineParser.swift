import Foundation

/// A deadline found inside a task's text, e.g. "Call mom tomorrow at 5pm".
struct Deadline: Equatable {
    var date: Date
    var isAllDay: Bool
    /// The exact substring that was recognized as a date ("tomorrow at 5pm").
    var phrase: String
    /// The task text with the date phrase (and a dangling "by"/"on"/"at") removed.
    var title: String
}

/// Extracts deadlines from natural language using Foundation's on-device date detector.
enum DeadlineParser {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    /// Words that hint the phrase includes a specific time rather than just a day.
    private static let timeCuePattern = #"(?i)(\d\s*(am|pm|a\.m|p\.m)|\d:\d\d|\bnoon\b|\bmidnight\b|\bmorning\b|\bafternoon\b|\bevening\b|\btonight\b|\bat\s+\d)"#

    /// Connector words left dangling once the date phrase is removed ("Submit report by").
    private static let trailingConnectorPattern = #"(?i)\s*\b(by|on|at|due|before|until|for)\s*$"#

    static func parse(_ text: String) -> Deadline? {
        guard let detector,
              let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let date = match.date,
              let range = Range(match.range, in: text)
        else { return nil }

        let phrase = String(text[range])
        let isAllDay = phrase.range(of: timeCuePattern, options: .regularExpression) == nil

        let prefix = String(text[..<range.lowerBound])
            .replacingOccurrences(of: trailingConnectorPattern, with: "", options: .regularExpression)
        let suffix = String(text[range.upperBound...])
        let title = "\(prefix) \(suffix)"
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;-–")))

        // A bare date with nothing else ("tomorrow") is more likely the task itself.
        guard !title.isEmpty else { return nil }

        return Deadline(
            date: isAllDay ? Calendar.current.startOfDay(for: date) : date,
            isAllDay: isAllDay,
            phrase: phrase,
            title: title
        )
    }
}

/// Human-friendly due date labels: "Today", "Tomorrow, 5:00 PM", "Friday", "Dec 3".
enum DueFormat {
    static func label(for date: Date, isAllDay: Bool, now: Date = .now) -> String {
        let calendar = Calendar.current
        let day: String

        if calendar.isDateInToday(date) {
            day = String(localized: "Today")
        } else if calendar.isDateInTomorrow(date) {
            day = String(localized: "Tomorrow")
        } else if calendar.isDateInYesterday(date) {
            day = String(localized: "Yesterday")
        } else if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day, (2..<7).contains(days) {
            day = date.formatted(.dateTime.weekday(.wide))
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            day = date.formatted(.dateTime.month(.abbreviated).day())
        } else {
            day = date.formatted(.dateTime.month(.abbreviated).day().year())
        }

        guard !isAllDay else { return day }
        return "\(day), \(date.formatted(date: .omitted, time: .shortened))"
    }

    static func isPast(_ date: Date, isAllDay: Bool, now: Date = .now) -> Bool {
        isAllDay ? date < Calendar.current.startOfDay(for: now) : date < now
    }
}

/// Buckets for grouping open tasks on the home screen.
enum DueGroup: Int, CaseIterable, Comparable {
    case overdue, today, tomorrow, upcoming, noDate

    var title: LocalizedStringResource {
        switch self {
        case .overdue: "Overdue"
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        case .upcoming: "Upcoming"
        case .noDate: "No Date"
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    static func of(_ todo: TodoItem, now: Date = .now) -> DueGroup {
        guard let due = todo.dueDate else { return .noDate }
        let calendar = Calendar.current
        if todo.isOverdue(now: now) { return .overdue }
        if calendar.isDateInToday(due) { return .today }
        if calendar.isDateInTomorrow(due) { return .tomorrow }
        return .upcoming
    }
}
