import Foundation
import SwiftData

/// Alle Kennzahlen des Entwurfs als reine Funktionen über `[Week]`.
///
/// Kein View-Bezug, `now` immer injizierbar — dasselbe Muster wie `WeekPlanning`. Der Entwurf
/// verlangt Aussagen („5 Wochen Serie", „Bei diesem Tempo schaffst du 6 von 7"), und eine
/// Aussage muss prüfbar sein, sonst behauptet die App etwas, das niemand nachgerechnet hat.
@MainActor
enum AnkerStatistics {

    /// Wie eine Woche dasteht.
    enum WeekStanding: Equatable {
        /// Jeder zählbare Anker hat mindestens eine erledigte Aufgabe.
        case held
        /// Mindestens einer ist liegen geblieben.
        case missed
        /// Kein Datensatz oder kein Anker — zählt nicht als gehalten und **unterbricht** die Serie.
        case unplanned
        /// Die laufende Woche. Nie ein Bruch.
        case running
        case upcoming
    }

    struct AnchorReport: Identifiable, Equatable {
        let id: UUID
        let number: Int
        let title: String
        let colorHex: String
        let doneCount: Int
        let totalCount: Int
        /// Verschiedene Kalendertage mit mindestens einer Erledigung.
        let activeDays: Int
        /// Von heute bis Sonntag, einschließlich. 0, wenn die Woche vorbei ist.
        let remainingDays: Int

        var openCount: Int { totalCount - doneCount }
        var isInMotion: Bool { doneCount > 0 }
        var progress: Double { totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount) }

        /// Vergangene Tage der Woche, den heutigen eingeschlossen.
        var elapsedDays: Int { max(0, 7 - remainingDays) }

        /// „Steht seit Montag still": geplant, aber nach mindestens zwei Tagen nichts erledigt.
        ///
        /// Die Zweitagesschwelle ist nötig, weil am Montag jeder Anker stillsteht — die Aussage
        /// wäre dann keine, nur eine Beobachtung über den Wochentag.
        var isStalled: Bool { totalCount > 0 && doneCount == 0 && elapsedDays >= 2 }

        /// Jenseits der Empfehlung von vier. Erlaubt, aber nie versteckt.
        var isOverRecommendation: Bool { number > GoalOrdering.maxAnchors }

