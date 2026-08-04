import Foundation

/// Das Archiv als **Ort**, nicht als Nebenwirkung des Scrollens.
///
/// Der Entwurf begründet das damit, dass vergangene Wochen dafür keinen permanenten Baum in der
/// Sidebar brauchen: „Abgeschlossene Anker und Aufgaben bleiben auffindbar — über die Suche und
/// über einen eigenen Eintrag." Die Zeitschiene zeigt deshalb nur ein Fenster um die laufende
/// Woche; alles Ältere lebt hier und im Jahresband.
///
/// Reiner Typ, keine View.
@MainActor
enum AnkerArchive {

    /// Eine abgeschlossene Woche in der Übersicht.
    struct Entry: Identifiable, Equatable {
        let id: UUID
        let monday: Date
        let isoWeek: Int
        let isoYear: Int
        let reviewedAt: Date?
        let anchorCount: Int
        let heldAnchorCount: Int
        let doneTaskCount: Int
        let taskCount: Int
        let hasReflection: Bool

        var isHeld: Bool { anchorCount > 0 && heldAnchorCount == anchorCount }

        var span: String {
            AnkerDateFormat.weekSpan(
                monday: monday,
                sunday: AnkerCalendar.iso.date(byAdding: .day, value: 6, to: monday) ?? monday
            )
        }

        var accessibilityLabel: String {
            "\(AnkerDateFormat.calendarWeek(isoWeek)), \(heldAnchorCount) von \(anchorCount) Ankern gehalten, \(doneTaskCount) von \(taskCount) Aufgaben erledigt"
        }
    }

    /// Was ins Archiv gehört: eine geschlossene Woche, oder eine, die ganz in der Vergangenheit
    /// liegt.
    ///
    /// Bewusst beides. „Geschlossen" allein wäre zu streng — wer den Rückblick überspringt,
    /// verliert sonst den Zugang zu seinen eigenen Daten. „Vergangen" allein wäre zu weit: eine
    /// bewusst früh geschlossene Woche gehört auch dann hierher, wenn sie noch läuft.
    static func isArchived(_ week: Week, now: Date = Date()) -> Bool {
        if week.reviewedAt != nil { return true }
        return week.monday < AnkerCalendar.weekInterval(containing: now).monday
    }

    /// Die archivierten Wochen, neueste zuerst.
    static func entries(in weeks: [Week], now: Date = Date()) -> [Entry] {
        weeks
            .filter { isArchived($0, now: now) }
            .sorted { $0.monday > $1.monday }
            .map { entry(for: $0) }
    }

    static func count(in weeks: [Week], now: Date = Date()) -> Int {
        weeks.filter { isArchived($0, now: now) }.count
    }

    private static func entry(for week: Week) -> Entry {
        let report = AnkerStatistics.week(week)
        let tasks = week.dayList.flatMap(\.taskList)

        return Entry(
            id: week.id,
            monday: week.monday,
            isoWeek: week.isoWeek,
            isoYear: week.isoYear,
            reviewedAt: week.reviewedAt,
            anchorCount: report.anchorCount,
            heldAnchorCount: report.inMotionCount,
            doneTaskCount: tasks.filter(\.isDone).count,
            taskCount: tasks.count,
            hasReflection: week.reflection?.isEmpty == false
        )
    }
}
