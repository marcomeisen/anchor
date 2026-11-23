import SwiftData
import SwiftUI

/// Sonntag: Wie lief die Woche?
///
/// Pro Anker eine ehrliche Antwort — gehalten, teilweise, nicht. Die Zahl daneben ist ein
/// Hinweis, die Antwort gibt der Mensch: „1 von 2" kann trotzdem gehalten sein. Danach pro
/// offener Aufgabe: mitnehmen oder loslassen. Nichts wandert stillschweigend.
struct ReviewScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Week.monday) private var weeks: [Week]
    @Query(filter: #Predicate<AnkerTask> { $0.day == nil && $0.linkedGoal == nil }) private var inbox: [AnkerTask]

    let weekStart: Date
    var onClosed: () -> Void = {}

    @State private var dropped: Set<UUID> = []
    @State private var reflection = ""
    @State private var didLoad = false
    @State private var reflectionCommit: Task<Void, Never>?
    @State private var confirmingClose = false
    @State private var showingWeekStart = false

    /// Was beim Abschließen mit den offenen Aufgaben geschieht — vorher genannt, nicht danach.
    private struct CloseSummary {
        var carried = 0
        var toInbox = 0
        var deleted = 0
        var targetWeek = 0

        var sentence: String? {
            var parts: [String] = []
            if carried > 0 { parts.append("\(carried) \(carried == 1 ? "wandert" : "wandern") in \(AnkerDateFormat.calendarWeek(targetWeek))") }
            if toInbox > 0 { parts.append("\(toInbox) \(toInbox == 1 ? "geht" : "gehen") in den Eingang") }
            if deleted > 0 { parts.append("\(deleted) \(deleted == 1 ? "wird" : "werden") gelöscht") }
            guard !parts.isEmpty else { return nil }
            return parts.joined(separator: ", ") + "."
        }
    }

    var body: some View {
        let sheet = WeekSheet(monday: weekStart, weeks: weeks, inbox: inbox)
        let lanes = sheet.anchorLanes
        let open = WeekActions.openTasks(in: sheet)
        let answered = lanes.filter { $0.goal?.verdict != nil }.count
        let held = lanes.filter { $0.goal?.verdict == .held }.count
        // Ohne Anker gibt es nichts zu beantworten — die Woche lässt sich trotzdem schließen.
        let allAnswered = answered == lanes.count
        let summary = summary(for: open, sheet: sheet)

        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
#if os(macOS)
                HStack {
                    Spacer()
                    Button("Abbrechen") { dismiss() }
                        .buttonStyle(AnkerButtonStyle.quiet)
                        .keyboardShortcut(.cancelAction)
                }
#endif
                BlattHeading(
                    eyebrow: "\(AnkerDateFormat.calendarWeek(sheet.isoWeek)) · \(AnkerDateFormat.weekSpan(monday: sheet.monday, sunday: AnkerCalendar.iso.date(byAdding: .day, value: 6, to: sheet.monday) ?? sheet.monday))",
                    title: lanes.isEmpty ? "Wie lief die Woche?"
                        : (allAnswered ? "\(held) von \(lanes.count) gehalten." : "Wie lief die Woche?"),
                    titleStyle: AnkerType.title1
                )

                if lanes.isEmpty {
                    emptyState
                } else {
                    Text("Die Zahlen sind ein Hinweis. Die Antwort gibst du.")
                        .ankerType(AnkerType.body)
                        .foregroundStyle(AnkerColor.inkSecond)

                    VStack(spacing: 0) {
                        ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                            if index > 0 { AnkerRule(weight: .row) }
                            if let goal = lane.goal {
                                verdictRow(lane: lane, goal: goal)
                            }
                        }
                    }
                    .ankerCard()
                }

                if !open.isEmpty {
                    VStack(spacing: 0) {
                        BlattSectionLabel(title: "Offen geblieben")
                            .padding(.horizontal, AnkerSpacing.s3)
                            .padding(.top, AnkerSpacing.s3)
                            .padding(.bottom, AnkerSpacing.s2)
                        ForEach(open) { task in
                            AnkerRule(weight: .row)
                            carryRow(task, number: sheet.anchorNumber(of: task))
                        }
                    }
                    .ankerCard()
                }

                if let week = sheet.week {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                        Text("Was hat diese Woche getragen?")
                            .ankerType(AnkerType.bodyStrong)
                            .foregroundStyle(AnkerColor.ink)
                        TextField("Ein Satz genügt", text: $reflection, axis: .vertical)
                            .textFieldStyle(.plain)
                            .ankerType(AnkerType.body)
                            .lineLimit(1...4)
                            .padding(AnkerSpacing.s3)
                            .ankerField()
                            .onChange(of: reflection) { _, _ in scheduleReflectionCommit() }
                    }

                    if let sentence = summary.sentence, !week.isReviewed {
                        Text(verbatim: "Beim Abschließen: \(sentence)")
                            .ankerType(AnkerType.meta)
                            .foregroundStyle(AnkerColor.inkSecond)
                            .accessibilityIdentifier("reviewCloseSummary")
                    }

                    Button("Woche abschließen") {
                        if summary.deleted > 0 {
                            confirmingClose = true
                        } else {
                            close(open: open)
                        }
                    }
                    .buttonStyle(AnkerButtonStyle.primaryBlock)
                    .disabled(!allAnswered)
                    .opacity(allAnswered ? 1 : 0.4)
                    .confirmationDialog(
                        "Woche abschließen?",
                        isPresented: $confirmingClose,
                        titleVisibility: .visible
                    ) {
                        Button(summary.deleted == 1 ? "Abschließen und 1 Aufgabe löschen" : "Abschließen und \(summary.deleted) Aufgaben löschen", role: .destructive) {
                            close(open: open)
                        }
                        Button("Abbrechen", role: .cancel) {}
                    } message: {
                        Text(verbatim: "\(summary.sentence ?? "") Losgelassene Aufgaben lassen sich nicht wiederherstellen.")
                    }

                    if week.isReviewed {
                        Button("Woche wieder öffnen") {
                            WeekActions.reopen(week, modelContext: modelContext)
                        }
                        .buttonStyle(AnkerButtonStyle.quiet)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s4)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
#if os(iOS)
        .ankerSheetChrome("Rückblick", cancel: AnkerSheetAction("Abbrechen") { dismiss() })
#endif
        .onAppear {
            guard !didLoad else { return }
            reflection = sheet.week?.reflection ?? ""
            didLoad = true
        }
        .onDisappear(perform: commitReflectionNow)
        .sheet(isPresented: $showingWeekStart) {
            WeekStartScreen(weekStart: sheet.monday)
#if os(macOS)
                .frame(minWidth: 520, minHeight: 620)
#endif
        }
    }

    private func summary(for open: [AnkerTask], sheet: WeekSheet) -> CloseSummary {
        var summary = CloseSummary()
        let nextMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: sheet.monday) ?? sheet.monday
        summary.targetWeek = AnkerCalendar.weekInterval(containing: nextMonday).isoWeek
        for task in open {
            if dropped.contains(task.id) {
                summary.deleted += 1
            } else if task.day == nil {
                summary.toInbox += 1
            } else {
                summary.carried += 1
            }
        }
        return summary
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Für diese Woche sind keine Anker gesetzt.")
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
            Text("Ohne Anker gibt es nichts zu beantworten. Du kannst die Woche nachträglich setzen oder sie so abschließen.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.inkSecond)
            Button("Woche setzen") { showingWeekStart = true }
                .buttonStyle(AnkerButtonStyle.secondary)
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }

    private func verdictRow(lane: WeekSheet.Lane, goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s2) {
                Text(verbatim: lane.numberLabel)
                    .ankerType(AnkerType.subheadline)
                    .monospacedDigit()
                    .frame(width: 22, alignment: .leading)
                Text(verbatim: lane.title)
                    .ankerType(AnkerType.bodyStrong)
                Spacer()
                Text(verbatim: "\(lane.doneCount) von \(lane.tasks.count)")
                    .ankerType(AnkerType.caption)
                    .monospacedDigit()
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .foregroundStyle(AnkerColor.ink)

            HStack(spacing: AnkerSpacing.s1 + 2) {
                ForEach(GoalVerdict.allCases) { verdict in
                    let isOn = goal.verdict == verdict
                    Button {
                        goal.verdict = isOn ? nil : verdict
                        modelContext.saveChanges()
                    } label: {
                        Text(verdict.label)
                            .ankerType(AnkerType.label)
                            .foregroundStyle(isOn ? AnkerColor.onAccent : AnkerColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .ankerControl(fill: isOn ? AnkerColor.accentFill : AnkerColor.card, stroke: isOn ? nil : AnkerColor.divider)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityLabel("\(lane.title): \(verdict.label)")
                }
            }
            .padding(.leading, AnkerSpacing.s5 + AnkerSpacing.s1h)
        }
        .padding(AnkerSpacing.s3)
    }

    private enum Carry: Hashable { case keep, drop }

    private func carryRow(_ task: AnkerTask, number: Int?) -> some View {
        let keep = !dropped.contains(task.id)
        let choice = Binding<Carry>(
            get: { dropped.contains(task.id) ? .drop : .keep },
            set: { value in
                if value == .drop { dropped.insert(task.id) } else { dropped.remove(task.id) }
            }
        )
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: AnkerSpacing.s2) {
                carryTitle(task, number: number, keep: keep)
                Spacer(minLength: AnkerSpacing.s2)
                carryChoice(task, choice: choice)
                    .frame(width: 220)
            }
            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                carryTitle(task, number: number, keep: keep)
                carryChoice(task, choice: choice)
            }
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s2)
    }

    private func carryTitle(_ task: AnkerTask, number: Int?, keep: Bool) -> some View {
        HStack(spacing: AnkerSpacing.s2) {
            Text(verbatim: number.map(String.init) ?? "–")
                .ankerType(AnkerType.bodyStrong)
                .monospacedDigit()
                .foregroundStyle(number == nil ? AnkerColor.inkTertiary : AnkerColor.ink)
                .frame(width: 18)
            Text(verbatim: task.title)
                .ankerType(AnkerType.body)
                .foregroundStyle(keep ? AnkerColor.ink : AnkerColor.inkTertiary)
                .strikethrough(!keep)
                .lineLimit(2)
        }
    }

    private func carryChoice(_ task: AnkerTask, choice: Binding<Carry>) -> some View {
        AnkerSegmented(
            options: [(Carry.keep, "Mitnehmen"), (Carry.drop, "Loslassen")],
            selection: choice,
            accessibilityLabel: "\(task.title): mitnehmen oder loslassen"
        )
    }

    // MARK: - Sichern

    /// Der Satz wird beim Tippen gesichert, nicht erst beim Schließen — wer das Blatt wegwischt,
    /// verliert ihn sonst. Eine Woche entsteht dafür nicht: ohne Woche gibt es kein Feld.
    private func scheduleReflectionCommit() {
        guard didLoad else { return }
        reflectionCommit?.cancel()
        reflectionCommit = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            commitReflection()
        }
    }

    private func commitReflectionNow() {
        reflectionCommit?.cancel()
        reflectionCommit = nil
        commitReflection()
    }

    private func commitReflection() {
        guard didLoad,
              let week = WeekPlanning.week(startingAt: AnkerCalendar.weekInterval(containing: weekStart).monday, in: weeks)
        else { return }
        WeekActions.setReflection(reflection, in: week, modelContext: modelContext)
    }

    private func close(open: [AnkerTask]) {
        guard let week = WeekPlanning.week(startingAt: AnkerCalendar.weekInterval(containing: weekStart).monday, in: weeks) else { return }
        reflectionCommit?.cancel()
        WeekActions.setReflection(reflection, in: week, modelContext: modelContext)

        // Auch Aufgaben ohne Tag: `close` legt sie an einen gleichnamigen Anker der Folgewoche
        // oder sonst in den Eingang.
        var decisions: [UUID: WeekActions.CarryDecision] = [:]
        for task in open {
            decisions[task.id] = dropped.contains(task.id) ? .drop : .keep
        }
        WeekActions.close(week, decisions: decisions, fallback: nil, weeks: weeks, modelContext: modelContext)
        onClosed()
        dismiss()
    }
}
