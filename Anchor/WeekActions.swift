import Foundation
import SwiftData

/// Mutationen an einer Woche — das dritte Gegenstück zu `TaskActions` und `GoalActions`.
@MainActor
enum WeekActions {

    static func setReflection(_ text: String?, in week: Week, modelContext: ModelContext) {
        let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        guard week.reflection != clean else { return }
        week.reflection = clean
        modelContext.saveChanges()
    }

    // MARK: - Reife des Rückblicks

    /// Wie laut der Rückblick sein darf.
    ///
    /// Der Entwurf nennt das „scharf, nicht laut": erreichbar ist er immer, aber bis die Woche
    /// endet bleibt die Zeile grau und **ohne Zähler**. Ab Sonntag wird sie rot und nennt, was
    /// offen ist. Kein Modal, keine Unterbrechung — das war der Grund, warum sich der alte
    /// Rückblick wie eine Mahnung anfühlte.
    enum ReviewReadiness: Equatable {
        /// Mitten in der Woche: erreichbar, aber stumm.
        case quiet
        /// Ab Sonntag oder danach. Nennt den Übertrag.
        case armed(open: Int)
        /// Schon abgeschlossen.
        case closed(at: Date)

        var isArmed: Bool {
            if case .armed = self { return true }
            return false
        }

        /// Der kurze Zusatz rechts in der Zeile.
        var meta: String {
            switch self {
            case .quiet:
                return String(localized: "ab So")
            case .armed(let open):
                return open == 0 ? String(localized: "nichts offen") : String(localized: "\(open) offen")
            case .closed(let date):
                return AnkerDateFormat.dayMonth(date)
            }
        }
    }

    static func readiness(of week: Week, now: Date = Date()) -> ReviewReadiness {
        if let reviewedAt = week.reviewedAt { return .closed(at: reviewedAt) }
        // Ab dem Sonntag der Woche, also sobald ihr letzter Tag begonnen hat. `sunday` ist der
        // Tagesbeginn, deshalb genügt der Vergleich — nicht erst, wenn die Woche ganz vorbei ist:
        // dann käme der Hinweis, wenn er nichts mehr ändern kann.
        guard now >= AnkerCalendar.nominalDate(ofStored: week.sunday) else { return .quiet }
        return .armed(open: openTaskCount(in: week))
    }

    // MARK: - Schließen

    /// Was mit einer offenen Aufgabe beim Schließen passiert.
    ///
    /// Der Entwurf verlangt die Entscheidung **pro Aufgabe**: „Nichts wandert stillschweigend —
    /// das war der Grund, warum die Übersicht sich fremd anfühlte." Vorher gab es nur
    /// alles-oder-nichts.
    enum CarryDecision: Equatable {
        /// In die Folgewoche übertragen, Anker bleibt wie er ist.
        case keep
        /// Streichen. Die Aufgabe wird gelöscht.
        case drop
        /// Übertragen und an einen anderen Anker hängen; `nil` heißt ohne Anker.
        ///
        /// Der Anker muss einer der **Zielwoche** sein. Gibt es ihn dort nicht, bleibt die
        /// Aufgabe ohne Anker — `TaskActions.move` löst die Verknüpfung über die Wochengrenze
        /// ohnehin, ein Anker gehört genau einer Woche.
        case reanchor(goalID: UUID?)
    }

    struct CloseReport: Equatable {
        var carriedOverTasks = 0
        var droppedTasks = 0
        var reanchoredTasks = 0
        /// Offene wiederkehrende Aufgaben, deren Folgeinstanz es schon gibt. Mitnehmen hätte
        /// sie verdoppelt; sie bleiben in ihrer Woche stehen.
        var supersededTasks = 0
        var targetISOWeek = 0
        var didSave = true
    }

    /// Was im Rückblick „offen geblieben" ist — **die** Liste, die `ReviewScreen` zeigt und
    /// deren Länge `readiness` nennt.
    ///
    /// Offene Aufgaben der Ankerbahnen (mit oder ohne Tag) und die der losen Bahn, die zu
    /// dieser Woche gehören: an einem ihrer Tage ohne Anker, und Aufgaben überzähliger Ziele.
    /// Der Eingang gehört zu keiner Woche und zählt nie mit, auch wenn das Blatt ihn zeigt.
    static func openTasks(in sheet: WeekSheet) -> [AnkerTask] {
        var seen = Set<UUID>()
        return sheet.lanes.flatMap(\.tasks).filter { task in
            !task.isDone
                && !task.isDeleted
                && !(task.day == nil && task.linkedGoal == nil)
                && seen.insert(task.id).inserted
        }
    }

