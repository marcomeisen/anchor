import Foundation
import SwiftData
import SwiftUI

/// Suche über Aufgaben, Wochenziele, Notizen und Zeitblöcke.
///
/// Bewusst als reine Funktion über die bereits geladenen Wochen statt als `FetchDescriptor`
/// mit `#Predicate`: gesucht wird auch in `Day.notes` und `Day.focusNote`, und die Treffer
/// brauchen ihren Kontext (Kalenderwoche, Tag, zugeordnetes Ziel) für die Anzeige und die
/// anschließende Navigation. Der Bestand ist klein — ein Jahr Nutzung sind rund 365 Tage.
/// Nur Aufgaben **ohne Tag** kommen per Fetch dazu; sie hängen an keinem Tag einer Woche.
enum AnkerSearch {
    enum Kind: String, Hashable {
        case task
        case goal
        case note
        case focus
        case timeBlock

        var title: String {
            switch self {
            case .task: String(localized: "Aufgabe")
            case .goal: String(localized: "Anker")
            case .note: String(localized: "Notiz")
            case .focus: String(localized: "Tagesfokus")
            case .timeBlock: String(localized: "Zeitblock")
            }
        }

        var icon: AnkerIcon {
            switch self {
            case .task: .checkCircle
            case .goal: .goal
            case .note: .note
            case .focus: .today
            case .timeBlock: .time
            }
        }

        /// Reihenfolge in der Ergebnisliste. Aufgaben und Ziele zuerst, weil danach am
        /// häufigsten gesucht wird; Notizen sind der Nachschlage-Fall.
        var sortRank: Int {
            switch self {
            case .task: 0
            case .goal: 1
            case .focus: 2
            case .note: 3
            case .timeBlock: 4
            }
        }
    }

    struct Result: Identifiable, Hashable {
        let id: UUID
        let kind: Kind
        /// Der Text, in dem der Treffer steckt — bei Notizen auf die Fundstelle gekürzt.
        let title: String
        /// Wo der Treffer sitzt: Kalenderwoche, Datum, zugeordnetes Ziel.
        let context: String
        let isDone: Bool
        /// Tag zum Anspringen. Leer bei Wochenzielen, Rückblicken und Aufgaben ohne Tag —
        /// die springen über `date` in ihre Woche bzw. über `goalID` zum Anker.
        let dayID: UUID?
        let goalID: UUID?
        /// Für Sortierung und Sprung: Datum des Tages, bei Zielen und Rückblicken der Montag der
        /// Woche, im Eingang „jetzt".
        let date: Date
    }

