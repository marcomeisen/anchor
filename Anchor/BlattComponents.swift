import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Kopf eines Bildschirms

/// Kleine Zeile oben, große Zeile darunter — „KW 48 · noch 6 Tage" über „Montag, 23.".
struct BlattHeading: View {
    let eyebrow: String
    let title: String
    var eyebrowColor: Color = AnkerColor.inkSecond
    var titleStyle: AnkerTextStyle = AnkerType.title2

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s0) {
            Text(verbatim: eyebrow)
                .ankerType(AnkerType.overline)
                .foregroundStyle(eyebrowColor)
            Text(verbatim: title)
                .ankerType(titleStyle)
                .foregroundStyle(AnkerColor.ink)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Eine Abschnittsbeschriftung mit optionaler Zahl rechts.
struct BlattSectionLabel: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            if let trailing {
                Text(verbatim: trailing).monospacedDigit()
            }
        }
        .ankerType(AnkerType.overline)
        .foregroundStyle(AnkerColor.inkSecond)
        .padding(.horizontal, AnkerSpacing.s1)
    }
}

// MARK: - Die vier Anker als Leiste

/// Vier Zellen nebeneinander: Nummer, Kurztitel, Zähler, Punkte.
struct BlattAnchorStrip: View {
    let sheet: WeekSheet
    var onSelect: (Goal) -> Void
    var onAddAnchor: (() -> Void)?

    var body: some View {
        let lanes = sheet.anchorLanes
        HStack(spacing: AnkerBorder.hairline) {
            ForEach(lanes) { lane in
                if let goal = lane.goal {
                    Button { onSelect(goal) } label: { cell(lane) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Anker \(lane.numberLabel), \(lane.title), \(lane.doneCount) von \(lane.tasks.count) erledigt")
                        .accessibilityIdentifier("anchorCell.\(lane.numberLabel)")
                }
            }
            if lanes.count < 4, let onAddAnchor {
                Button(action: onAddAnchor) {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                        Text(verbatim: "\(lanes.count + 1)")
                            .ankerType(AnkerType.bodyStrong)
                            .foregroundStyle(AnkerColor.inkTertiary)
                        Text("Anker setzen")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                        Spacer(minLength: 0)
                    }
                    .padding(AnkerSpacing.s2 + 2)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
                    .background(AnkerColor.card)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .background(AnkerColor.divider)
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AnkerRadius.card, style: .continuous)
                .strokeBorder(AnkerColor.divider, lineWidth: AnkerBorder.hairline)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Deine Anker")
    }

    private func cell(_ lane: WeekSheet.Lane) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: lane.numberLabel)
                    .ankerType(AnkerType.subheadline)
                    .monospacedDigit()
                Spacer(minLength: AnkerSpacing.s0)
                Text(verbatim: "\(lane.doneCount)/\(lane.tasks.count)")
                    .ankerType(AnkerType.microLabel)
                    .monospacedDigit()
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            Text(verbatim: lane.title)
                .ankerType(AnkerType.caption)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            AnkerPips(done: lane.doneCount, total: lane.tasks.count, size: 8)
        }
        .foregroundStyle(AnkerColor.ink)
        .padding(AnkerSpacing.s2 + 2)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .background(AnkerColor.card)
        .contentShape(Rectangle())
    }
}

// MARK: - Aufgabe als Chip

/// Eine Aufgabe im Wochenraster: Ankernummer und Titel, erledigt durchgestrichen.
///
/// Antippen ändert **nichts** — das Kästchen hakt ab, die Zeile nicht. Alles Weitere steht im
/// Kontextmenü; auf dem Mac lässt sich der Chip ziehen.
struct TaskChip: View {
    @Environment(\.modelContext) private var modelContext
    let task: AnkerTask
    var number: String?
    var compact = false
    var showsCheckbox = false
    /// Antippen wählt die Aufgabe zum Einplanen aus (iPhone, Woche nach Tag). Es ändert
    /// keinen Zustand an der Aufgabe — erst „Hierher" bei einem Tag tut das.
    var onPick: (() -> Void)?
    var isPicked = false
    var onUndoableAction: ((TaskUndoNotice) -> Void)?

