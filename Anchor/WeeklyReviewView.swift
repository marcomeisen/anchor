import SwiftData
import SwiftUI

/// Der Wochenrückblick als Plakat.
///
/// Der Entwurf begründet das so: statt einer Liste mit Häkchen eine Zahl, eine Serie, das eine
/// nicht gehaltene Ziel mit seinem Übertrag, eine Frage. **Rot als Fläche — die einzige Stelle
/// in der App, die so laut ist.**
///
/// Die Antwort landet in `Week.reflection` und überlebt damit den Bildschirmwechsel; vorher war
/// sie `@State` und beim Verlassen weg.
struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let week: Week

    @State private var draft = ""
    @State private var showingSettings = false
    @State private var confirmingDrop = false
    @FocusState private var isEditing: Bool

    /// Die Entscheidung je offener Aufgabe. Was nicht darin steht, wandert mit.
    @State private var decisions: [UUID: WeekActions.CarryDecision] = [:]

    private var report: AnkerStatistics.WeekReport {
        AnkerStatistics.week(week)
    }

    private var streak: AnkerStatistics.Streak {
        AnkerStatistics.streak(in: weeks)
    }

    private var openTasks: [AnkerTask] {
        week.dayList
            .sorted { $0.date < $1.date }
            .flatMap { $0.taskList.filter { !$0.isDone } }
    }

    /// Die Anker der **Folgewoche** — dorthin wandert der Übertrag, und ein Anker gehört genau
    /// einer Woche. Gibt es die Woche noch nicht, ist die Liste leer und „neu verankern" sagt das.
    private var targetAnchors: [Goal] {
        guard let nextMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday),
              let next = weeks.first(where: { AnkerCalendar.isSameDay($0.monday, nextMonday) }) else {
            return []
        }
        return GoalOrdering.anchors(in: next).filter(WeekPlanning.isUserCreated)
    }

    private func decision(for task: AnkerTask) -> WeekActions.CarryDecision {
        decisions[task.id] ?? .keep
    }

    private var tally: (kept: Int, dropped: Int) {
        let open = openTasks
        let dropped = open.filter { decision(for: $0) == .drop }.count
        return (open.count - dropped, dropped)
    }

    var body: some View {
        let report = self.report

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                poster(report)
                question
                carrySection
                actions(report)
                appSection
            }
        }
        .background(AnkerColor.ground)
        .navigationTitle("Wochenrückblick")
        .task(id: week.id) {
            draft = week.reflection ?? ""
        }
        // Ein Speichervorgang pro Tippppause statt pro Zeichen: `task(id:)` bricht bei jeder
        // Aenderung ab und faengt neu an. Ueber CloudKit ist das der Unterschied zwischen
        // einem Export und hundert.
        .task(id: draft) {
            guard draft != (week.reflection ?? "") else { return }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            WeekActions.setReflection(draft, in: week, modelContext: modelContext)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        // Der Dialog kommt nur, wenn etwas **gelöscht** wird. Ein Übertrag ist umkehrbar, eine
        // gestrichene Aufgabe nicht — nur dafür lohnt die Rückfrage.
        .confirmationDialog("Aufgaben streichen?", isPresented: $confirmingDrop, titleVisibility: .visible) {
            Button("Streichen und schließen", role: .destructive) { close() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(dropMessage)
        }
    }

    // MARK: - Plakat

    private func poster(_ report: AnkerStatistics.WeekReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Rückblick · \(AnkerDateFormat.calendarWeek(week.isoWeek))")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.accent[300])
                .padding(.bottom, AnkerSpacing.s3)

            AnkerRule(color: AnkerColor.onAccent)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: "\(report.inMotionCount)")
                    .ankerType(AnkerType.poster)
                    .foregroundStyle(AnkerColor.onAccent)
                Text(verbatim: "/\(report.anchorCount)")
                    .ankerType(AnkerType.poster)
                    .foregroundStyle(AnkerColor.accent[300])
            }
            .padding(.top, AnkerSpacing.s5)

            Text(verbatim: posterHeadline(report))
                .ankerType(AnkerType.title2)
                .foregroundStyle(AnkerColor.onAccent)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AnkerSpacing.s3)
                .padding(.bottom, AnkerSpacing.s5)

            missedSection(report)
        }
        .padding(AnkerSpacing.s5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnkerColor.accentMark)
        .accessibilityIdentifier("reviewPoster")
    }

    private func posterHeadline(_ report: AnkerStatistics.WeekReport) -> String {
        guard report.anchorCount > 0 else { return "Diese Woche hatte keine Anker." }

        var text = report.inMotionCount == report.anchorCount
            ? "Anker gehalten."
            : "Anker in Bewegung."
        if streak.weeks > 1 {
            text += " \(streak.weeks). Woche in Folge."
        }
        return text
    }

    /// Der nicht gehaltene Anker mit seinem Übertrag — benannt, nicht stillschweigend verschoben.
    @ViewBuilder
    private func missedSection(_ report: AnkerStatistics.WeekReport) -> some View {
        if let missed = report.firstMissedAnchor {
            AnkerRule(color: AnkerColor.onAccent)

            Text(verbatim: "Nicht gehalten")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.accent[300])
                .padding(.top, AnkerSpacing.s4)
                .padding(.bottom, AnkerSpacing.s3)

            HStack(alignment: .top, spacing: AnkerSpacing.s3) {
                Text(verbatim: "\(missed.number)")
                    .ankerType(AnkerType.subheadline)
                    .foregroundStyle(AnkerColor.onAccent)

                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(verbatim: missed.title)
                        .ankerType(AnkerType.bodyStrong)
                        .foregroundStyle(AnkerColor.onAccent)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verbatim: carryText(for: missed))
                        .ankerType(AnkerType.overline)
                        .foregroundStyle(AnkerColor.accent[300])
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func carryText(for anchor: AnkerStatistics.AnchorReport) -> String {
        let next = AnkerDateFormat.calendarWeek(
            AnkerCalendar.weekInterval(
                containing: AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday) ?? week.monday
            ).isoWeek
        )
        switch anchor.openCount {
        case 0: return "keine offene Aufgabe"
        case 1: return "1 Aufgabe wandert nach \(next)"
        default: return "\(anchor.openCount) Aufgaben wandern nach \(next)"
        }
    }

    // MARK: - Die eine Frage

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Eine Frage")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s5)
                .padding(.bottom, AnkerSpacing.s2)

            Text(verbatim: "Was hat dich diese Woche wirklich aufgehalten?")
                .ankerType(AnkerType.headline)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s3)

            TextEditor(text: $draft)
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(AnkerSpacing.s3)
                .ankerField()
                .focused($isEditing)
                .accessibilityLabel("Antwort auf die Wochenfrage")
                .accessibilityIdentifier("reviewAnswer")
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
    }

    // MARK: - Übertrag pro Aufgabe

    /// Der Kern der zweiten Runde: **jede** offene Aufgabe bekommt eine Entscheidung.
    ///
    /// Vorher gab es alles-oder-nichts in einem Dialog. Der Entwurf begründet den Wechsel so:
    /// „Nichts wandert stillschweigend — das war der Grund, warum die Übersicht sich fremd
    /// anfühlte." Wer nichts anfasst, überträgt; das steht auf dem Knopf.
    @ViewBuilder
    private var carrySection: some View {
        let open = openTasks

        if !open.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s3) {
                    Text(verbatim: "Übertrag")
                        .ankerType(AnkerType.eyebrow)
                        .foregroundStyle(AnkerColor.inkSecond)

                    Spacer(minLength: AnkerSpacing.s2)

                    Text(verbatim: "\(open.count) offen · Ziel \(nextWeekLabel)")
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(AnkerColor.inkTertiary)
                }
                .padding(.top, AnkerSpacing.s5)
                .padding(.bottom, AnkerSpacing.s2)

                AnkerRule(color: AnkerColor.ink)

                ForEach(open, id: \.id) { task in
                    CarryRow(
                        task: task,
                        decision: decision(for: task),
                        targetAnchors: targetAnchors,
                        nextWeekLabel: nextWeekLabel
                    ) { decision in
                        decisions[task.id] = decision
                    }
                    AnkerRule(weight: .row)
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
        }
    }

    // MARK: - Abschluss

    @ViewBuilder
    private func actions(_ report: AnkerStatistics.WeekReport) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            if report.isClosed {
                Text(verbatim: closedLabel)
                    .ankerType(AnkerType.overline)
                    .foregroundStyle(AnkerColor.inkSecond)

                Button("Wieder öffnen") {
                    WeekActions.reopen(week, modelContext: modelContext)
                }
                .buttonStyle(AnkerButtonStyle.secondary)
            } else {
                Button(closeLabel) {
                    if tally.dropped > 0 {
                        confirmingDrop = true
                    } else {
                        close()
                    }
                }
                .buttonStyle(AnkerButtonStyle.primaryBlock)
                .accessibilityIdentifier("closeWeek")
            }

            if report.carriedInTaskCount > 0 {
                Text(verbatim: "\(report.carriedInTaskCount) Aufgaben kamen aus einer früheren Woche.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.top, AnkerSpacing.s5)
    }

    private var closedLabel: String {
        guard let date = week.reviewedAt else { return "Woche geschlossen" }
        return "Woche geschlossen · \(AnkerDateFormat.dayMonth(date))"
    }

    private var nextWeekLabel: String {
        AnkerDateFormat.calendarWeek(
            AnkerCalendar.weekInterval(
                containing: AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday) ?? week.monday
            ).isoWeek
        )
    }

    /// Der Knopf nennt, was passiert. Das ist der Ersatz für den alten Dialog: „Nichts wandert
    /// stillschweigend" heißt nicht zwingend nachfragen, sondern vorher benennen.
    private var closeLabel: String {
        let tally = self.tally
        switch (tally.kept, tally.dropped) {
        case (0, 0): return "Woche schließen"
        case (let kept, 0): return "Schließen · \(kept) nach \(nextWeekLabel)"
        case (0, let dropped): return "Schließen · \(dropped) streichen"
        case (let kept, let dropped): return "Schließen · \(kept) übertragen, \(dropped) streichen"
        }
    }

    private var dropMessage: String {
        let tally = self.tally
        let dropped = tally.dropped == 1
            ? "1 Aufgabe wird gelöscht"
            : "\(tally.dropped) Aufgaben werden gelöscht"
        guard tally.kept > 0 else { return "\(dropped). Das lässt sich nicht zurücknehmen." }
        return "\(dropped), \(tally.kept) wandern nach \(nextWeekLabel). Das Löschen lässt sich nicht zurücknehmen."
    }

    private func close() {
        WeekActions.close(week, decisions: decisions, weeks: weeks, modelContext: modelContext)
        decisions = [:]
    }

    // MARK: - App

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnkerRule(color: AnkerColor.ink)
                .padding(.top, AnkerSpacing.s5)

            Button {
                showingSettings = true
            } label: {
                HStack(spacing: AnkerSpacing.s3) {
                    Image(.settings).ankerIcon(AnkerIconSize.s)
                        .foregroundStyle(AnkerColor.accentInk)
                    VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                        Text(verbatim: "Einstellungen")
                            .ankerType(AnkerType.bodyStrong)
                            .foregroundStyle(AnkerColor.ink)
                        Text(verbatim: "Erscheinungsbild, iCloud-Sync, Daten")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                    }
                    Spacer(minLength: 0)
                    Image(.chevronRight).ankerIcon(AnkerIconSize.xs)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                .padding(.vertical, AnkerSpacing.s4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Einstellungen öffnen")
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.bottom, AnkerSpacing.s6)
    }
}