    /// Wie `results(for:in:unscheduled:)`, holt die Aufgaben ohne Tag selbst aus dem Store.
    ///
    /// Die hängen an keinem Tag und wären über `week.dayList` unauffindbar: Anker-Aufgaben,
    /// die noch nicht eingeplant sind, und der ganze Eingang.
    static func results(
        for query: String,
        in weeks: [Week],
        modelContext: ModelContext,
        now: Date = Date(),
        limit: Int = 60
    ) -> [Result] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }
        let descriptor = FetchDescriptor<AnkerTask>(predicate: #Predicate { $0.day == nil })
        let unscheduled = (try? modelContext.fetch(descriptor)) ?? []
        return results(for: query, in: weeks, unscheduled: unscheduled, now: now, limit: limit)
    }

    /// Leeres Ergebnis bei leerer Eingabe, statt alles zurückzugeben.
    ///
    /// `unscheduled` sind Aufgaben ohne Tag. Mit Anker springt ihr Treffer zum Anker in seiner
    /// Woche, ohne Anker (Eingang) zur laufenden Woche.
    static func results(
        for query: String,
        in weeks: [Week],
        unscheduled: [AnkerTask] = [],
        now: Date = Date(),
        limit: Int = 60
    ) -> [Result] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }

        var results: [Result] = []
        // Beschriftungen erst beim Treffer bauen: Datumsformatierung ist der teure Teil, und
        // die allermeisten Tage treffen nicht.
        func weekLabel(_ week: Week) -> String {
            "\(AnkerDateFormat.calendarWeek(week.isoWeek)) · \(week.isoYear)"
        }

        for week in weeks where !week.isDeleted {
            let monday = AnkerCalendar.nominalDate(ofStored: week.monday)

            for goal in week.goalList where !goal.isDeleted {
                let titleHit = matches(goal.title, needle)
                let whyHit = !titleHit && matches(goal.why ?? "", needle)
                guard titleHit || whyHit else { continue }
                let context = whyHit
                    ? "\(snippet(of: goal.why ?? "", around: needle)) · \(weekLabel(week))"
                    : weekLabel(week)
                results.append(
                    Result(
                        id: goal.id,
                        kind: .goal,
                        title: goal.title,
                        context: context,
                        isDone: goal.progress >= 1,
                        dayID: nil,
                        goalID: goal.id,
                        date: monday
                    )
                )
            }

            if let reflection = week.reflection, matches(reflection, needle) {
                results.append(
                    Result(
                        id: week.id,
                        kind: .note,
                        title: snippet(of: reflection, around: needle),
                        context: String(localized: "Rückblick · \(weekLabel(week))"),
                        isDone: false,
                        dayID: nil,
                        goalID: nil,
                        // Ziel des Sprungs: die Woche des Rückblicks.
                        date: monday
                    )
                )
            }

            for day in week.dayList where !day.isDeleted {
                let date = AnkerCalendar.nominalDate(ofStored: day.date)
                func dayLabel() -> String { AnkerDateFormat.weekdayShortWithDayMonth(date) }

                for task in day.taskList where !task.isDeleted && matches(task.title, needle) {
                    var context = String(localized: "\(dayLabel()) · Prio \(task.priority.label)")
                    if let goalTitle = task.linkedGoal?.title, !goalTitle.isEmpty {
                        context += " · \(goalTitle)"
                    }
                    results.append(
                        Result(
                            id: task.id,
                            kind: .task,
                            title: task.title,
                            context: context,
                            isDone: task.isDone,
                            dayID: day.id,
                            goalID: task.linkedGoal?.id,
                            date: date
                        )
                    )
                }

                if let focus = day.focusNote, matches(focus, needle) {
                    results.append(
                        Result(
                            id: day.id,
                            kind: .focus,
                            title: snippet(of: focus, around: needle),
                            context: "\(dayLabel()) · \(weekLabel(week))",
                            isDone: false,
                            dayID: day.id,
                            goalID: nil,
                            date: date
                        )
                    )
                }

                if let notes = day.notes, matches(notes, needle) {
                    results.append(
                        Result(
                            // Nicht `day.id`: der Tag kann auch über den Fokus getroffen sein,
                            // und zwei Ergebnisse mit gleicher `id` verschluckt `ForEach`.
                            id: noteResultID(for: day),
                            kind: .note,
                            title: snippet(of: notes, around: needle),
                            context: "\(dayLabel()) · \(weekLabel(week))",
                            isDone: false,
                            dayID: day.id,
                            goalID: nil,
                            date: date
                        )
                    )
                }

                for block in day.timeBlockList where matches(block.title, needle) {
                    results.append(
                        Result(
                            id: block.id,
                            kind: .timeBlock,
                            title: block.title,
                            context: "\(dayLabel()) · \(AnkerDateFormat.clock(block.startTime))",
                            isDone: false,
                            dayID: day.id,
                            goalID: nil,
                            date: date
                        )
                    )
                }
            }
        }

        var seenTasks = Set(results.lazy.filter { $0.kind == .task }.map(\.id))
        for task in unscheduled where !task.isDeleted && task.day == nil && matches(task.title, needle) {
            guard seenTasks.insert(task.id).inserted else { continue }
            var context = String(localized: "Ohne Tag · Prio \(task.priority.label)")
            var date = now
            if let goal = task.linkedGoal, !goal.isDeleted {
                if !goal.title.isEmpty { context += " · \(goal.title)" }
                if let week = goal.week {
                    context += " · \(weekLabel(week))"
                    date = AnkerCalendar.nominalDate(ofStored: week.monday)
                }
            } else {
                context = String(localized: "Eingang · Prio \(task.priority.label)")
            }
            results.append(
                Result(
                    id: task.id,
                    kind: .task,
                    title: task.title,
                    context: context,
                    isDone: task.isDone,
                    dayID: nil,
                    goalID: task.linkedGoal?.id,
                    date: date
                )
            )
        }

        // Neueste zuerst innerhalb einer Art: gesucht wird meist nach etwas Kürzlichem.
        results.sort {
            if $0.kind.sortRank != $1.kind.sortRank {
                return $0.kind.sortRank < $1.kind.sortRank
            }
            if $0.date != $1.date {
                return $0.date > $1.date
            }
            return $0.title.localizedCompare($1.title) == .orderedAscending
        }

        return Array(results.prefix(limit))
    }

    /// Diakritika und Groß-/Kleinschreibung ignorieren: wer nach "prufung" sucht, meint
    /// "Prüfung" und soll es finden.
    static func matches(_ text: String, _ needle: String) -> Bool {
        guard !text.isEmpty else { return false }
        return text.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// Notizen können lang sein. In der Liste steht deshalb nur die Umgebung der Fundstelle,
    /// sonst wäre nicht erkennbar, warum der Treffer ein Treffer ist.
    static func snippet(of text: String, around needle: String, radius: Int = 34) -> String {
        let flattened = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let range = flattened.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(flattened.prefix(radius * 2))
        }

        let start = flattened.index(range.lowerBound, offsetBy: -radius, limitedBy: flattened.startIndex)
            ?? flattened.startIndex
        let end = flattened.index(range.upperBound, offsetBy: radius, limitedBy: flattened.endIndex)
            ?? flattened.endIndex

        var result = String(flattened[start..<end])
        if start != flattened.startIndex { result = "… " + result }
        if end != flattened.endIndex { result += " …" }
        return result
    }

    /// Stabile, vom Tag abgeleitete Kennung für Notiz-Treffer.
    private static func noteResultID(for day: Day) -> UUID {
        var bytes = day.id.uuid
        // Ein Bit kippen reicht: die Kennung muss nur innerhalb einer Ergebnisliste
        // eindeutig sein, nicht global.
        bytes.15 ^= 0x01
        return UUID(uuid: bytes)
    }
}