    @State private var showingMove = false
    @State private var showingEditor = false

    var body: some View {
        chip
            .sheet(isPresented: $showingMove) {
                TaskMoveSheet(tasks: [task]) { snapshots in
                    onUndoableAction?(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: snapshots))
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showingEditor) {
                TaskEditorSheet(task: task, onUndoableAction: onUndoableAction)
                    .presentationDetents([.medium, .large])
            }
    }

    /// Die Anker der Woche, zu der die Aufgabe gehört — über den Tag, sonst über den Anker.
    private var anchors: [Goal] {
        guard let week = task.day?.week ?? task.linkedGoal?.week else { return [] }
        return GoalOrdering.anchors(in: week)
    }

    @ViewBuilder
    private var chipMarks: some View {
        if showsCheckbox {
            Button(action: toggle) {
                TaskCheckmark(isDone: task.isDone, size: 14)
                    .ankerTapTarget(14)
            }
            .buttonStyle(.plain)
        }
        if let number {
            Text(verbatim: number)
                .ankerType(AnkerType.caption)
                .fontWeight(.heavy)
                .monospacedDigit()
                .foregroundStyle(task.isDone ? AnkerColor.inkTertiary : AnkerColor.accentInk)
        }
    }

    private func chipTitle(lines: Int) -> some View {
        Text(verbatim: task.title)
            .ankerType(compact ? AnkerType.caption : AnkerType.meta)
            .foregroundStyle(task.isDone ? AnkerColor.inkTertiary : AnkerColor.ink)
            .strikethrough(task.isDone, color: AnkerColor.inkTertiary)
            .lineLimit(lines)
            .multilineTextAlignment(.leading)
    }

