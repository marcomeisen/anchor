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

    @State private var isSelecting = false
    @State private var selectedTaskIDs = Set<UUID>()
    @State private var showingBulkMove = false
    @State private var showingBulkPriority = false
    @State private var confirmingBulkDelete = false
    @StateObject private var undo = TaskUndoCoordinator()
    /// Antippen eines Ankers filtert die Aufgabenliste. `nil` = alle Aufgaben des Tages.
    @State private var filteredAnchorID: UUID?

    private var tasks: [AnkerTask] {
        day.taskList.sorted { $0.order < $1.order }
    }

    private var selectedTasks: [AnkerTask] {
        tasks.filter { selectedTaskIDs.contains($0.id) }
    }

    /// Der Entwurf zeigt auf Heute: Datum, Fokus, die vier Anker, die Aufgabenliste des Tages
    /// und die Erfassungszeile. Was hier **nicht** mehr steht, ist Absicht des Entwurfs:
    ///
    /// - **Prio-Gruppen** ("Prio A/B/C" als drei Abschnitte) — der Buchstabe steht jetzt rechts
    ///   an der Zeile, und eine Liste liest sich schneller als drei.
    /// - **Zeitplan** — Zeitblöcke stehen in der Tagesdetailansicht, wo sie auch bearbeitbar sind.
    /// - **Wochenstreifen** — dafür gibt es den Tab „Woche" mit allen sieben Tagen.
    ///
    /// Die Aufgaben liegen in einer echten `List`. Das ist keine Formsache: `swipeActions`
    /// wirkt **nur** innerhalb einer `List`, und im Bestand gab es keine einzige — die im
    /// Interaktionskonzept vorgesehenen Wischgesten waren toter Code.
    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                Section {
                    focusSection
                    anchorSection
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(AnkerColor.ground)
                .listRowSeparator(.hidden)

                Section {
                    if visibleTasks.isEmpty {
                        Text(filteredAnchorID == nil ? "Nichts hier. Unten eintippen." : "Kein Eintrag für diesen Anker.")
                            .ankerType(AnkerType.body)
                            .foregroundStyle(AnkerColor.inkTertiary)
                            .padding(.vertical, AnkerSpacing.s4)
                            .listRowInsets(EdgeInsets(top: 0, leading: AnkerSpacing.screenPadding,
                                                      bottom: 0, trailing: AnkerSpacing.screenPadding))
                            .listRowBackground(AnkerColor.ground)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(visibleTasks, id: \.id) { task in
                            TaskCard(
                                task: task,
                                isSelectionMode: isSelecting,
                                isSelected: selectedTaskIDs.contains(task.id),
                                onSelectionToggle: { toggleSelection(for: task) },
                                onStartSelection: { startSelection(with: task) },
                                onUndoableAction: undo.present
                            )
                            .listRowInsets(EdgeInsets(top: 0, leading: AnkerSpacing.screenPadding,
                                                      bottom: 0, trailing: AnkerSpacing.screenPadding))
                            .listRowBackground(AnkerColor.ground)
                            .listRowSeparatorTint(AnkerColor.cardDivider)
                        }
                    }
                } header: {
                    listHeader
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AnkerColor.ground)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
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

    // MARK: - Abschnitte

    /// Der Fokus des Tages, gross und ohne Rahmen. Im Entwurf die erste Aussage des Bildschirms.
    private var focusSection: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: headerDate)
                    .ankerType(AnkerType.overline)
                    .foregroundStyle(AnkerColor.inkSecond)
                Spacer(minLength: AnkerSpacing.s2)
                Text(verbatim: "\(anchorsInMotion)/\(GoalOrdering.anchors(in: week).count) in Bewegung")
                    .ankerType(AnkerType.overline)
                    .foregroundStyle(AnkerColor.ink)
            }
            .padding(.top, AnkerSpacing.s3)
            .padding(.bottom, AnkerSpacing.s2)

            AnkerRule(color: AnkerColor.ink)

            Text(verbatim: "Fokus heute")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s4)

            Text(verbatim: focusTitle)
                .ankerType(AnkerType.title3)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s4)

            AnkerRule()
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
    }

    /// Die vier Anker. Antippen filtert die Liste darunter — das ersetzt die Zielpillen.
    private var anchorSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: "Deine vier Anker")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)
                Spacer(minLength: AnkerSpacing.s2)
                Text(verbatim: "Tippen = filtern")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkTertiary)
            }
            .padding(.top, AnkerSpacing.s4)
            .padding(.bottom, AnkerSpacing.s2)

            ForEach(Array(GoalOrdering.anchors(in: week).enumerated()), id: \.element.id) { index, goal in
                Button {
                    filteredAnchorID = filteredAnchorID == goal.id ? nil : goal.id
                } label: {
                    AnchorRow(
                        number: index + 1,
                        title: goal.title,
                        doneCount: goal.taskList.filter(\.isDone).count,
                        totalCount: goal.taskList.count,
                        tint: AnkerColor.goalTint(goal.colorHex),
                        isActive: filteredAnchorID == goal.id
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("anchorRow.\(index + 1)")
                AnkerRule(weight: .row)
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
    }

    private var listHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: listLabel)
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
            Spacer(minLength: AnkerSpacing.s2)
            if filteredAnchorID != nil {
                Button("Filter aus") { filteredAnchorID = nil }
                    .buttonStyle(AnkerButtonStyle.quiet)
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.top, AnkerSpacing.s4)
        .padding(.bottom, AnkerSpacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnkerColor.ground)
        .ankerEdge(.top, color: AnkerColor.ink)
    }

    /// Erfassungszeile, Undo-Hinweis und die Leiste der Mehrfachauswahl teilen sich den Fuss.
    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if let notice = undo.notice {
                TaskUndoToast(notice: notice) {
                    undo.undo(weeks: weeks, modelContext: modelContext)
                }
                .padding(.horizontal, AnkerSpacing.s4)
                .padding(.bottom, AnkerSpacing.s2)
            }

            if isSelecting {
                TaskBulkActionBar(
                    selectedCount: selectedTaskIDs.count,
                    onDone: markSelectedDone,
                    onMove: { showingBulkMove = true },
                    onPriority: { showingBulkPriority = true },
                    onDelete: requestBulkDelete
                )
                .padding(.horizontal, AnkerSpacing.s4)
                .padding(.bottom, AnkerSpacing.s2)
            } else {
                CaptureBar(week: week, fallbackDate: day.date)
            }
        }
        .background(AnkerColor.ground)
    }

    // MARK: - Ableitungen

    private var visibleTasks: [AnkerTask] {
        let base = filteredAnchorID.map { id in
            tasks.filter { $0.linkedGoal?.id == id }
        } ?? tasks
        // Erledigtes nach unten: die offene Arbeit steht oben.
        return base.sorted { lhs, rhs in
            lhs.isDone == rhs.isDone ? lhs.order < rhs.order : !lhs.isDone
        }
    }

    private var focusTitle: String {
        day.focusNote?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            ?? GoalOrdering.anchors(in: week).first?.title
            ?? "Kein Fokus gesetzt"
    }

    /// „In Bewegung" statt „erledigt": mitten in der Woche ist vollstaendig erledigt fast immer
    /// null und damit keine brauchbare Aussage.
    private var anchorsInMotion: Int {
        GoalOrdering.anchors(in: week).filter { goal in goal.taskList.contains(where: \.isDone) }.count
    }

    private var listLabel: String {
        if let id = filteredAnchorID,
           let goal = GoalOrdering.anchors(in: week).first(where: { $0.id == id }),
           let number = GoalOrdering.anchorNumber(of: goal, in: week) {
            return "Anker \(number)"
        }
        return "Heute · \(tasks.filter { !$0.isDone }.count) offen"
    }

    private var headerDate: String {
        let weekday = AnkerDateFormat.weekdayLong(day.date).uppercased()
        let date = AnkerDateFormat.dayMonthYear(day.date)
        return "\(weekday) · \(date) · \(AnkerDateFormat.calendarWeek(week.isoWeek))"
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
            TaskActions.setDone(task, true, modelContext: modelContext)
        }
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
        HStack(spacing: AnkerSpacing.s3) {
            Text("\(selectedCount)")
                .ankerType(AnkerType.numericSmall)
                .foregroundStyle(AnkerColor.onAccent)
                .frame(width: 30, height: 30)
                .background(AnkerColor.accentFill, in: Rectangle())
                .accessibilityLabel("\(selectedCount) ausgewählt")

            bulkButton(.check, "Erledigt", isDisabled: selectedCount == 0, action: onDone)
            bulkButton(.week, "Verschieben", isDisabled: selectedCount == 0, action: onMove)
            bulkButton(.priority, "Priorität", isDisabled: selectedCount == 0, action: onPriority)
            bulkButton(.delete, "Löschen", tint: AnkerColor.accentMark, isDisabled: selectedCount == 0, action: onDelete)
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s3)
        .ankerCard()
    }

    private func bulkButton(
        _ ankerIcon: AnkerIcon,
        _ title: String,
        tint: Color = AnkerColor.accentFill,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: AnkerSpacing.s1) {
                Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                Text(title)
                    .ankerType(AnkerType.caption)
                    .lineLimit(1)
            }
            .foregroundStyle(isDisabled ? AnkerColor.inkSecond : tint)
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
            HStack(spacing: AnkerSpacing.s3) {
                Text(notice.message)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: AnkerSpacing.s2)
                Button("Rückgängig", action: onUndo)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.accentInk)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s3)

            AnkerProgressBar(
                progress: progress,
                tint: AnkerColor.accentMark,
                track: .clear,
                thickness: AnkerBorder.rule
            )
        }
        // Der Ablaufbalken sitzt buendig an der Unterkante. Ohne Beschnitt stuenden seine
        // scharfen Enden ueber die runde Karte hinaus.
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card, style: .continuous))
        .ankerCard()
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
