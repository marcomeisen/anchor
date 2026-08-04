import Foundation
import SwiftData

/// Auflösen und Anlegen von Wochen, Tagen und dem ersten Wochenziel.
///
/// Vorher lag das alles als private Methoden in `AnkerRootView` — Navigation, Onboarding,
/// Wochenanlage und Zielverwaltung in einem Typ, und damit nur über die Oberfläche prüfbar.
/// Hier sind es Funktionen über `[Week]`, die ohne View aufrufbar und testbar sind.
@MainActor
enum WeekPlanning {

    // MARK: - Auflösen

    /// Die Woche, in der `date` liegt.
    static func week(containing date: Date, in weeks: [Week]) -> Week? {
        weeks.sorted { $0.monday < $1.monday }.first { contains(date, in: $0) }
    }

    /// Die Woche, die genau an `monday` beginnt.
    static func week(startingAt monday: Date, in weeks: [Week]) -> Week? {
        weeks.first { AnkerCalendar.isSameDay($0.monday, monday) }
    }

    /// Vergleich über `monday ..< monday + 7` statt `monday ... sunday`.
    ///
    /// `sunday` ist auf den Tagesanfang normalisiert; ein `<=`-Vergleich würde den Sonntag
    /// ab 00:01 aus seiner eigenen Woche fallen lassen.
    static func contains(_ date: Date, in week: Week) -> Bool {
        let nextMonday = AnkerCalendar.iso.date(byAdding: .day, value: 7, to: week.monday) ?? week.sunday
        return date >= week.monday && date < nextMonday
    }

    /// Der Tag zu `date`, mit Rückfall auf heute und dann auf den ersten Tag der Woche.
    ///
    /// Der Rückfall ist kein Luxus: nach dem Zusammenführen doppelter Tage aus dem Sync kann
    /// der bisher gewählte Tag verschwunden sein, und ohne Tag zeigt die App nur einen Spinner.
    static func day(on date: Date, in week: Week?, now: Date = Date()) -> Day? {
        let sortedDays = week?.dayList.sorted { $0.date < $1.date }
        return sortedDays?.first { AnkerCalendar.isSameDay($0.date, date) }
            ?? sortedDays?.first { AnkerCalendar.isSameDay($0.date, now) }
            ?? sortedDays?.first
    }

    /// Der Tag hinter einer ID, über alle Wochen. Für Suchtreffer.
    static func day(withID id: UUID, in weeks: [Week]) -> Day? {
        weeks.lazy.flatMap(\.dayList).first { $0.id == id }
    }

    // MARK: - Anlegen

    @discardableResult
    static func ensureWeek(containing date: Date, weeks: [Week], modelContext: ModelContext) -> Week {
        TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
    }

    // MARK: - Onboarding

    /// Titel, den `OnboardingView` vorschlägt und der deshalb nicht als echtes Ziel zählt.
    static let placeholderGoalTitle = "Erstes Wochenziel"

    /// Onboarding zeigen?
    ///
    /// **Der ganze Bestand entscheidet, nicht die laufende Woche.** Vorher fragte diese Funktion
    /// nur, ob die laufende Woche Anker hat — und das ist am Montagmorgen regelmäßig nicht der
    /// Fall. Auf einem neu installierten Gerät landete der Nutzer damit im Onboarding, obwohl
    /// sein ganzer iCloud-Bestand schon da war, und kam nicht mehr heraus: das Flag wurde in
    /// diesem Zweig gar nicht mehr gelesen, ein Überspringen wäre also wirkungslos geblieben.
    ///
    /// Nicht am Flag allein hängt es weiterhin, weil eine vollständige Löschung den Bestand
    /// leert — und eine leere App, die sich für eingerichtet hält, ist eine Sackgasse.
    static func needsOnboarding(in weeks: [Week], hasCompletedOnboarding: Bool, now: Date = Date()) -> Bool {
        if hasContent(in: weeks) { return false }
        return !hasCompletedOnboarding
    }

    /// Benutzt hier schon jemand die App?
    ///
    /// Ein echtes Wochenziel **oder** eine Aufgabe irgendwo genügt. Aufgaben zählen mit, weil
    /// die Erfassungszeile sie auch ohne Anker anlegt — wer so arbeitet, ist kein neuer Nutzer.
    /// Der Onboarding-Platzhalter zählt nicht, `isUserCreated` filtert ihn.
    static func hasContent(in weeks: [Week]) -> Bool {
        weeks.contains { week in
            week.goalList.contains(where: isUserCreated)
                || week.dayList.contains { !$0.taskList.isEmpty }
        }
    }

    static func isUserCreated(_ goal: Goal) -> Bool {
        let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && !isPlaceholder(goal)
    }

    static func isPlaceholder(_ goal: Goal) -> Bool {
        goal.title.trimmingCharacters(in: .whitespacesAndNewlines) == placeholderGoalTitle
            && goal.taskList.isEmpty
    }

    /// Legt das erste Wochenziel an — oder benennt den Platzhalter um, falls einer existiert.
    ///
    /// Ohne das Umbenennen entstünde bei einem zweiten Durchlauf des Onboardings ein
    /// zusätzliches leeres Ziel, und das Limit von vier Wochenzielen wäre unnötig verbraucht.
    @discardableResult
    static func upsertOnboardingGoal(title: String, in week: Week, modelContext: ModelContext) -> Goal {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let placeholder = week.goalList.first(where: isPlaceholder) {
            placeholder.title = cleanTitle
            placeholder.colorHex = defaultGoalColorHex
            return placeholder
        }

        let goal = Goal(
            title: cleanTitle,
            colorHex: defaultGoalColorHex,
            order: GoalOrdering.nextOrder(in: week),
            week: week
        )
        modelContext.insert(goal)
        week.appendGoal(goal)
        return goal
    }

    /// Legt bis zu vier Anker aus dem Onboarding an.
    ///
    /// Der erste ersetzt einen etwaigen Platzhalter, die weiteren kommen dahinter. Gibt die
    /// angelegten Ziele in Eingabereihenfolge zurueck, damit der Aufrufer zum ersten springen
    /// kann.
    @discardableResult
    static func createOnboardingAnchors(
        _ titles: [String],
        in week: Week,
        modelContext: ModelContext
    ) -> [Goal] {
        // Während das Onboarding offen stand, kann der Erstimport aus iCloud Anker gebracht
        // haben. Dann ist das hier kein neuer Nutzer mehr, und es wird **nichts** angelegt:
        // sonst stünden seine echten Anker neben vier erfundenen.
        guard week.goalList.filter(isUserCreated).isEmpty else { return [] }

        var created: [Goal] = []

        for (index, title) in titles.prefix(GoalOrdering.maxAnchors).enumerated() {
            if index == 0 {
                created.append(upsertOnboardingGoal(title: title, in: week, modelContext: modelContext))
            } else if let goal = GoalActions.create(
                title: title,
                colorHex: defaultGoalColorHex,
                in: week,
                modelContext: modelContext
            ) {
                created.append(goal)
            }
        }

        GoalOrdering.normalize(week)
        return created
    }

    /// Indigo aus dem Designsystem — dieselbe Farbe, die `NewGoalSheet` vorbelegt.
    static let defaultGoalColorHex = "#5B6EE8"
}