/// Ergebnisliste, geteilt zwischen Sidebar (Mac, iPad) und Suchblatt (iPhone).
struct SearchResultsList: View {
    let query: String
    let results: [AnkerSearch.Result]
    var onSelect: (AnkerSearch.Result) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                hint("Mindestens zwei Zeichen eingeben.")
            } else if results.isEmpty {
                hint("Keine Treffer in Aufgaben, Ankern, Notizen oder Zeitblöcken.")
            } else {
                // "Treffer" ist im Deutschen im Singular und Plural gleich — keine Pluralregel nötig.
                Text("\(results.count) Treffer")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .padding(.horizontal, AnkerSpacing.s3)

                ForEach(results) { result in
                    Button {
                        onSelect(result)
                    } label: {
                        row(result)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func hint(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s2)
    }

    private func row(_ result: AnkerSearch.Result) -> some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s2) {
            Image(result.kind.icon)
                .ankerIcon(AnkerIconSize.xs)
                .foregroundStyle(AnkerColor.accentInk)
                .padding(.top, 1)  // optische Ausrichtung, kein Raster. design-guard: erlaubt

            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(result.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .strikethrough(result.isDone, color: AnkerColor.inkSecond)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(verbatim: "\(result.kind.title) · \(result.context)")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            result.isDone
                ? Text("\(result.kind.title): \(result.title), \(result.context), erledigt")
                : Text(verbatim: "\(result.kind.title): \(result.title), \(result.context)")
        )
        .accessibilityAddTraits(.isButton)
    }
}

/// Suche auf dem iPhone. Dort gibt es keine Sidebar, in der ein Suchfeld stehen könnte —
/// erreichbar über die Lupe in der Navigationsleiste.
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let weeks: [Week]
    var onSelect: (AnkerSearch.Result) -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                SearchResultsList(query: query, results: AnkerSearch.results(for: query, in: weeks, modelContext: modelContext)) { result in
                    onSelect(result)
                    dismiss()
                }
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s3)
            }
            .background(AnkerColor.ground)
            .searchable(text: $query, prompt: "Anker, Aufgaben, Notizen")
            .ankerSheetChrome("Suchen", cancel: AnkerSheetAction("Fertig") { dismiss() })
        }
    }
}
