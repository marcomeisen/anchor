import Foundation
import SwiftUI

/// Suche über Aufgaben, Wochenziele, Notizen und Zeitblöcke.
///
/// Bewusst als reine Funktion über die bereits geladenen Wochen statt als `FetchDescriptor`
/// mit `#Predicate`: gesucht wird auch in `Day.notes` und `Day.focusNote`, und die Treffer
/// brauchen ihren Kontext (Kalenderwoche, Tag, zugeordnetes Ziel) für die Anzeige und die
/// anschließende Navigation. Der Bestand ist klein — ein Jahr Nutzung sind rund 365 Tage.
enum AnkerSearch {
    enum Kind: String, Hashable {
        case task
        case goal
        case note
        case focus
        case timeBlock

        var title: String {
            switch self {
            case .task: "Aufgabe"
            case .goal: "Wochenziel"
            case .note: "Notiz"
            case .focus: "Tagesfokus"
            case .timeBlock: "Zeitblock"
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
        /// Tag zum Anspringen. Bei Wochenzielen leer.
        let dayID: UUID?
        let goalID: UUID?
        /// Für die Sortierung: Datum des Tages, bei Zielen der Montag der Woche.
        let date: Date
    }

    /// Leeres Ergebnis bei leerer Eingabe, statt alles zurückzugeben.
    static func results(for query: String, in weeks: [Week], limit: Int = 60) -> [Result] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard needle.count >= 2 else { return [] }

        var results: [Result] = []

        for week in weeks {
            let weekLabel = "\(AnkerDateFormat.calendarWeek(week.isoWeek)) · \(week.isoYear)"

            for goal in week.goalList where matches(goal.title, needle) {
                results.append(
                    Result(
                        id: goal.id,
                        kind: .goal,
                        title: goal.title,
                        context: weekLabel,
                        isDone: goal.progress >= 1,
                        dayID: nil,
                        goalID: goal.id,
                        date: week.monday
                    )
                )
            }

            if let reflection = week.reflection, matches(reflection, needle) {
                results.append(
                    Result(
                        id: week.id,
                        kind: .note,
                        title: snippet(of: reflection, around: needle),
                        context: "Rückblick · \(weekLabel)",
                        isDone: false,
                        dayID: nil,
                        goalID: nil,
                        date: week.monday
                    )
                )
            }

            for day in week.dayList {
                let dayLabel = AnkerDateFormat.weekdayShortWithDayMonth(day.date)

                for task in day.taskList where matches(task.title, needle) {
                    var context = "\(dayLabel) · Prio \(task.priority.label)"
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
                            date: day.date
                        )
                    )
                }

                if let focus = day.focusNote, matches(focus, needle) {
                    results.append(
                        Result(
                            id: day.id,
                            kind: .focus,
                            title: snippet(of: focus, around: needle),
                            context: "\(dayLabel) · \(weekLabel)",
                            isDone: false,
                            dayID: day.id,
                            goalID: nil,
                            date: day.date
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
                            context: "\(dayLabel) · \(weekLabel)",
                            isDone: false,
                            dayID: day.id,
                            goalID: nil,
                            date: day.date
                        )
                    )
                }

                for block in day.timeBlockList where matches(block.title, needle) {
                    results.append(
                        Result(
                            id: block.id,
                            kind: .timeBlock,
                            title: block.title,
                            context: "\(dayLabel) · \(AnkerDateFormat.clock(block.startTime))",
                            isDone: false,
                            dayID: day.id,
                            goalID: nil,
                            date: day.date
                        )
                    )
                }
            }
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
                hint("Keine Treffer in Aufgaben, Zielen, Notizen oder Zeitblöcken.")
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

    private func hint(_ text: String) -> some View {
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

                Text("\(result.kind.title) · \(result.context)")
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
        .accessibilityLabel("\(result.kind.title): \(result.title), \(result.context)\(result.isDone ? ", erledigt" : "")")
        .accessibilityAddTraits(.isButton)
    }
}

/// Suche auf dem iPhone. Dort gibt es keine Sidebar, in der ein Suchfeld stehen könnte —
/// erreichbar über die Lupe in der Navigationsleiste.
struct SearchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let weeks: [Week]
    var onSelect: (AnkerSearch.Result) -> Void

    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                SearchResultsList(query: query, results: AnkerSearch.results(for: query, in: weeks)) { result in
                    onSelect(result)
                    dismiss()
                }
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s3)
            }
            .background(AnkerColor.ground)
            .searchable(text: $query, prompt: "Ziele, Aufgaben, Notizen")
            .ankerSheetChrome("Suchen", cancel: AnkerSheetAction("Fertig") { dismiss() })
        }
    }
}