        /// Der kurze Stand unter dem Balken — im Streifen und in der Sidebar dieselbe Aussage.
        var statusLine: String {
            if isOverRecommendation { return "über Empfehlung" }
            if isStalled { return "steht still" }
            if totalCount == 0 { return "noch keine Aufgabe" }
            if doneCount == 0 { return "noch nicht begonnen" }
            return activeDays == 1 ? "1 Tag aktiv" : "\(activeDays) Tage aktiv"
        }
    }

    struct WeekdayReport: Equatable {
        /// 1 = Montag.
        let index: Int
        let name: String
        let doneCount: Int
    }

    /// Die Prognose des Entwurfs: ein Satz, der eine Entscheidung verlangt, statt einer Prozentzahl.
    struct Forecast: Equatable {
        enum Kind: Equatable { case running, finished, empty }

        let kind: Kind
        let doneCount: Int
        let totalCount: Int
        let projectedDone: Int
        let nextISOWeek: Int

        var deficit: Int { max(0, totalCount - projectedDone) }

        var sentence: String {
            switch kind {
            case .empty:
                return "Noch keine Aufgabe in dieser Woche."
            case .finished:
                return "Du hast \(doneCount) von \(totalCount) geschafft."
            case .running:
                var text = "Bei diesem Tempo schaffst du \(projectedDone) von \(totalCount)."
                if deficit == 1 {
                    text += " Eine Aufgabe muss heute weg — oder nach \(AnkerDateFormat.calendarWeek(nextISOWeek))."
                } else if deficit > 1 {
                    text += " \(deficit) Aufgaben müssen heute weg — oder nach \(AnkerDateFormat.calendarWeek(nextISOWeek))."
                }
                return text
            }
        }
    }

    struct Streak: Equatable {
        let weeks: Int
        /// Zählt die laufende Woche schon mit?
        let isRunning: Bool
    }

    struct YearBar: Identifiable, Equatable {
        let isoWeek: Int
        let inMotionCount: Int
        let anchorCount: Int
        let standing: WeekStanding

        var id: Int { isoWeek }
        /// 0 bis 1, für die Balkenhöhe.
        var fill: Double {
            anchorCount == 0 ? 0 : Double(inMotionCount) / Double(anchorCount)
        }
    }

    struct WeekReport: Equatable {
        let isoYear: Int
        let isoWeek: Int
        let anchors: [AnchorReport]
        let inMotionCount: Int
        let anchorCount: Int
        let standing: WeekStanding
        /// Aufgaben **in** dieser Woche, die aus einer früheren übernommen wurden.
        let carriedInTaskCount: Int
        let strongestWeekday: WeekdayReport?
        let forecast: Forecast
        let isClosed: Bool

        /// Der Anker, der nicht gehalten wurde — für das Plakat.
        var firstMissedAnchor: AnchorReport? {
            anchors.first { !$0.isInMotion }
        }
    }

    struct YearReport: Equatable {
        let isoYear: Int
        /// Immer ein Eintrag pro ISO-Woche, Lücken inklusive.
        let bars: [YearBar]
        let heldWeekCount: Int
        let plannedWeekCount: Int
        let anchorTotal: Int
        let anchorInMotionTotal: Int
        let streak: Streak
        let strongestWeekday: WeekdayReport?
        let carriedInTaskCount: Int

        var heldAnchorPercentage: Int {
            anchorTotal == 0 ? 0 : Int((Double(anchorInMotionTotal) / Double(anchorTotal) * 100).rounded())
        }
    }

    // MARK: - Woche

    static func week(_ week: Week, now: Date = Date()) -> WeekReport {
        let countable = GoalOrdering.countableAnchors(in: week)
        let allTasks = week.dayList.flatMap(\.taskList)

        let anchors = countable.enumerated().map { index, goal in
            anchorReport(goal, number: index + 1, in: week, now: now)
        }

        return WeekReport(
            isoYear: week.isoYear,
            isoWeek: week.isoWeek,
            anchors: anchors,
            inMotionCount: anchors.filter(\.isInMotion).count,
            anchorCount: anchors.count,
            standing: standing(of: week, now: now),
            carriedInTaskCount: allTasks.filter { $0.carryOverCount > 0 }.count,
            strongestWeekday: strongestWeekday(in: allTasks),
            forecast: forecast(for: week, now: now),
            isClosed: week.isReviewed
        )
    }

    /// Alle Ziele der Woche als Bericht — die vier Anker **und** einen etwaigen Überschuss.
    ///
    /// `week()` liefert absichtlich nur die vier: die Kennzahlen der Woche dürfen sich nicht
    /// verschieben, wenn zwei Geräte offline fünf Ziele erzeugt haben. Der Streifen dagegen muss
    /// den fünften **zeigen** — erlaubt, aber unter einer Linie und nie versteckt.
    static func allAnchors(in week: Week, now: Date = Date()) -> [AnchorReport] {
        GoalOrdering.sorted(week.goalList)
            .filter(WeekPlanning.isUserCreated)
            .enumerated()
            .map { index, goal in anchorReport(goal, number: index + 1, in: week, now: now) }
    }

    private static func anchorReport(_ goal: Goal, number: Int, in week: Week, now: Date) -> AnchorReport {
        // Ueber die Tage statt ueber `goal.taskList`: nach einem Sync kann eine Seite der
        // Beziehung noch nicht nachgezogen sein.
        let own = week.dayList.flatMap(\.taskList).filter { $0.linkedGoal?.id == goal.id }
        let done = own.filter(\.isDone)

        let activeDays = Set(
            done.compactMap(\.completionDate).map { AnkerCalendar.iso.startOfDay(for: $0) }
        ).count

        return AnchorReport(
            id: goal.id,
            number: number,
            title: goal.title,
            colorHex: goal.colorHex,
            doneCount: done.count,
            totalCount: own.count,
            activeDays: activeDays,
            remainingDays: remainingDays(in: week, now: now)
        )
    }

    /// Von heute bis Sonntag, einschließlich beider. Vor der Woche zählen alle sieben.
    static func remainingDays(in week: Week, now: Date = Date()) -> Int {
        let today = AnkerCalendar.iso.startOfDay(for: now)
        let start = max(today, AnkerCalendar.iso.startOfDay(for: week.monday))
        let end = AnkerCalendar.iso.startOfDay(for: week.sunday)
        guard start <= end else { return 0 }
        let days = AnkerCalendar.iso.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }

    static func forecast(for week: Week, now: Date = Date()) -> Forecast {
        let tasks = week.dayList.flatMap(\.taskList)
        let done = tasks.filter(\.isDone).count
        let nextISOWeek = AnkerCalendar.weekInterval(
            containing: AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday) ?? week.monday
        ).isoWeek

        guard !tasks.isEmpty else {
            return Forecast(kind: .empty, doneCount: 0, totalCount: 0, projectedDone: 0, nextISOWeek: nextISOWeek)
        }

        let remaining = remainingDays(in: week, now: now)
        guard remaining > 0 else {
            return Forecast(kind: .finished, doneCount: done, totalCount: tasks.count,
                            projectedDone: done, nextISOWeek: nextISOWeek)
        }

        // Verstrichene Tage einschliesslich heute. Lineare Fortschreibung innerhalb der Woche —
        // eine echte Geschwindigkeit ueber mehrere Wochen waere ohne `completedAt`-Historie
        // geraten, und geraten ist schlechter als schlicht.
        let elapsed = max(1, 8 - remaining)
        let pace = Double(done) / Double(elapsed)
        let projected = min(tasks.count, done + Int((pace * Double(remaining - 1)).rounded()))

        return Forecast(kind: .running, doneCount: done, totalCount: tasks.count,
                        projectedDone: projected, nextISOWeek: nextISOWeek)
    }

    static func standing(of week: Week?, now: Date = Date()) -> WeekStanding {
        guard let week else { return .unplanned }

        let anchors = GoalOrdering.countableAnchors(in: week)
        let today = AnkerCalendar.weekInterval(containing: now)

        if (week.isoYear, week.isoWeek) == (today.isoYear, today.isoWeek) {
            return .running
        }
        if (week.isoYear, week.isoWeek) > (today.isoYear, today.isoWeek) {
            return .upcoming
        }

        guard !anchors.isEmpty else { return .unplanned }

        let tasks = week.dayList.flatMap(\.taskList)
        let inMotion = anchors.filter { goal in
            tasks.contains { $0.linkedGoal?.id == goal.id && $0.isDone }
        }.count

        return inMotion == anchors.count ? .held : .missed
    }

    /// Der Wochentag mit den meisten Erledigungen.
    ///
    /// Über `completionDate` — also `completedAt` mit Rückfall auf den geplanten Tag. Ohne das
    /// wäre es eine Aussage über die Planung, nicht über das Verhalten. Gleichstand entscheidet
    /// der frühere Wochentag, damit das Ergebnis nicht zufällig schwankt.
    static func strongestWeekday(in tasks: [AnkerTask]) -> WeekdayReport? {
        var counts: [Int: Int] = [:]
        for task in tasks {
            guard let date = task.completionDate else { continue }
            counts[isoWeekdayIndex(of: date), default: 0] += 1
        }

        guard let best = counts.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) }), best.value > 0 else {
            return nil
        }

        return WeekdayReport(index: best.key, name: weekdayName(best.key), doneCount: best.value)
    }

    // MARK: - Jahr

    static func year(isoYear: Int, in weeks: [Week], now: Date = Date()) -> YearReport {
        let byWeek = Dictionary(
            weeks.filter { $0.isoYear == isoYear }.map { ($0.isoWeek, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Ueber alle ISO-Wochen des Jahres iterieren, nicht ueber die vorhandenen Datensaetze —
        // sonst fehlen die Luecken, und genau die sind die Aussage des Bands.
        let bars = (1...AnkerCalendar.weeksInISOYear(isoYear)).map { isoWeek -> YearBar in
            guard let week = byWeek[isoWeek] else {
                return YearBar(isoWeek: isoWeek, inMotionCount: 0, anchorCount: 0, standing: .unplanned)
            }
            let report = self.week(week, now: now)
            return YearBar(
                isoWeek: isoWeek,
                inMotionCount: report.inMotionCount,
                anchorCount: report.anchorCount,
                standing: report.standing
            )
        }

        // Quote ueber *erklaerte* Anker: Wochen ohne Anker fallen aus dem Nenner, sonst
        // verduennt eine ungeplante Woche das Ergebnis.
        let counted = bars.filter { $0.anchorCount > 0 }

        return YearReport(
            isoYear: isoYear,
            bars: bars,
            heldWeekCount: bars.filter { $0.standing == .held }.count,
            plannedWeekCount: counted.count,
            anchorTotal: counted.reduce(0) { $0 + $1.anchorCount },
            anchorInMotionTotal: counted.reduce(0) { $0 + $1.inMotionCount },
            streak: streak(in: weeks, now: now),
            strongestWeekday: strongestWeekday(
                in: weeks.filter { $0.isoYear == isoYear }.flatMap(\.dayList).flatMap(\.taskList)
            ),
            carriedInTaskCount: weeks
                .filter { $0.isoYear == isoYear }
                .flatMap(\.dayList).flatMap(\.taskList)
                .filter { $0.carryOverCount > 0 }.count
        )
    }

    /// Die Serie gehaltener Wochen, von der laufenden rückwärts.
    ///
    /// Über Datumsarithmetik statt über `isoWeek`, damit sie Jahresgrenzen überlebt. Die
    /// laufende Woche zählt nur mit, wenn sie **schon** gehalten ist — sonst fiele die Zahl
    /// mittwochs auf null.
    static func streak(in weeks: [Week], now: Date = Date()) -> Streak {
        let byKey = Dictionary(
            weeks.map { (AnkerCalendar.WeekKey(isoYear: $0.isoYear, isoWeek: $0.isoWeek), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        func isHeld(_ date: Date) -> Bool {
            let interval = AnkerCalendar.weekInterval(containing: date)
            let key = AnkerCalendar.WeekKey(isoYear: interval.isoYear, isoWeek: interval.isoWeek)
            guard let week = byKey[key] else { return false }
            let anchors = GoalOrdering.countableAnchors(in: week)
            guard !anchors.isEmpty else { return false }
            let tasks = week.dayList.flatMap(\.taskList)
            return anchors.allSatisfy { goal in
                tasks.contains { $0.linkedGoal?.id == goal.id && $0.isDone }
            }
        }

        var count = 0
        let currentHeld = isHeld(now)
        if currentHeld { count += 1 }

        var cursor = now
        while let previous = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: -1, to: cursor) {
            guard isHeld(previous) else { break }
            count += 1
            cursor = previous
            // Ohne Schranke laeuft die Schleife bei einem verrutschten Datum ins Leere.
            if count > 520 { break }
        }

        return Streak(weeks: count, isRunning: currentHeld)
    }

    // MARK: - Hilfen

    /// 1 = Montag. `Calendar.component(.weekday:)` zaehlt ab Sonntag = 1.
    nonisolated static func isoWeekdayIndex(of date: Date) -> Int {
        let weekday = AnkerCalendar.iso.component(.weekday, from: date)
        return weekday == 1 ? 7 : weekday - 1
    }

    nonisolated static func weekdayName(_ index: Int) -> String {
        let monday = AnkerCalendar.weekInterval(containing: Date()).monday
        let date = AnkerCalendar.iso.date(byAdding: .day, value: index - 1, to: monday) ?? monday
        return AnkerDateFormat.weekdayLong(date)
    }
}
