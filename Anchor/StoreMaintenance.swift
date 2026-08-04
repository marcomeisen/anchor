import Foundation
import OSLog
import SwiftData

/// Fuehrt Datensaetze zusammen, die durch den iCloud-Sync doppelt entstehen.
///
/// CloudKit unterstuetzt keine Unique-Constraints. `AnkerRootView` legt beim Start ueber
/// `ensureCurrentWeek()` die laufende Woche an — machen das zwei Geraete unabhaengig
/// voneinander, existiert dieselbe Kalenderwoche nach dem Sync zweimal, mit je sieben
/// Tagen und auf beide Kopien verteilten Aufgaben. Sichtbar wird das als doppelte
/// Tagesliste in der Sidebar und als scheinbar verschwundene Aufgaben.
/// Empfaenger fuer das Protokoll einer Zusammenfuehrung.
///
/// `StoreMaintenance` rief vorher `CloudSyncStatusCenter.shared` direkt an. Ueber das
/// Protokoll laesst sich in Tests ein stiller Empfaenger einsetzen, statt den globalen
/// Zustand des Singletons zu veraendern.
@MainActor
protocol StoreMaintenanceReporting: AnyObject {
    func noteMaintenance(_ report: StoreMaintenance.MergeReport)
}

extension CloudSyncStatusCenter: StoreMaintenanceReporting {}

@MainActor
enum StoreMaintenance {
    /// Stabiler Schluessel pro Kalenderwoche.
    ///
    /// Bewusst ueber die ISO-Felder statt ueber `monday`: `AnkerCalendar` rechnet mit
    /// `TimeZone.current`, dieselbe Woche bekommt auf Geraeten in verschiedenen Zeitzonen
    /// also unterschiedliche `Date`-Werte und ein Vergleich darauf wuerde Duplikate uebersehen.
    /// Liegt jetzt bei `AnkerCalendar`, weil die Statistik denselben Schluessel braucht.
    typealias WeekKey = AnkerCalendar.WeekKey

    static func weekKey(_ week: Week) -> WeekKey {
        WeekKey(isoYear: week.isoYear, isoWeek: week.isoWeek)
    }

