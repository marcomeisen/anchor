import Foundation
import SwiftData

@Model
final class Goal {
    var id: UUID
    var title: String
    var colorHex: String
    var week: Week?

    @Relationship(deleteRule: .nullify, inverse: \AnkerTask.linkedGoal)
    var tasks: [AnkerTask] = []

    var progress: Double {
        tasks.isEmpty ? 0 : Double(tasks.filter(\.isDone).count) / Double(tasks.count)
    }

    init(id: UUID = UUID(), title: String, colorHex: String, week: Week? = nil) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.week = week
    }
}

@Model
final class Week {
    var id: UUID
    var isoYear: Int
    var isoWeek: Int
    var monday: Date
    var sunday: Date

    @Relationship(deleteRule: .cascade, inverse: \Goal.week)
    var goals: [Goal] = []

    @Relationship(deleteRule: .cascade, inverse: \Day.week)
    var days: [Day] = []

    init(
        id: UUID = UUID(),
        isoYear: Int,
        isoWeek: Int,
        monday: Date,
        sunday: Date
    ) {
        self.id = id
        self.isoYear = isoYear
        self.isoWeek = isoWeek
        self.monday = monday
        self.sunday = sunday
    }
}

@Model
final class Day {
    var id: UUID
    var date: Date
    var focusNote: String?
    var week: Week?

    @Relationship(deleteRule: .cascade, inverse: \AnkerTask.day)
    var tasks: [AnkerTask] = []

    @Relationship(deleteRule: .cascade, inverse: \TimeBlock.day)
    var timeBlocks: [TimeBlock] = []

    var notes: String?

    init(
        id: UUID = UUID(),
        date: Date,
        focusNote: String? = nil,
        week: Week? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.date = date
        self.focusNote = focusNote
        self.week = week
        self.notes = notes
    }
}

enum Priority: String, Codable, CaseIterable, Identifiable {
    case a
    case b
    case c

    var id: String { rawValue }

    var label: String { rawValue.uppercased() }
}

@Model
final class AnkerTask {
    var id: UUID
    var title: String
    var priority: Priority
    var isDone: Bool
    var order: Int
    var day: Day?
    var linkedGoal: Goal?

    init(
        id: UUID = UUID(),
        title: String,
        priority: Priority,
        isDone: Bool = false,
        order: Int,
        day: Day? = nil,
        linkedGoal: Goal? = nil
    ) {
        self.id = id
        self.title = title
        self.priority = priority
        self.isDone = isDone
        self.order = order
        self.day = day
        self.linkedGoal = linkedGoal
    }
}

@Model
final class TimeBlock {
    var id: UUID
    var startTime: Date
    var endTime: Date
    var title: String
    var day: Day?
    var linkedEventIdentifier: String?

    init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date,
        title: String,
        day: Day? = nil,
        linkedEventIdentifier: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.title = title
        self.day = day
        self.linkedEventIdentifier = linkedEventIdentifier
    }
}
