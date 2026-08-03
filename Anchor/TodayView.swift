import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Week.monday) private var weeks: [Week]

    @Bindable var day: Day
    let week: Week
    var onAddTask: () -> Void
    var onSelectDay: (Day) -> Void = { _ in }
    var onFocusDay: (Day) -> Void = { _ in }

    @State private var targetedDayID: UUID?
    @State private var isSelecting = false
    @State private var selectedTaskIDs = Set<UUID>()
    @State private var showingBulkMove = false
    @State private var showingBulkPriority = false
    @State private var confirmingBulkDelete = false
    @StateObject private var undo = TaskUndoCoordinator()

    private var tasks: [AnkerTask] {
        day.taskList.sorted { $0.order < $1.order }
    }

    private var selectedTasks: [AnkerTask] {
        tasks.filter { selectedTaskIDs.contains($0.id) }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    weekStrip

                    if let focus = day.focusNote ?? week.goalList.first?.title {
                        GoalBanner(label: "Verankert an Wochenziel", title: focus)
                            .padding(.horizontal, AnkerSpacing.screenPadding)
                            .padding(.bottom, 14)
                    }

                    SectionLabel(title: "Zeitplan")
                        .padding(.horizontal, AnkerSpacing.screenPadding)

                    VStack(spacing: 0) {
                        ForEach(day.timeBlockList.sorted { $0.startTime < $1.startTime }, id: \.id) { block in
                            TimeBlockRow(block: block, isAnchored: block.linkedEventIdentifier != nil)
                        }
                    }
                    .padding(.horizontal, AnkerSpacing.screenPadding)

                    ForEach(Priority.allCases, id: \.self) { priority in
                        let priorityTasks = tasks.filter { $0.priority == priority }
                        if !priorityTasks.isEmpty {
                            SectionLabel(title: "Prio \(priority.label)")
                                .padding(.horizontal, AnkerSpacing.screenPadding)

                            VStack(spacing: 8) {
                                ForEach(priorityTasks, id: \.id) { task in
                                    TaskCard(
                                        task: task,
                                        isSelectionMode: isSelecting,
                                        isSelected: selectedTaskIDs.contains(task.id),
                                        onSelectionToggle: {
                                            toggleSelection(for: task)
                                        },
                                        onStartSelection: {
                                            startSelection(with: task)
                                        },
                                        onUndoableAction: undo.present
                                    )
                                }
                            }
                            .padding(.horizontal, AnkerSpacing.screenPadding)
                        }
                    }
                }
                .padding(.bottom, 96)
            }
            .background(AnkerColor.paper)

            VStack(spacing: 10) {
                if let notice = undo.notice {
                    TaskUndoToast(notice: notice) {
                        undo.undo(weeks: weeks, modelContext: modelContext)
                    }
                }

                if isSelecting {
                    TaskBulkActionBar(
                        selectedCount: selectedTaskIDs.count,
                        onDone: markSelectedDone,
                        onMove: { showingBulkMove = true },
                        onPriority: { showingBulkPriority = true },
                        onDelete: requestBulkDelete
                    )
                } else {
                    HStack {
                        Spacer()
                        GlassFAB(action: onAddTask)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 86)
        }
#if os(macOS)
        .navigationTitle("Daivento — Heute")
#else
        .navigationTitle("Heute")
#endif
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(isSelecting ? "Fertig" : "Auswählen") {
                    withAnimation(listAnimation) {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedTaskIDs.removeAll()
                        }
                    }
                }
                .disabled(tasks.isEmpty)
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }
        }
