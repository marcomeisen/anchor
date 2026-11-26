import SwiftData
import SwiftUI

/// Was eine Woche im Rückblick über ihre Anker sagt — ohne View, deshalb testbar.
enum ArchiveSummary {
    enum Mark: Equatable { case held, partial, missed, unanswered, empty }

    typealias WeekKey = AnkerCalendar.WeekKey

    /// Ein Strich pro Anker. Ohne Antwort zählt, ob alle Aufgaben erledigt sind — sonst bliebe
    /// jede Woche vor diesem Entwurf leer.
    @MainActor
    static func marks(for week: Week?) -> [Mark] {
        guard let week else { return [] }
        return GoalOrdering.anchors(in: week).map(mark(for:))
    }

    /// Die Marke eines einzelnen Ankers — dieselbe Regel für Raster, Serie und `recurringMiss`.
    @MainActor
    static func mark(for goal: Goal) -> Mark {
        switch goal.verdict {
        case .held: .held
        case .partial: .partial
        case .missed: .missed
        case nil:
            goal.taskList.isEmpty ? .empty
                : (goal.taskList.allSatisfy(\.isDone) ? .held : .unanswered)
        }
    }

    /// Eine Woche pro ISO-Schlüssel. Vor dem Zusammenführen kann es zwei Kopien geben; es
    /// gilt dieselbe wie überall, die kleinste UUID.
    @MainActor
    static func weeksByKey(_ weeks: [Week]) -> [WeekKey: Week] {
        var result: [WeekKey: Week] = [:]
        for week in weeks where !week.isDeleted {
            let key = WeekKey(isoYear: week.isoYear, isoWeek: week.isoWeek)
            if let existing = result[key], existing.id.uuidString < week.id.uuidString { continue }
            result[key] = week
        }
        return result
    }

    /// Die Marken aller Wochen, **einmal** berechnet. Raster, Liste und Kennzahlen lesen daraus,
    /// statt `marks(for:)` pro Zelle und Zeile neu zu rechnen.
    @MainActor
    static func marksByKey(_ weeks: [Week]) -> [WeekKey: [Mark]] {
        weeksByKey(weeks).mapValues { marks(for: $0) }
    }

    /// Alle Anker gehalten — und es gab welche. Ein leerer Anker (keine Aufgabe, keine Antwort)
    /// zählt nicht mit: die Anzeige nennt „1/1", dann darf er auch die Serie nicht brechen.
    static func isAllHeld(_ marks: [Mark]) -> Bool {
        let counted = marks.filter { $0 != .empty }
        return !counted.isEmpty && counted.allSatisfy { $0 == .held }
    }

    /// Längste Folge **aufeinanderfolgender** Wochen, in denen jeder Anker gehalten wurde.
    ///
    /// Über die ISO-Schlüssel, nicht über die gespeicherten Wochen: eine Woche, die nicht im
    /// Store steht (nichts geplant), bricht die Serie genauso wie eine ohne Anker. Vorher
    /// liefen zwei gehaltene Wochen mit drei leeren Monaten dazwischen als Serie von zwei.
    /// Auf KW 52/53 folgt KW 1 des nächsten Jahres.
    @MainActor
    static func longestHeldStreak(_ weeks: [Week]) -> Int {
        longestHeldStreak(marks: marksByKey(weeks))
    }

    static func longestHeldStreak(marks: [WeekKey: [Mark]]) -> Int {
        var best = 0, run = 0
        var previous: WeekKey?
        for key in marks.keys.sorted() {
            guard isAllHeld(marks[key] ?? []) else {
                run = 0
                previous = key
                continue
            }
            run = (previous?.next == key) ? run + 1 : 1
            best = max(best, run)
            previous = key
        }
        return best
    }

