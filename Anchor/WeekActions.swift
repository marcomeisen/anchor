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
                return "ab So"
            case .armed(let open):
                return open == 0 ? "nichts offen" : "\(open) offen"
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
        guard now >= week.sunday else { return .quiet }
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
        var targetISOWeek = 0
        var didSave = true
    }

    /// Wie viele Aufgaben eine Schließung verschieben würde — für den Bestätigungstext.
    static func openTaskCount(in week: Week) -> Int {
        week.dayList.flatMap(\.taskList).filter { !$0.isDone }.count
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
        let nextMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday) ?? week.monday
        report.targetISOWeek = AnkerCalendar.weekInterval(containing: nextMonday).isoWeek

        // Erst sammeln, dann anwenden: `move` und `delete` hängen Aufgaben um, und darüber zu
        // iterieren, während sich die Beziehung ändert, ist nicht verlässlich.
        let open = week.dayList
            .sorted { $0.date < $1.date }
            .flatMap { $0.taskList.filter { !$0.isDone } }

        for task in open {
            guard let decision = decisions[task.id] ?? fallback else { continue }

            switch decision {
            case .drop:
                TaskActions.delete(task, modelContext: modelContext)
                report.droppedTasks += 1

            case .keep:
                guard let target = nextWeekDate(for: task, in: week) else { continue }
                TaskActions.move(task, to: target, weeks: weeks, modelContext: modelContext)
                report.carriedOverTasks += 1

            case .reanchor(let goalID):
                guard let target = nextWeekDate(for: task, in: week) else { continue }
                TaskActions.place(task, on: target, goalID: goalID, weeks: weeks, modelContext: modelContext)
                report.carriedOverTasks += 1
                report.reanchoredTasks += 1
            }
        }

        week.reviewedAt = now
        report.didSave = modelContext.saveChanges()
        return report
    }

    /// Derselbe Wochentag eine Woche später. Bewusst nicht der Montag der Folgewoche: eine
    /// Aufgabe, die für den Freitag gedacht war, bleibt eine Freitagsaufgabe.
    private static func nextWeekDate(for task: AnkerTask, in week: Week) -> Date? {
        let source = task.day?.date ?? week.monday
        return AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: source)
    }

    static func reopen(_ week: Week, modelContext: ModelContext) {
        guard week.reviewedAt != nil else { return }
        week.reviewedAt = nil
        modelContext.saveChanges()
    }
}