    @ViewBuilder
    private var chipContent: some View {
        if compact {
            // In schmalen Rasterspalten brach der Titel neben dem Kästchen mitten im Wort um
            // („Launc|h-Deck"). Passt er nicht in eine Zeile, steht er unter dem Kästchen und
            // bekommt die volle Chipbreite.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: AnkerSpacing.s1 + 2) {
                    chipMarks
                    chipTitle(lines: 1).fixedSize()
                }
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    HStack(spacing: AnkerSpacing.s1 + 2) { chipMarks }
                    chipTitle(lines: 3)
                }
            }
        } else {
            HStack(spacing: AnkerSpacing.s1 + 2) {
                chipMarks
                chipTitle(lines: 2)
            }
        }
    }

    private var chip: some View {
        chipContent
        .padding(.horizontal, AnkerSpacing.s2 - 1)
        .padding(.vertical, compact ? 4 : 5)
        .frame(maxWidth: compact ? .infinity : nil, alignment: .leading)
        .background(
            isPicked ? AnkerColor.accentTint : (task.isDone ? Color.clear : AnkerColor.surface),
            in: RoundedRectangle(cornerRadius: AnkerRadius.chip, style: .continuous)
        )
        .overlay {
            if isPicked {
                RoundedRectangle(cornerRadius: AnkerRadius.chip, style: .continuous)
                    .strokeBorder(AnkerColor.accentMark, lineWidth: AnkerBorder.focus)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: AnkerRadius.chip, style: .continuous))
        .onTapGesture { onPick?() }
        .draggable(task.id.uuidString) {
            Text(verbatim: task.title)
                .ankerType(AnkerType.meta)
                .padding(AnkerSpacing.s2)
                .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: AnkerRadius.chip, style: .continuous))
        }
        .contextMenu { menu }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
        .accessibilityIdentifier("taskChip")
        .accessibilityAction(named: task.isDone ? "Als offen markieren" : "Als erledigt markieren", toggle)
        .accessibilityAction(named: "Aufgabe bearbeiten") { showingEditor = true }
        .accessibilityActions {
            ForEach(Array(anchors.enumerated()), id: \.element.id) { index, goal in
                Button("Anker \(index + 1): \(goal.title)") { link(goal) }
            }
        }
        .accessibilityAction(named: "Ohne Tag") { unschedule() }
        .accessibilityAction(named: "Verschieben") { showingMove = true }
        .accessibilityAction(named: "Ohne Anker") { link(nil) }
        .accessibilityAction(named: "In die nächste Woche") { moveToNextWeek() }
        .accessibilityAction(named: "Aufgabe löschen") { delete() }
    }

    private var accessibilityText: String {
        let anchor = number.map { "Anker \($0)" } ?? "Ohne Anker"
        return "\(task.title), \(anchor)\(task.isDone ? ", erledigt" : "")"
    }

    @ViewBuilder
    private var menu: some View {
        Button(task.isDone ? "Als offen markieren" : "Als erledigt markieren", action: toggle)
        Button("Bearbeiten …") { showingEditor = true }
        Menu("Anker") {
            ForEach(Array(anchors.enumerated()), id: \.element.id) { index, goal in
                Button {
                    link(goal)
                } label: {
                    Label(verbatim: "\(index + 1) · \(goal.title)", ankerIcon: task.linkedGoal?.id == goal.id ? .check : .goal)
                }
            }
            if !anchors.isEmpty {
                Divider()
            }
            Button {
                link(nil)
            } label: {
                Label("Ohne Anker", ankerIcon: task.linkedGoal == nil ? .check : .clear)
            }
        }
        Button("Verschieben …") { showingMove = true }
        Button("In die nächste Woche", action: moveToNextWeek)
        if task.day != nil {
            Button("Ohne Tag", action: unschedule)
        }
        Divider()
        Button("Aufgabe löschen", role: .destructive, action: delete)
    }

    /// Derselbe Wochentag eine Woche später — ohne Tag der Montag der Folgewoche.
    private func moveToNextWeek() {
        let snapshot = TaskActions.snapshot(task)
        let base = task.day?.date ?? Date()
        let monday = AnkerCalendar.weekInterval(containing: base.addingTimeInterval(12 * 60 * 60)).monday
        guard let next = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: monday) else { return }
        TaskActions.move(task, toWeekStarting: next, weeks: [], modelContext: modelContext)
        onUndoableAction?(TaskUndoNotice(message: "In die nächste Woche verschoben", snapshots: [snapshot]))
    }

    private func toggle() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.toggleDone(task, modelContext: modelContext)
        onUndoableAction?(TaskUndoNotice(message: task.isDone ? "Erledigt" : "Wieder offen", snapshots: [snapshot]))
    }

    private func unschedule() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.unschedule(task, modelContext: modelContext)
        onUndoableAction?(TaskUndoNotice(message: "Ohne Tag", snapshots: [snapshot]))
    }

    private func delete() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.delete(task, modelContext: modelContext)
        onUndoableAction?(TaskUndoNotice(message: "Aufgabe gelöscht", snapshots: [snapshot]))
    }

    private func link(_ goal: Goal?) {
        guard task.linkedGoal?.id != goal?.id else { return }
        let snapshot = TaskActions.snapshot(task)
        TaskActions.link(task, to: goal, modelContext: modelContext)
        onUndoableAction?(TaskUndoNotice(message: goal == nil ? "Anker gelöst" : "Anker gesetzt", snapshots: [snapshot]))
    }
}

// MARK: - Ablegen

