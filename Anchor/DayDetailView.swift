import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Detailansicht eines einzelnen Tages.
///
/// Bis hierher fuehrte ein Klick auf einen Tag nur dazu, dass er in der Wochenuebersicht
/// hervorgehoben wurde. Diese Ansicht zeigt den Tag stattdessen vollstaendig: Kennzahlen,
/// Tagesfokus, betroffene Wochenziele, Zeitplan, Aufgaben nach Prioritaet und freie Notizen.
/// `focusNote` und `notes` am `Day`-Modell waren bisher nirgends bearbeitbar.
struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Week.monday) private var weeks: [Week]

    @Bindable var day: Day
    let week: Week
    var onAddTask: () -> Void = {}
    var onSelectGoal: (Goal) -> Void = { _ in }
    var onClose: (() -> Void)?

    @StateObject private var undo = TaskUndoCoordinator()

    @State private var focusDraft = ""
    @State private var notesDraft = ""
    @State private var hasLoadedDrafts = false
    @State private var commitTask: Task<Void, Never>?
    @State private var isDropTargeted = false

    private var tasks: [AnkerTask] {
        day.taskList.sorted { $0.order < $1.order }
    }

    private var doneCount: Int {
        day.taskList.filter(\.isDone).count
    }

    private var openCount: Int {
        day.taskList.count - doneCount
    }

    private var progress: Double {
        day.taskList.isEmpty ? 0 : Double(doneCount) / Double(day.taskList.count)
    }

    private var linkedGoals: [Goal] {
        var seen = Set<UUID>()
        return day.taskList
            .compactMap(\.linkedGoal)
            .filter { seen.insert($0.id).inserted }
    }

    private var isToday: Bool {
        AnkerCalendar.isSameDay(day.date, Date())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    statsRow
                    focusSection
                    goalSection
                    scheduleSection
                    taskSection
                    notesSection
                }
                .padding(.horizontal, AnkerSpacing.screenPadding)
                .padding(.bottom, AnkerSpacing.bottomBarClearance)
            }
            .background(AnkerColor.ground)

            VStack(spacing: AnkerSpacing.s3) {
                if let notice = undo.notice {
                    TaskUndoToast(notice: notice) {
                        undo.undo(weeks: weeks, modelContext: modelContext)
                    }
                }
            }
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.bottom, AnkerSpacing.s4)
        }
        .navigationTitle(navigationTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear(perform: loadDraftsIfNeeded)
        .onDisappear(perform: commitNow)
        .onDrop(
            of: TaskDropHandling.draggedTypes,
            isTargeted: $isDropTargeted
        ) { providers in
            dropTask(from: providers)
        }
    }

    private var navigationTitle: String {
        let weekday = AnkerDateFormat.weekdayLong(day.date)
        return isToday ? "\(weekday) — Heute" : weekday
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            HStack(alignment: .top, spacing: AnkerSpacing.s3) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(headerMeta)
                        .ankerType(AnkerType.numericSmall)
                        .foregroundStyle(AnkerColor.inkSecond)

                    Text(AnkerDateFormat.weekdayLong(day.date))
                        .ankerType(AnkerType.headline)
                        .foregroundStyle(AnkerColor.ink)
                }

                Spacer(minLength: AnkerSpacing.s2)

                Text(verbatim: "\(Int(progress * 100))%")
                    .ankerType(AnkerType.statValue)
                    .foregroundStyle(AnkerColor.ink)
                    .accessibilityLabel("\(Int(progress * 100)) Prozent des Tages erledigt")
            }

            AnkerProgressBar(progress: progress, thickness: AnkerBorder.rule * 3)
                .padding(.top, AnkerSpacing.s2)

            if let onClose {
                Button(action: onClose) {
                    Label("Zur Wochenübersicht", ankerIcon: AnkerIcon.chevronLeft)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.accentInk)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück zur Wochenübersicht")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnkerSpacing.s4)
        .padding(.vertical, AnkerSpacing.s3)
        .ankerPanel()
        
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .stroke(AnkerColor.accentFill, lineWidth: 2)
            }
        }
        .padding(.top, AnkerSpacing.s3)
    }

    private var headerMeta: String {
        let date = AnkerDateFormat.dayMonthYear(day.date)
        return "\(date) · \(AnkerDateFormat.calendarWeek(week.isoWeek))"
    }

    // MARK: - Kennzahlen

    private var statsRow: some View {
        HStack(spacing: AnkerSpacing.s2) {
            statTile(value: openCount, label: "Offen", tint: AnkerColor.accentInk)
            statTile(value: doneCount, label: "Erledigt", tint: AnkerColor.ink)
            statTile(value: day.timeBlockList.count, label: "Zeitblöcke", tint: AnkerColor.neutral[500])
        }
        .padding(.top, AnkerSpacing.s4)
    }

    private func statTile(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            Text(verbatim: String(value))
                .ankerType(AnkerType.headline)
                .foregroundStyle(tint)
            Text(label)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s3)
        .background(AnkerColor.surface)
        .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
        .clipShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Tagesfokus

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Fokus des Tages")

            TextField("Worauf kommt es heute an?", text: $focusDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .ankerType(AnkerType.meta)
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s3)
                .background(AnkerColor.surface)
                .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
                .clipShape(Rectangle())
                .onChange(of: focusDraft) { _, _ in scheduleCommit() }
                .accessibilityLabel("Fokus des Tages")
        }
    }

    // MARK: - Wochenziele

    @ViewBuilder
    private var goalSection: some View {
        if !linkedGoals.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(title: "Verankerte Wochenziele")

                VStack(spacing: AnkerSpacing.s2) {
                    ForEach(linkedGoals, id: \.id) { goal in
                        goalRow(goal)
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let dayTasks = day.taskList.filter { $0.linkedGoal?.id == goal.id }
        let dayDone = dayTasks.filter(\.isDone).count

        return Button {
            onSelectGoal(goal)
        } label: {
            HStack(spacing: AnkerSpacing.s3) {
                Rectangle()
                    .fill(AnkerColor.goalTint(goal.colorHex))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(goal.title)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.ink)
                        .lineLimit(1)
                    Text("\(dayDone) von \(dayTasks.count) an diesem Tag")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                Spacer(minLength: AnkerSpacing.s2)

                Text(verbatim: "\(Int(goal.progress * 100))%")
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s3)
            .background(AnkerColor.surface)
            .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
            .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Ziel öffnen: \(goal.title)")
        .accessibilityLabel("Ziel \(goal.title), \(Int(goal.progress * 100)) Prozent erreicht, \(dayDone) von \(dayTasks.count) Aufgaben an diesem Tag erledigt")
    }

    // MARK: - Zeitplan

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Zeitplan")

            if day.timeBlockList.isEmpty {
                emptyHint("Für diesen Tag sind keine Zeitblöcke eingetragen.")
            } else {
                VStack(spacing: 0) {
                    ForEach(day.timeBlockList.sorted { $0.startTime < $1.startTime }, id: \.id) { block in
                        DayTimeBlockRow(block: block)
                    }
                }
            }
        }
    }

    // MARK: - Aufgaben

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                SectionLabel(title: "Aufgaben")
                Spacer(minLength: AnkerSpacing.s2)
                Button(action: onAddTask) {
                    Label("Neu", ankerIcon: AnkerIcon.add)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.accentInk)
                }
                .buttonStyle(.plain)
                .help("Neue Aufgabe für diesen Tag")
                .accessibilityLabel("Neue Aufgabe für diesen Tag erstellen")
                .padding(.bottom, AnkerSpacing.s2)
            }

            if tasks.isEmpty {
                emptyHint("Noch keine Aufgaben. Über den Neu-Button anlegen oder eine Aufgabe hierher ziehen.")
            } else {
                ForEach(Priority.allCases, id: \.self) { priority in
                    let priorityTasks = tasks.filter { $0.priority == priority }
                    if !priorityTasks.isEmpty {
                        Text("Prio \(priority.label)")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                            .padding(.top, AnkerSpacing.s3)
                            .padding(.bottom, AnkerSpacing.s2)

                        VStack(spacing: AnkerSpacing.s2) {
                            ForEach(priorityTasks, id: \.id) { task in
                                TaskCard(task: task, onUndoableAction: undo.present)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notizen

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Notizen")

            TextEditor(text: $notesDraft)
                .scrollContentBackground(.hidden)
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .frame(minHeight: 96)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s2)
                .background(AnkerColor.surface)
                .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
                .clipShape(Rectangle())
                .onChange(of: notesDraft) { _, _ in scheduleCommit() }
                .accessibilityLabel("Notizen zum Tag")
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s4)
            .background(AnkerColor.surface.opacity(0.6))
            .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
            .clipShape(Rectangle())
    }

    // MARK: - Aktionen

    private func dropTask(from providers: [NSItemProvider]) -> Bool {
        let targetDate = day.date

        return TaskDropHandling.loadTaskID(from: providers) { taskID in
            let snapshot = TaskDropHandling.moveTask(id: taskID, to: targetDate, weeks: weeks, modelContext: modelContext)
            isDropTargeted = false

            if let snapshot {
                undo.present(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: [snapshot]))
            }
        }
    }

    private func loadDraftsIfNeeded() {
        guard !hasLoadedDrafts else { return }
        focusDraft = day.focusNote ?? ""
        notesDraft = day.notes ?? ""
        hasLoadedDrafts = true
    }

    /// Tippen soll nicht jeden Anschlag speichern — CloudKit wuerde daraus einen
    /// Export pro Zeichen machen.
    private func scheduleCommit() {
        guard hasLoadedDrafts else { return }

        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            commitDrafts()
        }
    }

    private func commitNow() {
        commitTask?.cancel()
        commitTask = nil
        commitDrafts()
    }

    private func commitDrafts() {
        guard hasLoadedDrafts else { return }

        let focus = normalized(focusDraft)
        let notes = normalized(notesDraft)
        var didChange = false

        if day.focusNote != focus {
            day.focusNote = focus
            didChange = true
        }

        if day.notes != notes {
            day.notes = notes
            didChange = true
        }

        if didChange {
            modelContext.saveChanges()
        }
    }

    private func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DayTimeBlockRow: View {
    let block: TimeBlock

    private var isAnchored: Bool {
        block.linkedEventIdentifier != nil
    }

    var body: some View {
        HStack(spacing: AnkerSpacing.s3) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(AnkerDateFormat.timeOfDay(block.startTime))
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.ink)
                Text(AnkerDateFormat.timeOfDay(block.endTime))
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .frame(width: 44, alignment: .leading)

            HStack {
                Text(block.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: AnkerSpacing.s2)
                if isAnchored {
                    Image(.week)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.accentInk)
                        .accessibilityLabel("Aus dem Kalender übernommen")
                }
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s2)
            .background(AnkerColor.surface)
            .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
            .clipShape(Rectangle())
        }
        .padding(.vertical, AnkerSpacing.s2)
        .accessibilityElement(children: .combine)
    }
}

private struct TimeBlockRow: View {
    let block: TimeBlock
    let isAnchored: Bool

    var body: some View {
        HStack(spacing: AnkerSpacing.s3) {
            Text(AnkerDateFormat.timeOfDay(block.startTime))
                .ankerType(AnkerType.numericSmall)
                .foregroundStyle(AnkerColor.inkSecond)
                .frame(width: 38, alignment: .leading)

            HStack {
                Text(block.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: AnkerSpacing.s2)
                if isAnchored {
                    Rectangle()
                        .fill(AnkerColor.accentMark)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s2)
            .background(AnkerColor.surface)
            .overlay(
                Rectangle()
                    .stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule)
            )
            .clipShape(Rectangle())
        }
        .padding(.vertical, AnkerSpacing.s2)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AnkerColor.divider)
                .frame(height: 1)
        }
    }
}