    /// Der Anker, der immer wieder gesetzt wird und selten hält — die ehrlichste Aussage des
    /// Jahres. Ab drei Wochen, sonst ist es Zufall.
    ///
    /// „Gehalten" heißt dasselbe wie im Raster (`mark(for:)`), auch für Altbestand ohne
    /// Antwort. Bei Gleichstand: mehr Verfehlungen, dann öfter gesetzt, dann der Titel — auf
    /// jedem Gerät dieselbe Aussage, unabhängig von der Reihenfolge im Wörterbuch.
    @MainActor
    static func recurringMiss(_ weeks: [Week]) -> (title: String, set: Int, held: Int)? {
        var counts: [String: (title: String, set: Int, held: Int)] = [:]
        let ordered = weeksByKey(weeks).sorted { $0.key < $1.key }.map(\.value)
        for week in ordered {
            for goal in GoalOrdering.anchors(in: week) {
                let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
                let key = title.lowercased()
                guard !key.isEmpty, WeekPlanning.isUserCreated(goal) else { continue }
                var entry = counts[key] ?? (title, 0, 0)
                // Die jüngste Schreibweise gilt.
                entry.title = title
                entry.set += 1
                if mark(for: goal) == .held { entry.held += 1 }
                counts[key] = entry
            }
        }
        return counts.values
            .filter { $0.set >= 3 && Double($0.held) / Double($0.set) < 0.5 }
            .min { lhs, rhs in
                let lhsMiss = lhs.set - lhs.held, rhsMiss = rhs.set - rhs.held
                if lhsMiss != rhsMiss { return lhsMiss > rhsMiss }
                if lhs.set != rhs.set { return lhs.set > rhs.set }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    /// „1 Woche", „3 Wochen".
    static func weeksText(_ count: Int) -> String {
        count == 1 ? String(localized: "1 Woche") : String(localized: "\(count) Wochen")
    }
}

/// Archiv: das Jahr als Raster aus Wochen, darunter die vergangenen Wochen.
///
/// Das Raster zeigt ein Jahr, umschaltbar; Standard ist das laufende. Die Liste der
/// vergangenen Wochen und die Kennzahlen gehen über **alle** Jahre — vorher filterte alles auf
/// das ISO-Jahr von heute, und am 1. Januar war das Archiv leer.
struct ArchiveScreen: View {
    @Query(sort: \Week.monday) private var weeks: [Week]

    var now: Date = Date()
    var onOpenWeek: (Date) -> Void

    /// `nil` heißt das laufende Jahr.
    @State private var selectedYear: Int?

    private var currentKey: AnkerCalendar.WeekKey { AnkerCalendar.weekKey(containing: now) }
    private var isoYear: Int { selectedYear ?? currentKey.isoYear }

    var body: some View {
        let byKey = ArchiveSummary.weeksByKey(weeks)
        let marksByKey = byKey.mapValues { ArchiveSummary.marks(for: $0) }
        let currentKey = currentKey
        let pastKeys = byKey.keys.filter { $0 < currentKey }
        let pastMarks = marksByKey.filter { $0.key < currentKey }
        let yearMarks = pastKeys.filter { $0.isoYear == isoYear }
            .flatMap { marksByKey[$0] ?? [] }
            .filter { $0 != .empty }
        let held = yearMarks.filter { $0 == .held }.count
        let years = (byKey.keys.map(\.isoYear) + [currentKey.isoYear])
        let firstYear = years.min() ?? currentKey.isoYear
        let lastYear = years.max() ?? currentKey.isoYear

        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                BlattHeading(
                    eyebrow: String(localized: "Archiv \(String(isoYear))"),
                    title: yearMarks.isEmpty
                        ? String(localized: "Noch keine abgeschlossene Woche")
                        : String(localized: "\(held) von \(yearMarks.count) Ankern gehalten"),
                    titleStyle: AnkerType.title2
                )

                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    yearSwitcher(first: firstYear, last: lastYear)
                    yearGrid(byKey: byKey, marksByKey: marksByKey)
                    legend
                }

                VStack(spacing: 0) {
                    statRow("Längste Serie, alles gehalten",
                            value: ArchiveSummary.weeksText(ArchiveSummary.longestHeldStreak(marks: pastMarks)))
                    if let miss = ArchiveSummary.recurringMiss(pastKeys.compactMap { byKey[$0] }) {
                        AnkerRule(weight: .row)
                        statRow("Kommt immer wieder und hält selten",
                                value: String(localized: "\(miss.title) · \(miss.set)× gesetzt, \(miss.held)× gehalten"))
                    }
                }
                .ankerCard()

                pastWeeks(byKey: byKey, marksByKey: marksByKey)
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
    }

    // MARK: - Jahr

    private func yearSwitcher(first: Int, last: Int) -> some View {
        HStack(spacing: AnkerSpacing.s1) {
            if isoYear > first {
                BlattIconButton(icon: .chevronLeft, label: "Vorheriges Jahr") { selectedYear = isoYear - 1 }
            } else {
                Color.clear.frame(width: 40, height: 40).accessibilityHidden(true)
            }
            Text(verbatim: "\(isoYear)")
                .ankerType(AnkerType.bodyStrong)
                .monospacedDigit()
                .foregroundStyle(AnkerColor.ink)
                .accessibilityLabel("Jahr \(String(isoYear))")
            if isoYear < last {
                BlattIconButton(icon: .chevronRight, label: "Nächstes Jahr") { selectedYear = isoYear + 1 }
            } else {
                Color.clear.frame(width: 40, height: 40).accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            if isoYear != currentKey.isoYear {
                Button("Dieses Jahr") { selectedYear = nil }
                    .ankerType(AnkerType.label)
                    .foregroundStyle(AnkerColor.accentInk)
                    .buttonStyle(.plain)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: AnkerSpacing.s3) {
            legendItem(.held, "Gehalten")
            legendItem(.partial, "Teilweise")
            legendItem(.missed, "Nicht")
            legendItem(.unanswered, "Offen")
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func legendItem(_ mark: ArchiveSummary.Mark, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: AnkerSpacing.s1) {
            RoundedRectangle(cornerRadius: AnkerRadius.mark, style: .continuous)
                .fill(color(mark, isFuture: false))
                .frame(width: 12, height: 8)
            Text(title)
                .ankerType(AnkerType.meta)
                .foregroundStyle(AnkerColor.inkSecond)
        }
    }

    private func yearGrid(
        byKey: [AnkerCalendar.WeekKey: Week],
        marksByKey: [AnkerCalendar.WeekKey: [ArchiveSummary.Mark]]
    ) -> some View {
        let count = AnkerCalendar.weeksInISOYear(isoYear)
        let columns = Array(repeating: GridItem(.flexible(), spacing: AnkerSpacing.s1h), count: 6)
        let currentKey = currentKey
        return LazyVGrid(columns: columns, spacing: AnkerSpacing.s1h) {
            ForEach(1...count, id: \.self) { number in
                let key = AnkerCalendar.WeekKey(isoYear: isoYear, isoWeek: number)
                let week = byKey[key]
                let marks = marksByKey[key] ?? []
                let isCurrent = key == currentKey
                let isFuture = key > currentKey
                Button {
                    if let week { onOpenWeek(week.nominalMonday) }
                } label: {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                        Text(verbatim: "\(number)")
                            .ankerType(AnkerType.microLabel)
                            .monospacedDigit()
                            .foregroundStyle(isCurrent ? AnkerColor.accentInk : AnkerColor.inkSecond)
                        HStack(spacing: AnkerSpacing.s0) {
                            ForEach(Array(paddedMarks(marks).enumerated()), id: \.offset) { _, mark in
                                RoundedRectangle(cornerRadius: AnkerRadius.mark, style: .continuous)
                                    .fill(color(mark, isFuture: isFuture))
                                    .frame(height: 8)
                            }
                        }
                    }
                    .padding(AnkerSpacing.s1h)
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .topLeading)
                    .background(isCurrent ? AnkerColor.accentTint : (isFuture ? Color.clear : AnkerColor.card),
                                in: RoundedRectangle(cornerRadius: AnkerRadius.cell, style: .continuous))
                    .overlay {
                        if isCurrent {
                            RoundedRectangle(cornerRadius: AnkerRadius.cell, style: .continuous).strokeBorder(AnkerColor.accentMark, lineWidth: 1.5)
                        } else if isFuture {
                            RoundedRectangle(cornerRadius: AnkerRadius.cell, style: .continuous)
                                .strokeBorder(AnkerColor.divider, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(week == nil)
                .accessibilityLabel(accessibility(number: number, marks: marks))
            }
        }
    }

    // MARK: - Vergangene Wochen

    /// Über alle Jahre, neueste zuerst, nach Jahr gruppiert.
    @ViewBuilder
    private func pastWeeks(
        byKey: [AnkerCalendar.WeekKey: Week],
        marksByKey: [AnkerCalendar.WeekKey: [ArchiveSummary.Mark]]
    ) -> some View {
        let currentKey = currentKey
        let listed = byKey
            .filter { $0.key < currentKey || $0.value.isReviewed }
            .sorted { $0.key > $1.key }
        let groups = Dictionary(grouping: listed, by: \.key.isoYear)
        let years = groups.keys.sorted(by: >)

        if !listed.isEmpty {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                ForEach(years, id: \.self) { year in
                    let entries = groups[year] ?? []
                    VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                        BlattSectionLabel(title: years.count > 1 ? String(localized: "Vergangene Wochen \(String(year))") : String(localized: "Vergangene Wochen"),
                                          trailing: ArchiveSummary.weeksText(entries.count))
                        VStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.value.id) { index, entry in
                                if index > 0 { AnkerRule(weight: .row) }
                                weekRow(entry.value, marks: marksByKey[entry.key] ?? [])
                            }
                        }
                        .ankerCard()
                    }
                }
            }
        }
    }

    private func paddedMarks(_ marks: [ArchiveSummary.Mark]) -> [ArchiveSummary.Mark] {
        marks + Array(repeating: .empty, count: max(0, GoalOrdering.maxAnchors - marks.count))
    }

    private func color(_ mark: ArchiveSummary.Mark, isFuture: Bool) -> Color {
        switch mark {
        case .held: AnkerColor.accentFill
        case .partial: AnkerColor.accent[400]
        case .missed: AnkerColor.neutral[400]
        case .unanswered: AnkerColor.neutral[300]
        case .empty: isFuture ? Color.clear : AnkerColor.surface
        }
    }

    private func accessibility(number: Int, marks: [ArchiveSummary.Mark]) -> String {
        let week = AnkerDateFormat.calendarWeek(number)
        guard !marks.isEmpty else { return String(localized: "\(week), keine Anker") }
        let held = marks.filter { $0 == .held }.count
        return String(localized: "\(week), \(held) von \(marks.count) Ankern gehalten")
    }

    private func statRow(_ label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            Text(label)
                .ankerType(AnkerType.meta)
                .foregroundStyle(AnkerColor.inkSecond)
            Text(verbatim: value)
                .ankerType(AnkerType.subheadline)
                .foregroundStyle(AnkerColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s4)
    }

    private func weekRow(_ week: Week, marks allMarks: [ArchiveSummary.Mark]) -> some View {
        let marks = allMarks.filter { $0 != .empty }
        let held = marks.filter { $0 == .held }.count
        return Button { onOpenWeek(week.nominalMonday) } label: {
            HStack(spacing: AnkerSpacing.s3) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s0) {
                    Text(verbatim: AnkerDateFormat.calendarWeek(week.isoWeek))
                        .ankerType(AnkerType.bodyStrong)
                    Text(verbatim: GoalOrdering.anchors(in: week).map(\.title).joined(separator: " · "))
                        .ankerType(AnkerType.meta)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .lineLimit(1)
                }
                Spacer()
                Text(verbatim: marks.isEmpty ? "–" : "\(held)/\(marks.count)")
                    .ankerType(AnkerType.numeric)
                    .foregroundStyle(AnkerColor.ink)
                Image(.chevronRight).ankerIcon(AnkerIconSize.xs).foregroundStyle(AnkerColor.inkTertiary)
            }
            .foregroundStyle(AnkerColor.ink)
            .padding(AnkerSpacing.s4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