    static func dayKey(_ day: Day) -> String {
        let components = AnkerCalendar.iso.dateComponents([.year, .month, .day], from: day.date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    static func duplicateWeekKeys(in weeks: [Week]) -> [WeekKey] {
        Dictionary(grouping: weeks, by: weekKey)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
    }

    static func duplicateDayKeys(in week: Week) -> [String] {
        Dictionary(grouping: week.dayList, by: dayKey)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
    }

    /// Was eine Zusammenfuehrung entfernt hat.
    ///
    /// Das Zusammenfuehren loescht Datensaetze vollautomatisch und ohne Rueckholmoeglichkeit.
    /// Ein Fehler in der Logik waere sonst stiller Datenverlust — deshalb wird jeder Durchlauf
    /// protokolliert und im Sync-Status ausgewiesen, statt nur eine Zahl zurueckzugeben.
    struct MergeReport: Sendable, Equatable {
        var removedWeeks = 0
        var removedDays = 0
        /// Wochen, deren Ankerreihenfolge korrigiert wurde. Altbestand hat durchweg `order == 0`.
        var reorderedGoalWeeks: [String] = []
        /// Betroffene Kalenderwochen als `2026-KW31`, damit im Log nachvollziehbar ist,
        /// wo eingegriffen wurde.
        var affectedWeeks: [String] = []

        var removedTotal: Int { removedWeeks + removedDays }
        var isEmpty: Bool { removedTotal == 0 && reorderedGoalWeeks.isEmpty }

        var summary: String {
            guard !isEmpty else { return "Keine Duplikate" }

            var parts: [String] = []
            if removedWeeks > 0 { parts.append("\(removedWeeks) doppelte Wochen") }
            if removedDays > 0 { parts.append("\(removedDays) doppelte Tage") }
            if !parts.isEmpty {
                var text = "\(parts.joined(separator: ", ")) zusammengeführt"
                if !reorderedGoalWeeks.isEmpty {
                    text += ", Ankerreihenfolge in \(reorderedGoalWeeks.count) Wochen korrigiert"
                }
                return text
            }
            return "Ankerreihenfolge in \(reorderedGoalWeeks.count) Wochen korrigiert"
        }
    }

    /// Fuehrt doppelte Wochen und doppelte Tage zusammen. Gibt die Anzahl entfernter
    /// Datensaetze zurueck.
    @discardableResult
    static func normalize(
        weeks: [Week],
        modelContext: ModelContext,
        reporter: StoreMaintenanceReporting? = CloudSyncStatusCenter.shared
    ) -> Int {
        merge(weeks: weeks, modelContext: modelContext, reporter: reporter).removedTotal
    }

    /// Wie `normalize`, aber mit vollem Protokoll.
    @discardableResult
    static func merge(
        weeks: [Week],
        modelContext: ModelContext,
        reporter: StoreMaintenanceReporting? = CloudSyncStatusCenter.shared
    ) -> MergeReport {
        var report = MergeReport()

        let weekGroups = Dictionary(grouping: weeks, by: weekKey).filter { $0.value.count > 1 }
        for (key, group) in weekGroups {
            guard let survivor = electSurvivor(group) else { continue }

            let label = "\(key.isoYear)-KW\(String(format: "%02d", key.isoWeek))"
            report.affectedWeeks.append(label)

            for duplicate in group where duplicate !== survivor {
                cloudSyncLog.notice(
                    "Zusammenfuehrung \(label, privacy: .public): Woche \(duplicate.id.uuidString, privacy: .public) mit \(duplicate.dayList.count, privacy: .public) Tagen und \(duplicate.goalList.count, privacy: .public) Zielen geht in \(survivor.id.uuidString, privacy: .public) auf"
                )
                merge(duplicate, into: survivor, modelContext: modelContext)
                report.removedWeeks += 1
            }
        }

        let survivingWeeks = weeks.filter { !$0.isDeleted }
        for week in survivingWeeks where GoalOrdering.normalize(week) {
            let label = "\(week.isoYear)-KW\(String(format: "%02d", week.isoWeek))"
            report.reorderedGoalWeeks.append(label)
        }

        for week in survivingWeeks {
            let removedDays = mergeDuplicateDays(in: week, modelContext: modelContext)
            guard removedDays > 0 else { continue }

            report.removedDays += removedDays
            let label = "\(week.isoYear)-KW\(String(format: "%02d", week.isoWeek))"
            if !report.affectedWeeks.contains(label) {
                report.affectedWeeks.append(label)
            }
        }

        report.affectedWeeks.sort()

        if !report.isEmpty {
            let saved = modelContext.saveChanges()
            cloudSyncLog.notice(
                "Zusammenfuehrung abgeschlossen: \(report.removedWeeks, privacy: .public) Wochen und \(report.removedDays, privacy: .public) Tage entfernt in \(report.affectedWeeks.joined(separator: ", "), privacy: .public), gespeichert=\(saved, privacy: .public)"
            )
            reporter?.noteMaintenance(report)
        }

        return report
    }

    /// Deterministische Auswahl, damit beide Geraete unabhaengig voneinander denselben
    /// Datensatz behalten und das Ergebnis konvergiert statt hin und her zu schwingen.
    /// Absichtlich nicht generisch: `@Model`-Typen erben aus `PersistentModel` ein
    /// `id: PersistentIdentifier`, das hier von der eigenen `id: UUID` verdeckt wird —
    /// in generischem Code ist dann nicht mehr eindeutig, welches `id` gemeint ist.
    /// Wer bei doppelten Wochen überlebt: **die inhaltsreichere**, bei Gleichstand die kleinere
    /// UUID.
    ///
    /// Vorher entschied allein die UUID, also der Zufall. Das war der Kern eines gemeldeten
    /// Datenfehlers: installiert man die App neu, legt das Onboarding eine eigene Woche für
    /// denselben Montag an, während der iCloud-Erstimport dieselbe Woche noch bringt. Gewann die
    /// Onboarding-Woche, belegten ihre vier frischen Anker die sichtbaren Plätze und die echten
    /// rutschten in den Überschuss — von außen nicht von „überschrieben" zu unterscheiden.
    ///
    /// Der Gleichstandsentscheid muss geräteunabhängig sein: sonst führen zwei Geräte dieselben
    /// Duplikate verschieden zusammen und laufen auseinander.
    private static func electSurvivor(_ candidates: [Week]) -> Week? {
        candidates.min { left, right in
            let leftWeight = contentWeight(left), rightWeight = contentWeight(right)
            if leftWeight != rightWeight { return leftWeight > rightWeight }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func contentWeight(_ week: Week) -> Int {
        week.goalList.filter(WeekPlanning.isUserCreated).count
            + week.dayList.reduce(0) { $0 + $1.taskList.count }
            + (week.reflection?.isEmpty == false ? 1 : 0)
    }

    /// Dieselbe Regel für doppelte Tage: der mit mehr Aufgaben führt, damit Notizen und Fokus
    /// des benutzten Tages die Grundlage bleiben.
    private static func electSurvivor(_ candidates: [Day]) -> Day? {
        candidates.min { left, right in
            if left.taskList.count != right.taskList.count {
                return left.taskList.count > right.taskList.count
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    private static func merge(_ duplicate: Week, into survivor: Week, modelContext: ModelContext) {
        // Beide Wochen numerieren ihre Anker ab 0. Ohne Umnumerieren stehen nach dem
        // Zusammenführen zwei Ziele auf Platz 0, und beim Gleichstand entscheidet die UUID,
        // welche vier sichtbar bleiben — der Nutzer sähe seine echten Anker verschwinden und
        // fremde an ihrer Stelle. Die Ziele der überlebenden Woche behalten deshalb ihre
        // Plätze, die der doppelten kommen dahinter.
        let offset = (survivor.goalList.map(\.order).max() ?? -1) + 1
        for (index, goal) in GoalOrdering.sorted(duplicate.goalList).enumerated() {
            goal.order = offset + index
            goal.week = survivor
            if !survivor.goalList.contains(where: { $0.id == goal.id }) {
                survivor.appendGoal(goal)
            }
        }
        duplicate.goals = []
        // Anders als Tage wurden Ziele bisher nur angehaengt und nie nachsortiert — damit war
        // die Ankernummer nach jedem Zusammenfuehren eine andere.
        survivor.goals = GoalOrdering.sorted(survivor.goalList.filter { !$0.isDeleted })
        GoalOrdering.normalize(survivor)

        // Beide Rueckblicke behalten, wie bei den Tagesnotizen: Datenverlust beim Aufraeumen
        // waere schlimmer als eine doppelte Zeile.
        survivor.reflection = mergedNotes(survivor.reflection, duplicate.reflection)
        // Der fruehere Abschluss gilt — die Woche *wurde* an dem Tag geschlossen.
        survivor.reviewedAt = [survivor.reviewedAt, duplicate.reviewedAt].compactMap { $0 }.min()

        for day in duplicate.dayList {
            day.week = survivor
            if !survivor.dayList.contains(where: { $0.id == day.id }) {
                survivor.days = survivor.dayList + [day]
            }
        }
        duplicate.days = []

        // Erst nach dem Umhaengen loeschen: die Cascade-Regel wuerde Tage und Ziele
        // der doppelten Woche sonst mitnehmen.
        modelContext.delete(duplicate)
    }

    @discardableResult
    private static func mergeDuplicateDays(in week: Week, modelContext: ModelContext) -> Int {
        let groups = Dictionary(grouping: week.dayList, by: dayKey).filter { $0.value.count > 1 }
        guard !groups.isEmpty else { return 0 }

        var removed = 0

        for group in groups.values {
            guard let survivor = electSurvivor(group) else { continue }

            for duplicate in group where duplicate !== survivor {
                cloudSyncLog.notice(
                    "Zusammenfuehrung Tag \(dayKey(duplicate), privacy: .public): \(duplicate.id.uuidString, privacy: .public) mit \(duplicate.taskList.count, privacy: .public) Aufgaben und \(duplicate.timeBlockList.count, privacy: .public) Zeitbloecken geht in \(survivor.id.uuidString, privacy: .public) auf"
                )
                merge(duplicate, into: survivor, modelContext: modelContext)
                removed += 1
            }

            TaskActions.normalizeOrders(in: survivor)
        }

        week.days = week.dayList
            .filter { !$0.isDeleted }
            .sorted { $0.date < $1.date }

        return removed
    }

    private static func merge(_ duplicate: Day, into survivor: Day, modelContext: ModelContext) {
        for task in duplicate.taskList {
            task.day = survivor
            if !survivor.taskList.contains(where: { $0.id == task.id }) {
                survivor.appendTask(task)
            }
        }
        duplicate.tasks = []

        for block in duplicate.timeBlockList {
            block.day = survivor
            if !survivor.timeBlockList.contains(where: { $0.id == block.id }) {
                survivor.timeBlocks = survivor.timeBlockList + [block]
            }
        }
        duplicate.timeBlocks = []

        survivor.focusNote = firstFilled(survivor.focusNote, duplicate.focusNote)
        survivor.notes = mergedNotes(survivor.notes, duplicate.notes)

        modelContext.delete(duplicate)
    }

    private static func firstFilled(_ lhs: String?, _ rhs: String?) -> String? {
        let left = lhs?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let left, !left.isEmpty { return lhs }
        return rhs
    }

    /// Notizen beider Kopien behalten. Ein Datenverlust beim Aufraeumen waere deutlich
    /// schlimmer als eine doppelte Zeile, die der Nutzer selbst kuerzen kann.
    private static func mergedNotes(_ lhs: String?, _ rhs: String?) -> String? {
        let left = lhs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let right = rhs?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if left.isEmpty { return right.isEmpty ? lhs : rhs }
        if right.isEmpty || left == right { return lhs }
        return "\(left)\n\n\(right)"
    }
}