#endif
        .sheet(isPresented: $showingBulkMove) {
            TaskMoveSheet(tasks: selectedTasks) { snapshots in
                undo.present(TaskUndoNotice(message: "\(snapshots.count) Aufgaben verschoben", snapshots: snapshots))
                finishSelection()
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Priorität ändern", isPresented: $showingBulkPriority, titleVisibility: .visible) {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button("Priorität \(priority.label)") {
                    setSelectedPriority(priority)
                }
            }
            Button("Abbrechen", role: .cancel) {}
        }
        .confirmationDialog("Ausgewählte Aufgaben löschen?", isPresented: $confirmingBulkDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                deleteSelectedTasks()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("\(selectedTaskIDs.count) Aufgaben werden entfernt.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(headerDate)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AnkerColor.muted)
                .tracking(0.35)
            Text("Heute")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 13)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var weekStrip: some View {
        let orderedDays = week.dayList.sorted { $0.date < $1.date }

        return HStack {
            ForEach(orderedDays, id: \.id) { item in
                Button {
                    onSelectDay(item)
                } label: {
                    WeekDot(
                        date: item.date,
                        isActive: AnkerCalendar.isSameDay(item.date, day.date),
                        hasGoal: item.taskList.contains { $0.linkedGoal != nil },
                        isDropTarget: targetedDayID == item.id
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tag \(dayLabel(item)) öffnen")
                .onDrop(
                    of: TaskDropHandling.draggedTypes,
                    isTargeted: Binding(
                        get: { targetedDayID == item.id },
                        set: { isTargeted in targetedDayID = isTargeted ? item.id : nil }
                    )
                ) { providers in
                    dropTask(from: providers, on: item)
                }

                if item.id != orderedDays.last?.id {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.vertical, 6)
        .padding(.bottom, 8)
    }

    private func dayLabel(_ day: Day) -> String {
        day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide).day().month())
    }

    private func dropTask(from providers: [NSItemProvider], on targetDay: Day) -> Bool {
        let targetDate = targetDay.date

        return TaskDropHandling.loadTaskID(from: providers) { taskID in
            let snapshot = TaskDropHandling.moveTask(id: taskID, to: targetDate, weeks: weeks, modelContext: modelContext)
            targetedDayID = nil
            onFocusDay(targetDay)

            if let snapshot {
                undo.present(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: [snapshot]))
            }
        }
    }

    private var headerDate: String {
        let weekday = day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide)).uppercased()
        let date = day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
        return "\(weekday) · \(date) · KW \(String(format: "%02d", week.isoWeek))"
    }

    private var listAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .snappy
    }

    private func toggleSelection(for task: AnkerTask) {
        if selectedTaskIDs.contains(task.id) {
            selectedTaskIDs.remove(task.id)
        } else {
            selectedTaskIDs.insert(task.id)
        }
    }

    private func startSelection(with task: AnkerTask) {
        withAnimation(listAnimation) {
            isSelecting = true
            selectedTaskIDs.insert(task.id)
        }
    }

    private func markSelectedDone() {
        let selected = selectedTasks
        guard !selected.isEmpty else { return }

        let snapshots = selected.map { TaskActions.snapshot($0) }
        for task in selected {
            task.isDone = true
        }
        try? modelContext.save()
        undo.present(TaskUndoNotice(message: "\(selected.count) Aufgaben erledigt", snapshots: snapshots))
        finishSelection()
    }

    private func setSelectedPriority(_ priority: Priority) {
        let selected = selectedTasks
        guard !selected.isEmpty else { return }

        let snapshots = selected.map { TaskActions.snapshot($0) }
        for task in selected {
            TaskActions.setPriority(task, to: priority, modelContext: modelContext)
        }
        undo.present(TaskUndoNotice(message: "Priorität geändert", snapshots: snapshots))
        finishSelection()
    }

    private func requestBulkDelete() {
        guard !selectedTaskIDs.isEmpty else { return }
        if selectedTaskIDs.count >= 3 {
            confirmingBulkDelete = true
        } else {
            deleteSelectedTasks()
        }
    }

    private func deleteSelectedTasks() {
        let selected = selectedTasks
        guard !selected.isEmpty else { return }

        let snapshots = selected.map { TaskActions.snapshot($0) }
        for task in selected {
            TaskActions.delete(task, modelContext: modelContext)
        }
        undo.present(TaskUndoNotice(message: "\(selected.count) Aufgaben gelöscht", snapshots: snapshots))
        finishSelection()
    }

    private func finishSelection() {
        withAnimation(listAnimation) {
            isSelecting = false
            selectedTaskIDs.removeAll()
        }
    }

}

private struct TaskBulkActionBar: View {
    let selectedCount: Int
    let onDone: () -> Void
    let onMove: () -> Void
    let onPriority: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(selectedCount)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(AnkerColor.indigo, in: Circle())
                .accessibilityLabel("\(selectedCount) ausgewählt")

            bulkButton("checkmark", "Erledigt", isDisabled: selectedCount == 0, action: onDone)
            bulkButton("calendar", "Verschieben", isDisabled: selectedCount == 0, action: onMove)
            bulkButton("flag", "Priorität", isDisabled: selectedCount == 0, action: onPriority)
            bulkButton("trash", "Löschen", tint: Color(hex: "#E0392E"), isDisabled: selectedCount == 0, action: onDelete)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.32), lineWidth: 1))
        .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 8)
    }

    private func bulkButton(
        _ systemName: String,
        _ title: String,
        tint: Color = AnkerColor.indigo,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemName)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 24)
                Text(title)
                    .font(.system(size: 9.5, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isDisabled ? AnkerColor.muted : tint)
            .frame(width: 62)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct TaskUndoToast: View {
    let notice: TaskUndoNotice
    let onUndo: () -> Void

    @State private var progress: CGFloat = 1

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(notice.message)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Rückgängig", action: onUndo)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(AnkerColor.indigoText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            GeometryReader { proxy in
                Capsule()
                    .fill(AnkerColor.indigo)
                    .frame(width: proxy.size.width * progress, height: 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 2)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.32), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 8)
        .onAppear {
            progress = 1
            withAnimation(.linear(duration: 4)) {
                progress = 0
            }
        }
        .id(notice.id)
        .accessibilityElement(children: .combine)
    }
}

private struct TimeBlockRow: View {
    let block: TimeBlock
    let isAnchored: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(block.startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(AnkerColor.muted)
                .frame(width: 38, alignment: .leading)

            HStack {
                Text(block.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isAnchored {
                    Circle()
                        .fill(AnkerColor.indigo)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AnkerColor.card)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(AnkerColor.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AnkerColor.lineSoft)
                .frame(height: 1)
        }
    }
}
