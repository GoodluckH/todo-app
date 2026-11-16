import Foundation
import SwiftData

/// A single todo entry, persisted with SwiftData.
@Model
final class TodoItem {
    var title: String
    var isDone: Bool
    var createdAt: Date
    var completedAt: Date?
    var dueDate: Date?
    /// When true, `dueDate` is the start of a day and has no meaningful time.
    var isAllDay: Bool = true

    init(title: String, dueDate: Date? = nil, isAllDay: Bool = true, isDone: Bool = false, createdAt: Date = .now) {
        self.title = title
        self.dueDate = dueDate
        self.isAllDay = isAllDay
        self.isDone = isDone
        self.createdAt = createdAt
        self.completedAt = isDone ? .now : nil
    }

    func toggle() {
        isDone.toggle()
        completedAt = isDone ? .now : nil
    }

    func isOverdue(now: Date = .now) -> Bool {
        guard let dueDate, !isDone else { return false }
        return DueFormat.isPast(dueDate, isAllDay: isAllDay, now: now)
    }
}
