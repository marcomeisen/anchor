import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Die Anker-Matrix: Zeile = Anker, Spalte = Tag.
///
/// Ersetzt die Wochenübersicht im Split-Layout (Mac, iPad). Auf dem iPhone bleibt die
/// Tagesliste — sieben Spalten sind dort nicht lesbar.
struct AnkerMatrixView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let week: Week
    let selectedDay: Day
    var onSelectGoal: (Goal) -> Void = { _ in }

    /// Welche Zelle ist gerade Ziel eines Drags?
    @State private var targetedCell: CellID?
    @State private var goalPendingDeletion: Goal?
    @StateObject private var undo = TaskUndoCoordinator()

    private struct CellID: Hashable {
        let row: String
        let dayID: UUID
    }

    private var days: [Day] { AnkerMatrix.orderedDays(in: week) }
    private var rows: [MatrixRow] { AnkerMatrix.rows(for: week) }

    /// Einmal pro `body` aufgelöst statt siebenmal — derselbe Grund wie beim Duplikat-Zähler.
    private var todayID: UUID? {
        days.first { AnkerCalendar.isSameDay($0.date, Date()) }?.id
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = AnkerMatrixMetrics.dayColumnWidth(containerWidth: proxy.size.width)

            VStack(spacing: 0) {
                headerBar

                // Der Tagesheader gehoert **in** die Scrollansicht, nicht darueber:
                //
                // 1. Ausserhalb zog er die `VStack` auf seine eigene Breite (212 + 7 × 108).
                //    Auf einem schmaleren Fenster schob das die Erfassungszeile aus dem
                //    Fenster hinaus — der Knopf „Sichern" war nicht mehr erreichbar.
                // 2. Beim Querscrollen wanderten die Spalten, der Header nicht. Die
                //    Wochentagsbeschriftung stand dann ueber der falschen Spalte.
                ScrollView([.vertical, metrics.needsHorizontalScroll ? .horizontal : []]) {
                    VStack(spacing: 0) {
                        dayHeader(width: metrics.width)

                        ForEach(rows) { row in
                            matrixRow(row, width: metrics.width)
                            AnkerRule()
                        }
                    }
                }

                if let notice = undo.notice {
                    TaskUndoToast(notice: notice) {
                        undo.undo(weeks: weeks, modelContext: modelContext)
                    }
                    .padding(AnkerSpacing.s3)
                }

                CaptureBar(week: week, fallbackDate: selectedDay.date)
            }
        }
        .background(AnkerColor.ground)
        .navigationTitle("Wochenübersicht")
        .goalDeleteConfirmation(goal: $goalPendingDeletion, week: week)
    }

    // MARK: - Kopf

    private var headerBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: AnkerSpacing.s5) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    // Woche, Zeitraum und gewählter Tag stehen in `AnkerContentHeader`. Hier
                    // bleibt die Aussage der Matrix — nicht ihre Ortsangabe.
                    Text(verbatim: AnkerMatrix.headline(
                        inMotion: AnkerMatrix.inMotionCount(in: week),
                        anchorCount: min(week.goalList.count, AnkerMatrix.maxAnchors),
                        openTasks: week.dayList.flatMap(\.taskList).filter { !$0.isDone }.count
                    ))
                    .ankerType(AnkerType.title1)
                    .foregroundStyle(AnkerColor.ink)
                }

                Spacer(minLength: AnkerSpacing.s4)
            }
            .padding(.horizontal, AnkerSpacing.s5)
            .padding(.vertical, AnkerSpacing.s4)

            AnkerRule(color: AnkerColor.ink)
        }
    }

    private func dayHeader(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(verbatim: "Anker")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .frame(width: AnkerMatrixMetrics.anchorColumnWidth, alignment: .leading)
                    .padding(.horizontal, AnkerSpacing.s4)

                ForEach(days, id: \.id) { day in
                    let isToday = day.id == todayID
                    HStack(spacing: AnkerSpacing.s1) {
                        Text(verbatim: AnkerDateFormat.weekdayShort(day.date))
                            .ankerType(AnkerType.overline)
                            .foregroundStyle(isToday ? AnkerColor.accentInk : AnkerColor.ink)
                        Text(verbatim: AnkerDateFormat.dayMonth(day.date))
                            .ankerType(AnkerType.numericSmall)
                            .foregroundStyle(AnkerColor.inkSecond)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AnkerSpacing.s2)
                    .padding(.vertical, AnkerSpacing.s3)
                    .frame(width: width, alignment: .leading)
                    .background(isToday ? AnkerColor.highlight : Color.clear)
                }
            }
            AnkerRule(color: AnkerColor.ink)
        }
    }

    // MARK: - Zeilen

    private func matrixRow(_ row: MatrixRow, width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            anchorCell(row)
                .frame(width: AnkerMatrixMetrics.anchorColumnWidth, alignment: .topLeading)

            AnkerRule(axis: .vertical)

            ForEach(days, id: \.id) { day in
                dropCell(row: row, day: day)
                    .frame(width: width, alignment: .topLeading)
            }
        }
        .background(row.isInbox ? AnkerColor.surface : Color.clear)
    }

    private func anchorCell(_ row: MatrixRow) -> some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s3) {
            Text(verbatim: row.number)
                .ankerType(AnkerType.subheadline)
                .foregroundStyle(row.isInbox ? AnkerColor.inkTertiary : AnkerColor.ink)

            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                Text(verbatim: row.title)
                    .ankerType(AnkerType.bodyStrong)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !row.isInbox {
                    AnkerProgressBar(
                        progress: row.progress,
                        tint: AnkerColor.goalTint(row.colorHex),
                        thickness: AnkerBorder.rule * 2 + 1
                    )
                }

                Text(verbatim: AnkerMatrix.metaLine(kind: row.kind, doneCount: row.doneCount, totalCount: row.totalCount))
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(row.isExcess ? AnkerColor.accentInk : AnkerColor.inkSecond)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AnkerSpacing.s3)
        .frame(minHeight: AnkerMatrixMetrics.minCellHeight, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture {
            if let id = row.goalID, let goal = week.goalList.first(where: { $0.id == id }) {
                onSelectGoal(goal)
            }
        }
        .contextMenu {
            if let id = row.goalID, let goal = week.goalList.first(where: { $0.id == id }) {
                Button(role: .destructive) {
                    goalPendingDeletion = goal
                } label: {
                    Label("Wochenziel löschen", ankerIcon: .delete)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func dropCell(row: MatrixRow, day: Day) -> some View {
        let cell = CellID(row: row.id, dayID: day.id)
        let isTargeted = targetedCell == cell
        let cellTasks = AnkerMatrix.tasks(in: row, on: day)
        let isToday = day.id == todayID

        return VStack(alignment: .leading, spacing: AnkerSpacing.s1 + 1) {
            ForEach(cellTasks, id: \.id) { task in
                MatrixTaskChip(task: task, onUndoableAction: undo.present)
            }

            if isTargeted && cellTasks.isEmpty {
                Text(verbatim: AnkerMatrix.emptyCellHint)
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.accentInk)
            }

            Spacer(minLength: 0)
        }
        .padding(AnkerSpacing.s2)
        .frame(maxWidth: .infinity, minHeight: AnkerMatrixMetrics.minCellHeight, alignment: .topLeading)
        .background(cellBackground(isTargeted: isTargeted, isToday: isToday))
        .overlay {
            if isTargeted {
                Rectangle()
                    .strokeBorder(AnkerColor.accentMark, lineWidth: AnkerBorder.rule)
            }
        }
        .overlay(alignment: .trailing) {
            if day.id != days.last?.id {
                AnkerRule(axis: .vertical)
            }
        }
        .onDrop(
            of: TaskDropHandling.draggedTypes,
            isTargeted: Binding(
                get: { targetedCell == cell },
                set: { targetedCell = $0 ? cell : nil }
            )
        ) { providers in
            drop(providers, row: row, day: day)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(row.title), \(AnkerDateFormat.weekdayLong(day.date)), \(cellTasks.count) Aufgaben")
        .accessibilityIdentifier("matrixCell.\(row.id).\(day.id.uuidString)")
    }

    private func cellBackground(isTargeted: Bool, isToday: Bool) -> Color {
        if isTargeted { return AnkerColor.accentTint }
        if isToday { return AnkerColor.highlight }
        return .clear
    }

    private func drop(_ providers: [NSItemProvider], row: MatrixRow, day: Day) -> Bool {
        TaskDropHandling.loadTaskID(from: providers) { taskID in
            let snapshot = TaskDropHandling.placeTask(
                id: taskID,
                on: .init(date: day.date, goalID: row.goalID),
                weeks: weeks,
                modelContext: modelContext
            )
            targetedCell = nil

            guard let snapshot else { return }
            undo.present(
                TaskUndoNotice(
                    message: row.isInbox ? "Anker gelöst" : "Verankert an \(row.title)",
                    snapshots: [snapshot]
                )
            )
        }
    }
}

/// Eine Aufgabe in einer Matrixzelle.
///
/// **Das Kästchen hakt ab, der Titel wird bearbeitet.** Vorher hakte ein Klick auf die ganze
/// Chipfläche ab — die häufige Handlung, aber damit war der Titel per Klick unerreichbar und jeder
/// Versuch, eine Aufgabe anzusehen, änderte ihren Zustand. Jetzt gilt hier dieselbe Regel wie in
/// der Tagesliste: das Quadrat schaltet, ein Doppelklick auf den Titel öffnet ihn zum Tippen.
///
/// Das Kontextmenü bleibt der barrierefreie Ersatz für das Ziehen: ohne das Untermenü „Anker"
/// wäre die Kernaktion der Matrix per Tastatur unerreichbar.
private struct MatrixTaskChip: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let task: AnkerTask
    var onUndoableAction: ((TaskUndoNotice) -> Void)?

    @State private var isDragging = false
    @State private var showingEditor = false
    @State private var isEditingTitle = false

    var body: some View {
        chip
            .opacity(isDragging ? 0.35 : 1)
            .contentShape(Rectangle())
            .conditionalTaskDrag(task: task, isEnabled: task.day != nil, isDragging: $isDragging)
            .contextMenu { menu }
            .sheet(isPresented: $showingEditor) {
                TaskEditorSheet(task: task)
                    .presentationDetents([.medium, .large])
            }
            .onReceive(NotificationCenter.default.publisher(for: TaskDragEvents.didEnd)) { notification in
                guard let rawID = notification.object as? String, rawID == task.id.uuidString else { return }
                isDragging = false
            }
            .accessibilityLabel("\(task.title)\(task.isDone ? ", erledigt" : "")")
    }

    /// Getrennt vom `body`, weil der Typechecker die Kette sonst nicht in vertretbarer Zeit
    /// aufloest.
    private var chip: some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s2) {
            Button(action: toggle) {
                // 14pt statt 22: in einer 108pt-Spalte bliebe fuer den Titel sonst nichts.
                TaskCheckmark(isDone: task.isDone, size: 14)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("matrixChipToggle")

            TaskTitleField(
                task: task,
                style: AnkerType.caption,
                isEditing: $isEditingTitle
            )
            .onTapGesture(count: 2) { isEditingTitle = true }

            Spacer(minLength: 0)
        }
            .padding(.horizontal, AnkerSpacing.s2)
            .padding(.vertical, AnkerSpacing.s1 + 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(task.isDone ? Color.clear : AnkerColor.ground)
            .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
            // Prioritaet A als Kante links: sichtbar, ohne eine zweite Farbe einzufuehren.
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(task.priority == .a ? AnkerColor.accentMark : Color.clear)
                    .frame(width: AnkerBorder.heavy)
            }
    }

    @ViewBuilder
    private var menu: some View {
        Button(task.isDone ? "Als offen markieren" : "Als erledigt markieren", action: toggle)
        Button("Titel ändern") { isEditingTitle = true }
        Button("Bearbeiten …") { showingEditor = true }
        anchorMenu
        Divider()
        Button("Löschen", role: .destructive, action: delete)
    }

    private func delete() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.delete(task, modelContext: modelContext)
        onUndoableAction?(
            TaskUndoNotice(message: "Aufgabe gelöscht", snapshots: [snapshot], operation: .restore)
        )
    }

    /// Der barrierefreie Ersatz fuer das Ziehen.
    @ViewBuilder
    private var anchorMenu: some View {
        if let week = task.day?.week {
            Menu {
                ForEach(Array(AnkerMatrix.orderedGoals(in: week).prefix(AnkerMatrix.maxAnchors).enumerated()), id: \.element.id) { index, goal in
                    Button {
                        let snapshot = TaskActions.snapshot(task)
                        TaskActions.link(task, to: goal, modelContext: modelContext)
                        onUndoableAction?(TaskUndoNotice(message: "Verankert an \(goal.title)", snapshots: [snapshot]))
                    } label: {
                        Label(verbatim: "Anker \(index + 1) · \(goal.title)",
                              ankerIcon: task.linkedGoal?.id == goal.id ? .check : .goal)
                    }
                }
                Button {
                    let snapshot = TaskActions.snapshot(task)
                    TaskActions.link(task, to: nil, modelContext: modelContext)
                    onUndoableAction?(TaskUndoNotice(message: "Anker gelöst", snapshots: [snapshot]))
                } label: {
                    Label("Ohne Anker", ankerIcon: task.linkedGoal == nil ? .check : .clear)
                }
            } label: {
                Label("Anker", ankerIcon: .goal)
            }
        }
    }

    private func toggle() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.toggleDone(task, modelContext: modelContext)
        onUndoableAction?(
            TaskUndoNotice(message: task.isDone ? "Als erledigt markiert" : "Als offen markiert", snapshots: [snapshot])
        )
    }
}