    /// Wie viele Aufgaben eine Schließung verschieben würde — für den Bestätigungstext.
    ///
    /// Dieselbe Zahl wie `openTasks(in:)`. Vorher zählte sie nur Aufgaben an Tagen, der
    /// Rückblick listete aber auch offene Anker-Aufgaben ohne Tag: „2 offen" über drei Zeilen.
    static func openTaskCount(in week: Week) -> Int {
        openTasks(in: WeekSheet(week: week, includesInbox: false)).count
    }

    /// Schließt die Woche und schiebt offene Aufgaben in die Folgewoche.
    ///
    /// Läuft über `TaskActions.move`, damit der Übertragungszähler stimmt und die Reihenfolge
    /// im Zieltag normalisiert wird — nicht über direkte Zuweisungen.
    ///
    /// Der Übertrag wird **benannt**, nicht stillschweigend erledigt: der Rückblick nennt die
    /// Zahl vorher, und `CloseReport` gibt sie danach zurück.
    @discardableResult
    static func close(
        _ week: Week,
        at now: Date = Date(),
        carryOverOpenTasks: Bool = true,
        weeks: [Week],
        modelContext: ModelContext
    ) -> CloseReport {
        // `carryOverOpenTasks: false` liess die Aufgaben in ihrer Woche stehen, statt sie zu
        // streichen. Diese Bedeutung bleibt: keine Entscheidung, nicht `.drop`. Wer streichen
        // will, sagt es pro Aufgabe.
        close(
            week,
            at: now,
            decisions: [:],
            fallback: carryOverOpenTasks ? .keep : nil,
            weeks: weeks,
            modelContext: modelContext
        )
    }

    /// Schließt die Woche und wendet auf jede offene Aufgabe ihre Entscheidung an.
    ///
    /// Aufgaben ohne Eintrag in `decisions` bekommen `fallback`. Ist `fallback` nil, bleiben sie
    /// unangetastet in ihrer Woche stehen — genau das ist „Nur schließen".
    ///
    /// Betroffen ist genau `openTasks(in:)`, also auch offene Anker-Aufgaben **ohne Tag**. Die
    /// bleiben beim Mitnehmen ohne Tag.
    ///
    /// **Mitnehmen behält den Anker, wenn es ihn drüben gibt.** Ein Anker gehört zu genau einer
    /// Woche, `TaskActions.move` löst ihn deshalb über die Wochengrenze. Hat die Folgewoche
    /// schon einen Anker mit demselben Titel (getrimmt, ohne Groß-/Kleinschreibung), hängt die
    /// Aufgabe dort an. Sonst steht sie ohne Anker — an ihrem Tag bzw. im Eingang.
    ///
    /// Grenze: Wird der gleichnamige Anker erst **nach** dem Schließen gesetzt (Montag im
    /// Setzen), findet er die mitgenommenen Aufgaben nicht mehr. Woher eine ankerlose Aufgabe
    /// kam, steht in keinem Feld (`carryOverCount` sagt nur *dass*, nicht *von welchem Anker*),
    /// und ein neues Modellfeld wäre eine Schemaänderung.
    @discardableResult
    static func close(
        _ week: Week,
        at now: Date = Date(),
        decisions: [UUID: CarryDecision],
        fallback: CarryDecision? = .keep,
        weeks: [Week],
        modelContext: ModelContext
    ) -> CloseReport {
        var report = CloseReport()
        let monday = AnkerCalendar.nominalDate(ofStored: week.monday)
        let nextMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: monday) ?? monday
        report.targetISOWeek = AnkerCalendar.weekInterval(containing: nextMonday).isoWeek

        // Erst sammeln, dann anwenden: `move` und `delete` hängen Aufgaben um, und darüber zu
        // iterieren, während sich die Beziehung ändert, ist nicht verlässlich.
        let open = openTasks(in: WeekSheet(week: week, now: now, includesInbox: false))
        var knownWeeks = weeks

