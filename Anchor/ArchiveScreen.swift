import SwiftData
import SwiftUI

/// Was eine Woche im Rückblick über ihre Anker sagt — ohne View, deshalb testbar.
enum ArchiveSummary {
    enum Mark: Equatable { case held, partial, missed, unanswered, empty }

    /// Ein Strich pro Anker. Ohne Antwort zählt, ob alle Aufgaben erledigt sind — sonst bliebe
    /// jede Woche vor diesem Entwurf leer.
    @MainActor
    static func marks(for week: Week?) -> [Mark] {
        guard let week else { return [] }
        return GoalOrdering.anchors(in: week).map { goal in
            switch goal.verdict {
            case .held: .held
            case .partial: .partial
            case .missed: .missed
            case nil:
                goal.taskList.isEmpty ? .empty
                    : (goal.taskList.allSatisfy(\.isDone) ? .held : .unanswered)
            }
        }
    }

    /// Längste Folge abgeschlossener Wochen, in denen jeder Anker gehalten wurde.
    @MainActor
    static func longestHeldStreak(_ weeks: [Week]) -> Int {
        var best = 0, run = 0
        for week in weeks.sorted(by: { $0.monday < $1.monday }) {
            let marks = marks(for: week)
            if !marks.isEmpty && marks.allSatisfy({ $0 == .held }) {
                run += 1
                best = max(best, run)
            } else if !marks.isEmpty {
                run = 0
            }
        }
        return best
    }

    /// Der Anker, der immer wieder gesetzt wird und selten hält — die ehrlichste Aussage des
    /// Jahres. Ab drei Wochen, sonst ist es Zufall.
    @MainActor
    static func recurringMiss(_ weeks: [Week]) -> (title: String, set: Int, held: Int)? {
        var counts: [String: (title: String, set: Int, held: Int)] = [:]
        for week in weeks {
            for goal in GoalOrdering.anchors(in: week) {
                let key = goal.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                guard !key.isEmpty else { continue }
                var entry = counts[key] ?? (goal.title, 0, 0)
                entry.set += 1
                if goal.verdict == .held { entry.held += 1 }
                counts[key] = entry
            }
        }
        return counts.values
            .filter { $0.set >= 3 && Double($0.held) / Double($0.set) < 0.5 }
            .max { $0.set - $0.held < $1.set - $1.held }
    }
}

/// Archiv: das Jahr als Raster aus Wochen, darunter die vergangenen Wochen.
struct ArchiveScreen: View {
    @Query(sort: \Week.monday) private var weeks: [Week]

    var now: Date = Date()
    var onOpenWeek: (Date) -> Void

    private var isoYear: Int { AnkerCalendar.weekInterval(containing: now).isoYear }
    private var currentWeek: Int { AnkerCalendar.weekInterval(containing: now).isoWeek }

    var body: some View {
        let yearWeeks = weeks.filter { $0.isoYear == isoYear && !$0.isDeleted }
        let past = yearWeeks.filter { $0.isoWeek < currentWeek }
        let marks = past.flatMap { ArchiveSummary.marks(for: $0) }.filter { $0 != .empty }
        let held = marks.filter { $0 == .held }.count

        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                BlattHeading(
                    eyebrow: "Archiv \(isoYear)",
                    title: marks.isEmpty ? "Noch keine abgeschlossene Woche" : "\(held) von \(marks.count) Ankern gehalten",
                    titleStyle: AnkerType.title2
                )

                yearGrid(yearWeeks)

                VStack(spacing: 0) {
                    statRow("Längste Serie, alles gehalten", value: "\(ArchiveSummary.longestHeldStreak(past)) Wochen")
                    if let miss = ArchiveSummary.recurringMiss(past) {
                        AnkerRule(weight: .row)
                        statRow("Kommt immer wieder und hält selten",
                                value: "\(miss.title) · \(miss.set)× gesetzt, \(miss.held)× gehalten")
                    }
                }
                .ankerCard()

                let listed = yearWeeks.filter { $0.isoWeek < currentWeek || $0.isReviewed }.sorted { $0.monday > $1.monday }
                if !listed.isEmpty {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                        BlattSectionLabel(title: "Vergangene Wochen")
                        VStack(spacing: 0) {
                            ForEach(Array(listed.enumerated()), id: \.element.id) { index, week in
                                if index > 0 { AnkerRule(weight: .row) }
                                weekRow(week)
                            }
                        }
                        .ankerCard()
                    }
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
    }

    private func yearGrid(_ yearWeeks: [Week]) -> some View {
        let count = AnkerCalendar.weeksInISOYear(isoYear)
        let columns = Array(repeating: GridItem(.flexible(), spacing: AnkerSpacing.s1h), count: 6)
        return LazyVGrid(columns: columns, spacing: AnkerSpacing.s1h) {
            ForEach(1...count, id: \.self) { number in
                let week = yearWeeks.first { $0.isoWeek == number }
                let isCurrent = number == currentWeek
                let isFuture = number > currentWeek
                Button {
                    if let week { onOpenWeek(week.monday) }
                } label: {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                        Text(verbatim: "\(number)")
                            .ankerType(AnkerType.microLabel)
                            .monospacedDigit()
                            .foregroundStyle(isCurrent ? AnkerColor.accentInk : AnkerColor.inkSecond)
                        HStack(spacing: AnkerSpacing.s0) {
                            ForEach(Array(paddedMarks(week).enumerated()), id: \.offset) { _, mark in
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
                .accessibilityLabel(accessibility(number: number, week: week))
            }
        }
    }

    private func paddedMarks(_ week: Week?) -> [ArchiveSummary.Mark] {
        let marks = ArchiveSummary.marks(for: week)
        return marks + Array(repeating: .empty, count: max(0, 4 - marks.count))
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

    private func accessibility(number: Int, week: Week?) -> String {
        let marks = ArchiveSummary.marks(for: week)
        guard !marks.isEmpty else { return "KW \(number), keine Anker" }
        let held = marks.filter { $0 == .held }.count
        return "KW \(number), \(held) von \(marks.count) Ankern gehalten"
    }

    private func statRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            Text(verbatim: label)
                .ankerType(AnkerType.meta)
                .foregroundStyle(AnkerColor.inkSecond)
            Text(verbatim: value)
                .ankerType(AnkerType.subheadline)
                .foregroundStyle(AnkerColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AnkerSpacing.s4)
    }

    private func weekRow(_ week: Week) -> some View {
        let marks = ArchiveSummary.marks(for: week).filter { $0 != .empty }
        let held = marks.filter { $0 == .held }.count
        return Button { onOpenWeek(week.monday) } label: {
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
