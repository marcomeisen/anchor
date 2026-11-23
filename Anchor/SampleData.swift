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

extension SampleData {
    /// Eine Woche „Blatt" um heute herum: vier Anker mit Warum-Satz, Aufgaben über die Woche
    /// verteilt, einige ohne Tag, eine im Eingang. Nur für den UI-Testmodus und Vorschauen.
    @MainActor
    static func insertDemoWeek(in context: ModelContext, now: Date = Date()) {
        let week = TaskActions.ensureWeek(containing: now, weeks: [], modelContext: context)
        let anchors: [(String, String)] = [
            ("Launch vorbereiten", "Beta geht Freitag raus."),
            ("Dreimal laufen", "Für den Kopf, nicht für die Zeit."),
            ("Zeit für Familie", "Ein Abend ohne Laptop."),
            ("Spanisch lernen", "Zweiter Versuch nach letzter Woche."),
        ]
        let goals = anchors.enumerated().map { index, entry in
            let goal = Goal(title: entry.0, colorHex: AnkerColor.goalTintOptions[0], order: index, week: week)
            goal.why = entry.1
            context.insert(goal)
            week.appendGoal(goal)
            return goal
        }
        let plan: [(String, Int?, Int?, Bool)] = [
            ("Angebot an Kunde senden", 0, 0, true), ("Launch-Deck gliedern", 0, 0, false),
            ("Rückmeldung an Design", 0, 0, false), ("Probelauf mit dem Team", 0, 1, false),
            ("Beta veröffentlichen", 0, 4, false), ("Release Notes schreiben", 0, nil, true),
            ("30 Minuten laufen", 1, 0, false), ("Intervalle", 1, 2, false), ("Langer Lauf", 1, 5, false),
            ("Laufschuhe kaufen", 1, nil, false), ("Geschenk für Lea bestellen", 2, 0, false),
            ("Elternabend", 2, 3, false), ("Oma anrufen", 2, nil, false),
            ("Vokabeln Lektion 4", 3, 0, false), ("Tandem-Gespräch", 3, 2, false),
            ("Steuerunterlagen sortieren", nil, 1, false),
        ]
        let dates = AnkerCalendar.daysInWeek(starting: week.monday)
        for (title, goalIndex, dayIndex, done) in plan {
            let goal = goalIndex.map { goals[$0] }
            let task: AnkerTask?
            if let dayIndex {
                let day = TaskActions.ensureDay(containing: dates[dayIndex], in: week)
                task = TaskActions.create(title: title, priority: .b, on: day, linkedGoal: goal, modelContext: context)
            } else {
                task = TaskActions.createUnscheduled(title: title, goal: goal, modelContext: context)
            }
            if done, let task { TaskActions.setDone(task, true, modelContext: context) }
        }
        _ = TaskActions.createUnscheduled(title: "Arzttermin vereinbaren", goal: nil, modelContext: context)
        insertDemoHistory(in: context, before: week.monday)
        context.saveChanges()
    }

    /// Abgeschlossene Wochen vor der Demowoche — damit Archiv, Jahresraster und Serie etwas
    /// zeigen. Deterministisch, damit Bildschirmfotos reproduzierbar sind.
    private static func insertDemoHistory(in context: ModelContext, before monday: Date, weeks count: Int = 30) {
        let titles = ["Launch vorbereiten", "Dreimal laufen", "Zeit für Familie", "Spanisch lernen",
                      "Steuer erledigen", "Wohnung streichen", "Vortrag üben", "Früher schlafen"]
        // Ein Muster aus gehalten (h), teilweise (p) und nicht (m), je Woche bis zu vier Anker.
        let pattern = ["hhhp", "hhph", "hhhh", "hphm", "hhhh", "hhhh", "phhm", "hhhh", "hmhp", "hhhh",
                       "hhp", "hhhh", "hhhh", "hhhh", "phhh", "hmph", "hhhh", "hhh", "hphm", "hhhh",
                       "hhhh", "hhhh", "phmh", "hhhh", "hhph", "hhhh", "hhhh", "hhhh", "hhhh", "hhhp"]
        for offset in 1...count {
            guard let date = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: -offset, to: monday) else { continue }
            let week = TaskActions.ensureWeek(containing: date, weeks: [], modelContext: context)
            let marks = Array(pattern[(offset - 1) % pattern.count])
            for (index, mark) in marks.enumerated() {
                let title = titles[(offset + index * 3) % titles.count]
                let goal = Goal(title: title, colorHex: AnkerColor.goalTintOptions[0], order: index, week: week)
                goal.verdict = mark == "h" ? .held : (mark == "p" ? .partial : .missed)
                context.insert(goal)
                week.appendGoal(goal)
            }
            week.reviewedAt = AnkerCalendar.iso.date(byAdding: .day, value: 6, to: week.monday)
        }
    }
}
