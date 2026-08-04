import Foundation
import SwiftData

/// Beispieldaten fuer Previews und Unit-Tests.
///
/// Frueher wurden diese Daten auch in Auslieferungsbuilds erkannt und beim Start geloescht
/// (`isReferenceWeek` / `removeReferenceDataIfNeeded`). Das war ein Migrationsbehelf aus der
/// Entwicklung, lief bei jedem Start und haette bei einer Fehlerkennung echte Nutzerdaten
/// getroffen — eine Woche mit vier gleichnamigen Zielen reicht dafuer. Die Erkennung ist
/// entfernt; angelegt werden die Daten nur noch aus `PreviewContainer` und den Tests.
enum SampleData {
    static let referenceToday = AnkerCalendar.date(year: 2026, month: 1, day: 1, hour: 9, minute: 41)
    @discardableResult
    static func insertReferenceWeek(in context: ModelContext) -> Week {
        let interval = AnkerCalendar.weekInterval(containing: referenceToday)
        let week = Week(
            isoYear: interval.isoYear,
            isoWeek: interval.isoWeek,
            monday: interval.monday,
            sunday: interval.sunday
        )

        // `order` ausdruecklich: ohne sie waeren die Ankernummern in Previews und Tests
        // von der Beziehungsreihenfolge abhaengig.
        let annual = Goal(title: "Jahresplanung 2026", colorHex: "#5B6EE8", order: 0, week: week)
        let security = Goal(title: "Security-Review AWS SES", colorHex: "#C9974B", order: 1, week: week)
        let workshop = Goal(title: "Workshop Product Owner Lead", colorHex: "#7FCDA8", order: 2, week: week)
        let tax = Goal(title: "FZulG-Bewertung abschließen", colorHex: "#8A8D98", order: 3, week: week)
        week.goals = [annual, security, workshop, tax]

        week.days = AnkerCalendar.daysInWeek(starting: interval.monday).enumerated().map { offset, date in
            let day = Day(date: date, week: week)
            switch offset {
            case 0:
                day.tasks = [
                    AnkerTask(title: "RACI-Matrix Review", priority: .b, isDone: true, order: 0,
                              completedAt: AnkerCalendar.date(year: 2026, month: 12, day: 29, hour: 11),
                              day: day, linkedGoal: annual)
                ]
            case 1:
                day.tasks = [
                    AnkerTask(title: "SOC-Meldung abschließen", priority: .a, isDone: true, order: 0,
                              completedAt: AnkerCalendar.date(year: 2026, month: 12, day: 30, hour: 16),
                              day: day, linkedGoal: security)
                ]
            case 3:
                day.focusNote = "Jahresplanung 2026 abschließen"
                day.timeBlocks = [
                    TimeBlock(
                        startTime: AnkerCalendar.date(year: 2026, month: 1, day: 1, hour: 9),
                        endTime: AnkerCalendar.date(year: 2026, month: 1, day: 1, hour: 10),
                        title: "Team-Sync Produkt",
                        day: day,
                        linkedEventIdentifier: "sample-team-sync"
                    ),
                    TimeBlock(
                        startTime: AnkerCalendar.date(year: 2026, month: 1, day: 1, hour: 11),
                        endTime: AnkerCalendar.date(year: 2026, month: 1, day: 1, hour: 12),
                        title: "Konzeptreview mit Team",
                        day: day
                    )
                ]
                day.tasks = [
                    AnkerTask(title: "Executive Summary finalisieren", priority: .a, order: 0, day: day, linkedGoal: annual),
                    AnkerTask(title: "Rückmeldung an R+V senden", priority: .b, order: 1,
                              carryOverCount: 1, day: day),
                    AnkerTask(title: "Feedback-Runde einplanen", priority: .c, isDone: true, order: 2,
                              completedAt: AnkerCalendar.date(year: 2026, month: 1, day: 1, hour: 9),
                              day: day, linkedGoal: annual)
                ]
            case 4:
                day.tasks = [
                    AnkerTask(title: "Workshop vorbereiten", priority: .b, order: 0, day: day, linkedGoal: annual),
                    AnkerTask(title: "Workshop-Agenda abstimmen", priority: .a, order: 1, day: day, linkedGoal: annual)
                ]
            default:
                break
            }
            return day
        }

        week.reflection = "Der Donnerstag war zu voll — Reviews früher legen."

        context.insert(week)
        return week
    }
}