/// Eine offene Aufgabe mit ihrer Entscheidung.
///
/// Drei Zustände, einer davon mit Nutzlast — deshalb keine Segmentleiste aus drei gleichen
/// Knöpfen, sondern zwei Knöpfe und ein Menü. „Neu verankern" braucht das Ziel.
private struct CarryRow: View {
    let task: AnkerTask
    let decision: WeekActions.CarryDecision
    let targetAnchors: [Goal]
    let nextWeekLabel: String
    let onChange: (WeekActions.CarryDecision) -> Void

    private var isDropped: Bool { decision == .drop }

    private var reanchorTarget: Goal? {
        guard case .reanchor(let goalID) = decision, let goalID else { return nil }
        return targetAnchors.first { $0.id == goalID }
    }

    private var isReanchored: Bool {
        if case .reanchor = decision { return true }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s3) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(verbatim: task.title)
                    .ankerType(AnkerType.taskTitle)
                    .foregroundStyle(isDropped ? AnkerColor.inkTertiary : AnkerColor.ink)
                    .strikethrough(isDropped, color: AnkerColor.inkTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verbatim: metaLine)
                    .ankerType(AnkerType.overline)
                    .foregroundStyle(isReanchored ? AnkerColor.accentInk : AnkerColor.inkSecond)
            }

            Spacer(minLength: AnkerSpacing.s2)

            HStack(spacing: 0) {
                choiceButton("Behalten", isActive: decision == .keep) { onChange(.keep) }
                AnkerRule(axis: .vertical)
                choiceButton("Streichen", isActive: isDropped) { onChange(.drop) }
                AnkerRule(axis: .vertical)
                reanchorMenu
            }
            .fixedSize()
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous).stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule))
        }
        .padding(.vertical, AnkerSpacing.s3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(task.title), \(metaLine)")
        .accessibilityIdentifier("carryRow.\(task.title)")
    }

    private var metaLine: String {
        if isDropped { return "wird gestrichen" }
        if case .reanchor(let goalID) = decision {
            guard let goalID else { return "nach \(nextWeekLabel), ohne Anker" }
            let title = targetAnchors.first { $0.id == goalID }?.title ?? "unbekannter Anker"
            return "nach \(nextWeekLabel) an \(title)"
        }
        let anchor = task.linkedGoal?.title
        let day = task.day.map { AnkerDateFormat.weekdayShort($0.date) } ?? "—"
        return anchor.map { "\($0) · \(day) · nach \(nextWeekLabel)" } ?? "Ohne Anker · \(day) · nach \(nextWeekLabel)"
    }

    private func choiceButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(isActive ? AnkerColor.onAccent : AnkerColor.ink)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s2)
                .background(isActive ? AnkerColor.accentFill : Color.clear, in: Rectangle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var reanchorMenu: some View {
        Menu {
            if targetAnchors.isEmpty {
                // Ehrlich statt leer: die Folgewoche existiert noch nicht oder hat keine Anker.
                // Die Aufgabe wandert dann ohne Anker — ein Anker gehört genau einer Woche.
                Text("\(nextWeekLabel) hat noch keine Anker")
            } else {
                ForEach(targetAnchors, id: \.id) { goal in
                    Button(goal.title) { onChange(.reanchor(goalID: goal.id)) }
                }
            }
            Divider()
            Button("Ohne Anker") { onChange(.reanchor(goalID: nil)) }
        } label: {
            Text(verbatim: reanchorTarget == nil ? "Verankern" : "Anker ✓")
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(isReanchored ? AnkerColor.onAccent : AnkerColor.ink)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s2)
                .background(isReanchored ? AnkerColor.accentFill : Color.clear, in: Rectangle())
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Neu verankern")
    }
}