enum BlattDrop {
    /// Legt die gezogene Aufgabe auf Tag und Anker — `date == nil` heißt „ohne Tag".
    ///
    /// Vor dem Ändern entsteht ein Schnappschuss; `onUndoable` bekommt den Rückgängig-Hinweis
    /// (zum Beispiel `undo.present`). Ein Drop, der nichts ändert, meldet keinen.
    @MainActor
    @discardableResult
    static func place(
        _ payload: [String],
        on date: Date?,
        goal: Goal?,
        weeks: [Week],
        modelContext: ModelContext,
        onUndoable: (TaskUndoNotice) -> Void = { _ in }
    ) -> Bool {
        guard let raw = payload.first, let id = UUID(uuidString: raw) else { return false }
        let descriptor = FetchDescriptor<AnkerTask>(predicate: #Predicate { $0.id == id })
        guard let task = try? modelContext.fetch(descriptor).first else { return false }
        // Die Ursprungszeile einer `TaskCard` wartet auf das Drag-Ende, sonst bleibt sie blass.
        defer { TaskDragEvents.end(taskID: id) }

        let snapshot = TaskActions.snapshot(task)
        if let date {
            TaskActions.place(task, on: date, goalID: goal?.id, weeks: weeks, modelContext: modelContext)
        } else {
            TaskActions.unschedule(task, modelContext: modelContext)
            TaskActions.link(task, to: goal, modelContext: modelContext)
        }

        let after = TaskActions.snapshot(task)
        if after.dayID != snapshot.dayID || after.goalID != snapshot.goalID {
            onUndoable(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: [snapshot]))
        }
        return true
    }
}

// MARK: - Rückgängig

struct BlattUndoBar: View {
    @ObservedObject var coordinator: TaskUndoCoordinator
    let weeks: [Week]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        if let notice = coordinator.notice {
            HStack {
                Text(verbatim: notice.message)
                    .ankerType(AnkerType.label)
                    .foregroundStyle(AnkerColor.onInk)
                Spacer()
                Button("Rückgängig") {
                    coordinator.undo(weeks: weeks, modelContext: modelContext)
                }
                .ankerType(AnkerType.label)
                .foregroundStyle(AnkerColor.onInk)
                .buttonStyle(.plain)
                .keyboardShortcut("z", modifiers: .command)
            }
            .padding(.horizontal, AnkerSpacing.s4)
            .frame(minHeight: 48)
            .background(AnkerColor.ink, in: RoundedRectangle(cornerRadius: AnkerRadius.bar, style: .continuous))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

// MARK: - Leerer Zustand

struct BlattEmptyNote: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .ankerType(AnkerType.body)
            .foregroundStyle(AnkerColor.inkSecond)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AnkerSpacing.s4)
            .ankerCard(fill: AnkerColor.surface, elevated: false)
    }
}

// MARK: - Datum

enum BlattDates {
    static let weekdayNames = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    static func isToday(_ date: Date, now: Date = Date()) -> Bool {
        AnkerCalendar.isSameDay(date, now)
    }

    static func remainingDays(in sheet: WeekSheet, now: Date = Date()) -> Int? {
        guard let index = sheet.dates.firstIndex(where: { isToday($0, now: now) }) else { return nil }
        return 6 - index
    }
}

/// Der kleine Rückgängig-Hinweis mit Ablaufbalken — für Ansichten außerhalb von „Blatt“
/// (Tagesdetail).
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

/// Ein Symbolknopf im Fensterkopf — auf allen Plattformen (der iPhone-Baustein
/// `AnkerHeaderButton` existiert nur unter iOS).
struct BlattIconButton: View {
    let icon: AnkerIcon
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .ankerIcon(AnkerIconSize.m)
                .foregroundStyle(AnkerColor.ink)
                .frame(width: 40, height: 40)
                .ankerTapTarget(40)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(Text(label))
    }
}

/// Der Weg zurück aus einer Detailansicht auf Mac und iPad.
///
/// Über `dismiss` aus der Umgebung, **nicht** über eine hereingereichte Closure: der Baustein
/// von `navigationDestination` ist escapend und hält eine Momentaufnahme der Wurzelansicht —
/// ein Zurück darüber schriebe in eine Kopie.
struct BlattBackBar: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: AnkerSpacing.s1) {
                    Image(.chevronLeft).ankerIcon(AnkerIconSize.s)
                    Text("Zurück")
                }
                .ankerType(AnkerType.label)
                .foregroundStyle(AnkerColor.ink)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("[", modifiers: .command)
            Spacer()
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .background(AnkerColor.ground)
    }
}