        for task in open {
            guard let decision = decisions[task.id] ?? fallback else { continue }
            let sourceTitle = task.linkedGoal?.title

            // Wieder geöffnet, nachdem das Abhaken schon die Folgeinstanz erzeugt hatte: die
            // Wiederholung steht drüben bereits. Mitnehmen hieße zweimal dieselbe Aufgabe.
            if decision != .drop, TaskActions.nextOccurrence(of: task, modelContext: modelContext) != nil {
                report.supersededTasks += 1
                continue
            }

            switch decision {
            case .drop:
                TaskActions.delete(task, save: false, modelContext: modelContext)
                report.droppedTasks += 1

            case .keep:
                if task.day != nil {
                    guard let target = nextWeekDate(for: task, in: week) else { continue }
                    TaskActions.move(task, to: target, weeks: knownWeeks, save: false, modelContext: modelContext)
                    if let targetWeek = task.day?.week, !knownWeeks.contains(where: { $0 === targetWeek }) {
                        knownWeeks.append(targetWeek)
                    }
                    if task.linkedGoal == nil, let sourceTitle, let targetWeek = task.day?.week {
                        task.linkedGoal = matchingAnchor(titled: sourceTitle, in: targetWeek)
                    }
                } else {
                    // Ohne Tag gibt es nichts zu schreiben außer dem Anker: die Folgewoche nur
                    // finden, nie anlegen.
                    let targetWeek = TaskActions.existingWeek(containing: nextMonday, weeks: knownWeeks, modelContext: modelContext)
                    let goal = sourceTitle.flatMap { title in targetWeek.flatMap { matchingAnchor(titled: title, in: $0) } }
                    TaskActions.link(task, to: goal, save: false, modelContext: modelContext)
                }
                report.carriedOverTasks += 1

            case .reanchor(let goalID):
                if task.day != nil {
                    guard let target = nextWeekDate(for: task, in: week) else { continue }
                    TaskActions.place(task, on: target, goalID: goalID, weeks: knownWeeks, save: false, modelContext: modelContext)
                    if let targetWeek = task.day?.week, !knownWeeks.contains(where: { $0 === targetWeek }) {
                        knownWeeks.append(targetWeek)
                    }
                } else {
                    let targetWeek = TaskActions.existingWeek(containing: nextMonday, weeks: knownWeeks, modelContext: modelContext)
                    let goal = goalID.flatMap { id in targetWeek?.goalList.first { $0.id == id } }
                    TaskActions.link(task, to: goal, save: false, modelContext: modelContext)
                }
                report.carriedOverTasks += 1
                report.reanchoredTasks += 1
            }
        }

        week.reviewedAt = now
        report.didSave = modelContext.saveChanges()
        return report
    }

    /// Der Anker der Woche mit demselben Titel — getrimmt, ohne Groß-/Kleinschreibung. Nur die
    /// sichtbaren vier; ein überzähliges Ziel ist kein Anker.
    static func matchingAnchor(titled title: String, in week: Week) -> Goal? {
        let needle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return nil }
        return GoalOrdering.anchors(in: week).first { goal in
            goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .compare(needle, options: [.caseInsensitive]) == .orderedSame
        }
    }

    /// Derselbe Wochentag eine Woche später. Bewusst nicht der Montag der Folgewoche: eine
    /// Aufgabe, die für den Freitag gedacht war, bleibt eine Freitagsaufgabe.
    ///
    /// Ab dem **gemeinten** Kalendertag: `Day.date` ist Mitternacht in der Zone des anlegenden
    /// Geräts. Ein Freitag aus Tokio ist in Berlin Donnerstag 16 Uhr — direkt darauf eine Woche
    /// addiert, wäre die Aufgabe drüben eine Donnerstagsaufgabe.
    ///
    /// Eine wiederkehrende Aufgabe landet auf ihrem ersten Termin in der Folgewoche — eine
    /// tägliche Aufgabe vom Sonntag am Montag, nicht am nächsten Sonntag. Fällt kein Termin in
    /// die Folgewoche (alle 2 Wochen, monatlich), bleibt es beim selben Wochentag.
    private static func nextWeekDate(for task: AnkerTask, in week: Week) -> Date? {
        let source = AnkerCalendar.nominalDate(ofStored: task.day?.date ?? week.monday)
        let sameWeekday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: source)

        guard let rule = task.recurrence, task.day != nil else { return sameWeekday }
        let nextKey = AnkerCalendar.weekKey(containing: AnkerCalendar.nominalDate(ofStored: week.monday)).next
        var candidate = source
        // Höchstens zwei Wochen weit: weiter reicht keine Regel, die in die Folgewoche trifft.
        for _ in 0..<14 {
            candidate = rule.nextDate(after: candidate)
            let key = AnkerCalendar.weekKey(containing: candidate)
            if key == nextKey { return candidate }
            if key > nextKey { break }
        }
        return sameWeekday
    }

    static func reopen(_ week: Week, modelContext: ModelContext) {
        guard week.reviewedAt != nil else { return }
        week.reviewedAt = nil
        modelContext.saveChanges()
    }
}
