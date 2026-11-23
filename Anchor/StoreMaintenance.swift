import Foundation
import OSLog
import SwiftData

/// Fuehrt Datensaetze zusammen, die durch den iCloud-Sync doppelt entstehen.
///
/// CloudKit unterstuetzt keine Unique-Constraints. Schreiben zwei Geraete offline in dieselbe
/// neue Kalenderwoche, existiert sie nach dem Sync zweimal. Seit Wochen und Tage erst beim
/// Schreiben entstehen (nicht mehr beim Start und beim Blaettern), ist das selten — aber
/// moeglich, und dann muss das Aufraeumen auf allen Geraeten **dasselbe** Ergebnis haben.
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

    /// Ueber den gemeinten Kalendertag statt ueber das rohe Datum — siehe
    /// `AnkerCalendar.nominalDay(ofStored:)`.
    static func dayKey(_ day: Day) -> String {
        let components = AnkerCalendar.nominalDay(ofStored: day.date)
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
        /// Tage, Ziele und Zeitbloecke ohne Woche bzw. ohne Tag, die wieder eingehaengt wurden.
        var adoptedOrphans = 0
        /// Wochen, deren Ankerreihenfolge korrigiert wurde. Altbestand hat durchweg `order == 0`.
        var reorderedGoalWeeks: [String] = []
        /// Betroffene Kalenderwochen als `2026-KW31`, damit im Log nachvollziehbar ist,
        /// wo eingegriffen wurde.
        var affectedWeeks: [String] = []

        var removedTotal: Int { removedWeeks + removedDays }
        var isEmpty: Bool { removedTotal == 0 && reorderedGoalWeeks.isEmpty && adoptedOrphans == 0 }

        var summary: String {
            guard !isEmpty else { return String(localized: "Keine Duplikate") }

            var parts: [String] = []
            if removedWeeks > 0 { parts.append(String(localized: "\(removedWeeks) doppelte Wochen")) }
            if removedDays > 0 { parts.append(String(localized: "\(removedDays) doppelte Tage")) }
            if adoptedOrphans > 0 { parts.append(String(localized: "\(adoptedOrphans) verwaiste Einträge")) }
            if !parts.isEmpty {
                let merged = parts.joined(separator: ", ")
                if !reorderedGoalWeeks.isEmpty {
                    return String(localized: "\(merged) zusammengeführt, Ankerreihenfolge in \(reorderedGoalWeeks.count) Wochen korrigiert")
                }
                return String(localized: "\(merged) zusammengeführt")
            }
            return String(localized: "Ankerreihenfolge in \(reorderedGoalWeeks.count) Wochen korrigiert")
        }
    }

    /// Fuehrt doppelte Wochen und doppelte Tage zusammen. Gibt die Anzahl entfernter
    /// Datensaetze zurueck.
    @discardableResult
    static func normalize(
        weeks: [Week],
        modelContext: ModelContext,
        reporter: StoreMaintenanceReporting? = nil
    ) -> Int {
        merge(weeks: weeks, modelContext: modelContext, reporter: reporter).removedTotal
    }

    /// Aufraeumen auf dem **aktuellen** Bestand statt auf dem Schnappschuss einer View.
    ///
    /// `@Query` aktualisiert verzoegert; mit dem alten Array blieben frisch importierte
    /// Duplikate bis zum naechsten Durchlauf liegen.
    @discardableResult
    static func run(
        modelContext: ModelContext,
        reporter: StoreMaintenanceReporting? = nil
    ) -> MergeReport {
        let weeks = (try? modelContext.fetch(FetchDescriptor<Week>())) ?? []
        return merge(weeks: weeks.filter { !$0.isDeleted }, modelContext: modelContext, reporter: reporter)
    }

    /// Wie `normalize`, aber mit vollem Protokoll.
    @discardableResult
    static func merge(
        weeks: [Week],
        modelContext: ModelContext,
        reporter: StoreMaintenanceReporting? = nil
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

        report.adoptedOrphans = adoptOrphans(
            weeks: weeks.filter { !$0.isDeleted },
            modelContext: modelContext
        )

        report.affectedWeeks.sort()

        if !report.isEmpty {
            let saved = modelContext.saveChanges()
            cloudSyncLog.notice(
                "Zusammenfuehrung abgeschlossen: \(report.removedWeeks, privacy: .public) Wochen und \(report.removedDays, privacy: .public) Tage entfernt in \(report.affectedWeeks.joined(separator: ", "), privacy: .public), gespeichert=\(saved, privacy: .public)"
            )
            // `nil` heißt der Sync-Status der App. Als Standardwert direkt `.shared` zu
            // schreiben, warnt Swift 6: der Ausdruck läge außerhalb der Hauptakteur-Isolation.
            (reporter ?? CloudSyncStatusCenter.shared).noteMaintenance(report)
        }

        return report
    }

    /// Wer bei Duplikaten ueberlebt: **immer die kleinste UUID.**
    ///
    /// Vorher gewann die inhaltsreichere Kopie. Das konvergiert nicht: der Inhalt wird lokal
    /// gezaehlt, und waehrend eines Imports kommen Wochen vor ihren Tagen an. Zwei Geraete
    /// sahen dieselben zwei Kopien verschieden schwer, jedes loeschte die jeweils andere —
    /// und mit der frueheren Kaskade gingen dabei Aufgaben verloren. Die UUID sieht auf jedem
    /// Geraet gleich aus, egal wie weit der Import ist.
    ///
    /// Dass dabei eine leere Kopie gewinnen kann, ist kein Verlust: die Kinder werden vor dem
    /// Loeschen umgehaengt, und was spaeter noch an die geloeschte Kopie gebunden ankommt,
    /// sammelt `adoptOrphans` ein. Das alte Problem, dass frische Onboarding-Anker die echten
    /// verdraengten, loest jetzt die Zielreihenfolge in `merge(_:into:)`: Anker mit Aufgaben
    /// kommen vor leeren.
    private static func electSurvivor(_ candidates: [Week]) -> Week? {
        candidates.min { $0.id.uuidString < $1.id.uuidString }
    }

    private static func electSurvivor(_ candidates: [Day]) -> Day? {
        candidates.min { $0.id.uuidString < $1.id.uuidString }
    }

    private static func merge(_ duplicate: Week, into survivor: Week, modelContext: ModelContext) {
        // Beide Wochen numerieren ihre Anker ab 0. Ohne Umnumerieren stehen nach dem
        // Zusammenführen zwei Ziele auf Platz 0, und beim Gleichstand entscheidet die UUID,
        // welche vier sichtbar bleiben — der Nutzer sähe seine echten Anker verschwinden und
        // fremde an ihrer Stelle. Die Ziele der überlebenden Woche behalten deshalb ihre
        // Plätze, die der doppelten kommen dahinter.
        // Beide Wochen numerieren ihre Anker ab 0. Gemeinsam neu ordnen: zuerst Anker, die
        // schon benutzt werden (Warum-Satz, Antwort, echter Titel — siehe `isInUse`), dann leere — so verdraengen vier
        // frisch angelegte Onboarding-Anker nicht die echten. Innerhalb derselben Stufe die
        // bisherige Nummer, dann die UUID: auf jedem Geraet dieselbe Folge.
        let combined = (survivor.goalList + duplicate.goalList).filter { !$0.isDeleted }
        var seen = Set<UUID>()
        let unique = combined.filter { seen.insert($0.id).inserted }
        let ordered = unique.sorted { left, right in
            let leftRank = usageRank(left), rightRank = usageRank(right)
            if leftRank != rightRank { return leftRank > rightRank }
            if left.order != right.order { return left.order < right.order }
            return left.id.uuidString < right.id.uuidString
        }
        for (index, goal) in ordered.enumerated() {
            if goal.order != index { goal.order = index }
            if goal.week !== survivor { goal.week = survivor }
        }
        duplicate.goals = []
        survivor.goals = ordered

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

    /// Wie sehr wird dieser Anker benutzt? **Nur aus Feldern des Ziel-Datensatzes selbst.**
    ///
    /// Früher zählten auch seine Aufgaben. Die sind aber lokal und importabhängig: mitten in
    /// einem Import sieht ein Gerät die Aufgaben schon, das andere noch nicht — und beide
    /// ordneten dieselben Anker verschieden. Warum-Satz, Antwort und Titel kommen mit dem
    /// Datensatz selbst an und sehen überall gleich aus.
    ///
    /// Gestuft, damit ein frisch im Onboarding getippter Anker (nur Titel) nicht gleichauf mit
    /// einem steht, zu dem es schon ein Warum oder eine Antwort gibt:
    /// 2 = Warum oder Antwort, 1 = echter Titel, 0 = leer oder Platzhalter.
    static func usageRank(_ goal: Goal) -> Int {
        let hasWhy = goal.why?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        if hasWhy || goal.verdictRaw != nil { return 2 }
        let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return (!title.isEmpty && title != WeekPlanning.placeholderGoalTitle) ? 1 : 0
    }

    static func isInUse(_ goal: Goal) -> Bool { usageRank(goal) > 0 }

    // MARK: - Verwaistes einsammeln

    /// Haengt Tage ohne Woche, Ziele ohne Woche und Zeitbloecke ohne Tag wieder ein.
    ///
    /// Verwaist wird ein Datensatz, wenn sein Elternteil geloescht wurde, bevor er selbst
    /// ankam oder umgehaengt war — typischerweise ein Tag, dessen doppelte Woche ein anderes
    /// Geraet schon zusammengefuehrt hat. Seit den `.nullify`-Regeln geht dabei nichts mehr
    /// verloren, es ist nur unsichtbar, bis es hier wieder einen Platz bekommt.
    ///
    /// **Eingehängt wird nur in vorhandene Wochen und Tage.** Früher legte diese Funktion die
    /// fehlende Woche an. Hat aber nur ein abgebrochener Import die Tage vor ihrer Woche
    /// gebracht, entstand so neben der noch kommenden echten Woche ein Duplikat — auf jedem
    /// Gerät eines, und jedes wurde exportiert. Eine Waise ohne vorhandene Woche bleibt liegen,
    /// bis die Woche ankommt (oder der Nutzer in diese Woche schreibt).
    ///
    /// Aufgaben ohne Tag sind **kein** Waisenfall: mit Ziel heissen sie „noch nicht
    /// eingeplant", ohne Ziel liegen sie im Eingang. Sie bleiben, wie sie sind — mit einer
    /// Ausnahme: hängen sie an einem Ziel ohne Woche, sähe sie niemand. Dann lösen sie sich
    /// vom Ziel und stehen im Eingang; das Ziel bleibt.
    @discardableResult
    static func adoptOrphans(weeks: [Week], modelContext: ModelContext) -> Int {
        var adopted = 0
        // Bekannte Wochen plus ein frischer Fetch: die übergebene Liste kann ein Ausschnitt sein.
        var known = weeks.filter { !$0.isDeleted }
        let knownIDs = Set(known.map(\.id))
        known += ((try? modelContext.fetch(FetchDescriptor<Week>())) ?? [])
            .filter { !$0.isDeleted && !knownIDs.contains($0.id) }

        // Per Prädikat statt alles zu holen und im Speicher zu filtern: Waisen sind die Ausnahme.
        let orphanDays = ((try? modelContext.fetch(FetchDescriptor<Day>(predicate: #Predicate { $0.week == nil }))) ?? [])
            .filter { !$0.isDeleted }
        for day in orphanDays {
            let nominal = AnkerCalendar.nominalDate(ofStored: day.date)
            let key = AnkerCalendar.weekKey(containing: nominal)
            guard let week = WeekPlanning.week(startingAt: nominal, in: known) else {
                cloudSyncLog.notice("Verwaister Tag \(dayKey(day), privacy: .public) wartet auf \(key.isoYear, privacy: .public)-KW\(key.isoWeek, privacy: .public)")
                continue
            }

            if let twin = WeekPlanning.existingDay(on: nominal, in: week), twin !== day {
                // Den Tag gibt es in der Woche schon: Inhalt hinueber, Waise loeschen.
                merge(day, into: twin, modelContext: modelContext)
                TaskActions.normalizeOrders(in: twin)
            } else {
                day.week = week
                week.days = week.dayList + [day]
            }
            cloudSyncLog.notice("Verwaister Tag \(dayKey(day), privacy: .public) in \(key.isoYear, privacy: .public)-KW\(key.isoWeek, privacy: .public) eingehaengt")
            adopted += 1
        }

        // Ziele haben kein Datum. Ihre Woche ergibt sich aus ihren eingeplanten Aufgaben.
        let orphanGoals = ((try? modelContext.fetch(FetchDescriptor<Goal>(predicate: #Predicate { $0.week == nil }))) ?? [])
            .filter { !$0.isDeleted }
        for goal in orphanGoals {
            if let week = goal.taskList.compactMap({ $0.day?.week }).first(where: { !$0.isDeleted }) {
                goal.order = GoalOrdering.nextOrder(in: week)
                goal.week = week
                week.appendGoal(goal)
                adopted += 1
                continue
            }

            // Keine Aufgabe mit Tag: das Ziel findet keine Woche. Seine Aufgaben ohne Tag wären
            // unsichtbar — der Eingang filtert `linkedGoal == nil`. In den Eingang damit.
            let stranded = goal.taskList.filter { !$0.isDeleted && $0.day == nil }
            guard !stranded.isEmpty else { continue }
            for task in stranded { task.linkedGoal = nil }
            goal.tasks = goal.taskList.filter { task in !stranded.contains { $0 === task } }
            cloudSyncLog.notice("\(stranded.count, privacy: .public) Aufgaben eines Ziels ohne Woche in den Eingang gelegt")
            adopted += stranded.count
        }

        let orphanBlocks = ((try? modelContext.fetch(FetchDescriptor<TimeBlock>(predicate: #Predicate { $0.day == nil }))) ?? [])
            .filter { !$0.isDeleted }
        for block in orphanBlocks {
            guard let week = WeekPlanning.week(startingAt: block.startTime, in: known),
                  let day = WeekPlanning.existingDay(on: block.startTime, in: week) else { continue }
            block.day = day
            day.timeBlocks = day.timeBlockList + [block]
            adopted += 1
        }

        return adopted
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
