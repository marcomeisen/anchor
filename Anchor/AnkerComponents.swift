import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .ankerType(AnkerType.overline)
            .foregroundStyle(AnkerColor.inkSecond)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AnkerSpacing.s4)
            .padding(.bottom, AnkerSpacing.s2)
    }
}

struct PriorityTag: View {
    let priority: Priority

    /// Die Marke traegt Schrift, also muss jede Stufe 4,5:1 mit `onAccent` halten.
    ///
    /// Deshalb **nicht** `accentMark`: das ist die 3:1-Markenfarbe fuer Linien und Icons, und mit
    /// einem Buchstaben darauf kam sie auf 4,20:1. Die Stufen laufen jetzt ueber die Rampe —
    /// A tiefer als B, C aus der Textrampe.
    var color: Color {
        switch priority {
        case .a: AnkerColor.accent[700]
        case .b: AnkerColor.accentFill
        case .c: AnkerColor.inkSecond
        }
    }

    var body: some View {
        Text(priority.label)
            .ankerType(AnkerType.microLabel)
            .foregroundStyle(AnkerColor.onAccent)
            .padding(.horizontal, AnkerSpacing.s1)
            .padding(.vertical, AnkerSpacing.s1)
            .background(color, in: Rectangle())
            .accessibilityLabel("Priorität \(priority.label)")
    }
}

struct TaskCheckmark: View {
    let isDone: Bool
    /// Die Tagesliste hat Platz fuer 22pt, der Matrixchip in einer 108pt-Spalte nicht.
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous)
            .fill(isDone ? AnkerColor.ink : Color.clear)
            .overlay(
                // Auch offen eine 2px-Kante in Tinte, nicht in der Trennlinienfarbe: das
                // Kaestchen ist ein Bedienelement und muss als solches lesbar sein.
                RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous)
                    .stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule)
            )
            .overlay {
                if isDone {
                    Image(.check)
                        .ankerIcon(size * 0.6)
                        .foregroundStyle(AnkerColor.onAccent)
                }
            }
            .frame(width: size, height: size)
            .contentShape(RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous))
            .accessibilityLabel(isDone ? "Erledigt" : "Offen")
    }
}

/// Der Titel einer Aufgabe — an der Stelle bearbeitbar, an der er steht.
///
/// Der Entwurf arbeitet mit Flaechen und Kanten, nicht mit Dialogen: ein Blatt mit sechs Feldern
/// aufzurufen, um ein Wort zu tippen, sind drei Handgriffe zu viel. Doppelklick oeffnet das Feld,
/// Enter sichert, Escape verwirft. Das ganze Blatt bleibt fuer die Faelle, in denen sich Woche,
/// Tag und Anker mitaendern sollen.
///
/// Ein leerer Titel wird verworfen statt die Aufgabe zu loeschen — Text wegzuwischen darf keine
/// Loeschung sein.
struct TaskTitleField: View {
    @Environment(\.modelContext) private var modelContext

    let task: AnkerTask
    let style: AnkerTextStyle
    var lineLimit: Int = 2
    @Binding var isEditing: Bool
    var onRenamed: ((TaskSnapshot) -> Void)?

    @State private var draft = ""
    /// Ob der Fokus ueberhaupt schon einmal angekommen ist.
    ///
    /// Ohne das feuerte `onChange` nie, wenn das Feld den Fokus nie bekam — und das Feld blieb
    /// offen stehen, auch wenn der Nutzer woanders hin klickte.
    @State private var didFocus = false
    @FocusState private var isFocused: Bool

    var body: some View {
        if isEditing {
            field
        } else {
            Text(verbatim: task.title)
                .ankerType(style)
                .foregroundStyle(task.isDone ? AnkerColor.inkSecond : AnkerColor.ink)
                .strikethrough(task.isDone, color: AnkerColor.inkSecond)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
    }

    private var field: some View {
        TextField("Titel", text: $draft)
            .textFieldStyle(.plain)
            .ankerType(style)
            .foregroundStyle(AnkerColor.ink)
            .lineLimit(1)
            .focused($isFocused)
            .onSubmit(commit)
            // Die 2px-Kante im Akzent ist dieselbe, mit der das System ueberall den Fokus
            // auszeichnet — kein eigenes Idiom fuer diesen Fall.
            .padding(.horizontal, AnkerSpacing.s1)
            .ankerControl(fill: AnkerColor.ground, stroke: AnkerColor.accentMark)
            .task {
                draft = task.title
                // Ein `@FocusState` unmittelbar beim Erscheinen zu setzen greift nicht
                // verlaesslich: das Feld ist noch nicht im Fokussystem angemeldet. Ein Durchlauf
                // Wartezeit genuegt.
                await Task.yield()
                isFocused = true
            }
            // Fokus zu verlieren heisst sichern, nicht verwerfen: wer woanders hin klickt, hat
            // seine Aenderung gemeint.
            .onChange(of: isFocused) { _, hasFocus in
                if hasFocus {
                    didFocus = true
                } else if didFocus {
                    commit()
                }
            }
#if os(macOS)
            .onExitCommand { isEditing = false }
#endif
            // SwiftUI meldet bei einem `TextField` den **Inhalt** als Beschriftung und
            // ueberschreibt damit `accessibilityLabel`. Die Kennung ist deshalb der einzige
            // stabile Zugriff — der UI-Test haengt daran.
            .accessibilityIdentifier("taskTitleField")
            .accessibilityLabel("Titel der Aufgabe")
    }

    private func commit() {
        guard isEditing else { return }
        let snapshot = TaskActions.snapshot(task)
        isEditing = false
        if TaskActions.rename(task, to: draft, modelContext: modelContext) {
            onRenamed?(snapshot)
        }
    }
}

struct TaskCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Week.monday) private var weeks: [Week]

    /// Was in der Metazeile steht.
    ///
    /// In der Tagesliste ist der **Anker** die Aussage — die Zuordnung ist der Kern der App. Im
    /// Ankerdetail haben alle Aufgaben denselben Anker; dort ist der **Tag** die Information.
    enum MetaLine { case anchor, day }

    let task: AnkerTask
    var showPriority = true
    var metaLine: MetaLine = .anchor
    var onToggle: (() -> Void)?
    var isSelectionMode = false
    var isSelected = false
    var onSelectionToggle: (() -> Void)?
    var onStartSelection: (() -> Void)?
    var onUndoableAction: ((TaskUndoNotice) -> Void)?

    @State private var showingEditor = false
    @State private var isEditingTitle = false
    @State private var showingMoveSheet = false
    @State private var confirmingDelete = false
    @State private var isHovering = false
    @State private var isDragging = false

    private var isActionable: Bool {
        task.day != nil
    }

    /// „Anker 2 · Security-Review" oder „Ohne Anker".
    private var anchorLabel: String {
        guard let goal = task.linkedGoal else { return "Ohne Anker" }
        guard let week = goal.week,
              let number = GoalOrdering.anchorNumber(of: goal, in: week) else {
            return goal.title
        }
        return "Anker \(number) · \(goal.title)"
    }

    private var priorityColor: Color {
        switch task.priority {
        case .a: AnkerColor.accentInk
        case .b: AnkerColor.inkSecond
        case .c: AnkerColor.inkTertiary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s2) {
            if isSelectionMode {
                Button {
                    onSelectionToggle?()
                } label: {
                    SelectionCheckmark(isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)  // optische Ausrichtung, kein Raster. design-guard: erlaubt
                .onLongPressGesture {
                    onStartSelection?()
                }
            }

            if !isSelectionMode {
                Button {
                    performToggleDone()
                } label: {
                    TaskCheckmark(isDone: task.isDone)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)  // optische Ausrichtung, kein Raster. design-guard: erlaubt
            }

            VStack(alignment: .leading, spacing: AnkerSpacing.s1 + 1) {
                TaskTitleField(
                    task: task,
                    style: AnkerType.taskTitle,
                    isEditing: $isEditingTitle,
                    onRenamed: { snapshot in
                        notifyUndo(message: "Titel geändert", snapshots: [snapshot])
                    }
                )

                // Der Anker steht als Text da, nicht als Farbpunkt oder Logo: die Zuordnung
                // ist die Kernaussage der App und soll lesbar sein.
                Text(verbatim: metaText)
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(metaColor)
                    .lineLimit(1)
            }
            // Doppelklick auf die Zeile bearbeitet den Titel an der Stelle. Bewusst nicht der
            // einfache Klick: der zieht in der Mehrfachauswahl und darf nicht zweierlei tun.
            .onTapGesture(count: 2) {
                guard isActionable && !isSelectionMode else { return }
                isEditingTitle = true
            }
            Spacer(minLength: AnkerSpacing.s2)

            // Prio-Gruppen entfallen; der Buchstabe steht rechts an der Zeile.
            if showPriority {
                Text(verbatim: task.priority.label)
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(priorityColor)
                    .padding(.top, AnkerSpacing.s1)
            }

            if isActionable && !isSelectionMode {
#if os(macOS)
                hoverActions
#endif
            }
        }
        .padding(.vertical, AnkerSpacing.s3)
        .frame(minHeight: 46)
        .contentShape(Rectangle())
        .platformTaskContextMenu {
            if isActionable && !isSelectionMode {
                taskMenuItems
            }
        } preview: {
            if isActionable && !isSelectionMode {
                TaskContextPreviewCard(task: task)
            }
        }
        .conditionalTaskDrag(task: task, isEnabled: isActionable && !isSelectionMode, isDragging: $isDragging)
#if os(iOS)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            if isActionable && !isSelectionMode {
                Button {
                    performToggleDone()
                } label: {
                    Label(task.isDone ? "Offen" : "Erledigt", ankerIcon: task.isDone ? .undo : .check)
                }
                .tint(AnkerColor.ink)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isActionable && !isSelectionMode {
                Button(role: .destructive) {
                    performDelete()
                } label: {
                    Label("Aufgabe löschen", ankerIcon: AnkerIcon.delete)
                }

                Button {
                    iOSImpact(.medium)
                    showingMoveSheet = true
                } label: {
                    Label("Verschieben", ankerIcon: AnkerIcon.week)
                }
                .tint(AnkerColor.accentInk)
            }
        }
        .accessibilityAction(named: task.isDone ? "Als offen markieren" : "Als erledigt markieren") {
            performToggleDone()
        }
        .accessibilityAction(named: "Titel ändern") {
            isEditingTitle = true
        }
        .accessibilityAction(named: "Aufgabe bearbeiten") {
            showingEditor = true
        }
        .accessibilityAction(named: "Aufgabe verschieben") {
            showingMoveSheet = true
        }
        .accessibilityAction(named: "Aufgabe löschen") {
            confirmingDelete = true
        }
#endif
        .onTapGesture {
            if isSelectionMode {
                onSelectionToggle?()
            }
        }
        .opacity(isDragging ? 0.35 : 1)
#if os(macOS)
        .onHover { isInside in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = isInside
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: TaskDragEvents.didEnd)) { notification in
            guard let rawID = notification.object as? String,
                  rawID == task.id.uuidString else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                isDragging = false
            }
        }
#endif
        .sheet(isPresented: $showingEditor) {
            TaskEditorSheet(task: task)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingMoveSheet) {
            TaskMoveSheet(tasks: [task]) { snapshots in
                notifyUndo(message: "Aufgabe verschoben", snapshots: snapshots)
            }
                .presentationDetents([.medium])
        }
        .confirmationDialog("Aufgabe löschen?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                performDelete()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aufgabe wird dauerhaft entfernt.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("taskCard")
    }

    private var hoverActions: some View {
        HStack(spacing: AnkerSpacing.s2) {
            hoverAction(
                ankerIcon: task.isDone ? .open : .check,
                tint: AnkerColor.ink,
                help: task.isDone ? "Als offen markieren (⌘.)" : "Als erledigt markieren (⌘.)"
            ) {
                performToggleDone()
            }

            hoverAction(ankerIcon: .week, tint: AnkerColor.accentFill, help: "In die nächste Woche verschieben (⌘⇧M)") {
                performMoveByDays(7)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            hoverAction(ankerIcon: .delete, tint: AnkerColor.accentMark, help: "Aufgabe löschen (⌘⌫)", isDestructive: true) {
                confirmingDelete = true
            }
        }
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .frame(width: 90, alignment: .trailing)
        .accessibilityHidden(!isHovering)
    }

    private func hoverAction(
        ankerIcon: AnkerIcon,
        tint: Color,
        help: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(ankerIcon)
                .ankerIcon(AnkerIconSize.xs)
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .ankerControl(fill: isDestructive ? tint.opacity(0.10) : AnkerColor.divider, stroke: nil)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var taskMenu: some View {
        Menu {
            taskMenuItems
        } label: {
            Image(.more)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .frame(width: 26, height: 26)
                .ankerControl()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Aufgabenaktionen")
    }

    @ViewBuilder
    private var taskMenuItems: some View {
        Button {
            performToggleDone()
        } label: {
            Label(task.isDone ? "Als offen markieren" : "Als erledigt markieren", ankerIcon: task.isDone ? .open : .checkCircle)
        }
        .keyboardShortcut(".", modifiers: .command)

        Button {
            isEditingTitle = true
        } label: {
            Label("Titel ändern", ankerIcon: AnkerIcon.edit)
        }

        Button {
            showingEditor = true
        } label: {
            Label("Bearbeiten …", ankerIcon: AnkerIcon.edit)
        }
        .keyboardShortcut("e", modifiers: .command)

        Menu {
            Button {
                let snapshot = TaskActions.snapshot(task)
                TaskActions.move(task, to: Date(), weeks: weeks, modelContext: modelContext)
                notifyUndo(message: "Aufgabe verschoben", snapshots: [snapshot])
            } label: {
                Label("Heute", ankerIcon: AnkerIcon.week)
            }

            Button {
                performMoveByDays(1)
            } label: {
                Label("Morgen", ankerIcon: AnkerIcon.tomorrow)
            }

            Menu {
                ForEach(currentWeekDates, id: \.self) { date in
                    Button {
                        performMove(to: date)
                    } label: {
                        Label(verbatim: AnkerDateFormat.weekdayLongWithDayMonth(date), ankerIcon: AnkerIcon.week)
                    }
                }
            } label: {
                Label("Diese Woche", ankerIcon: AnkerIcon.week)
            }

            Button {
                performMoveByDays(7)
            } label: {
                Label("Nächste Woche", ankerIcon: AnkerIcon.nextMonth)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

#if !os(macOS)
            Button {
                showingMoveSheet = true
            } label: {
                Label("Datum wählen ...", ankerIcon: AnkerIcon.pickDate)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
#endif
        } label: {
            Label("Verschieben", ankerIcon: AnkerIcon.move)
        }

        Menu {
            if let goals = task.day?.week?.goalList, !goals.isEmpty {
                ForEach(goals, id: \.id) { goal in
                    Button {
                        let snapshot = TaskActions.snapshot(task)
                        TaskActions.link(task, to: goal, modelContext: modelContext)
                        iOSImpact(.light)
                        notifyUndo(message: "Ziel verknüpft", snapshots: [snapshot])
                    } label: {
                        Label(verbatim: goal.title, ankerIcon: task.linkedGoal?.id == goal.id ? .check : .goal)
                    }
                }
                Divider()
            }

            Button {
                let snapshot = TaskActions.snapshot(task)
                TaskActions.link(task, to: nil, modelContext: modelContext)
                iOSImpact(.light)
                notifyUndo(message: "Ziel gelöst", snapshots: [snapshot])
            } label: {
                Label("Kein Ziel", ankerIcon: task.linkedGoal == nil ? .check : .clear)
            }
        } label: {
            Label("Mit Ziel verknüpfen", ankerIcon: AnkerIcon.goal)
        }

        Menu {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    let snapshot = TaskActions.snapshot(task)
                    TaskActions.setPriority(task, to: priority, modelContext: modelContext)
                    iOSImpact(.light)
                    notifyUndo(message: "Priorität geändert", snapshots: [snapshot])
                } label: {
                    Label("Priorität \(priority.label)", ankerIcon: task.priority == priority ? .check : .priority)
                }
                .keyboardShortcut(priority.shortcutKey, modifiers: .command)
            }
        } label: {
            Label("Priorität", ankerIcon: AnkerIcon.priority)
        }

        Button {
            if let copy = TaskActions.duplicate(task, modelContext: modelContext) {
                iOSImpact(.light)
                onUndoableAction?(TaskUndoNotice(
                    message: "Aufgabe dupliziert",
                    snapshots: [TaskActions.snapshot(copy)],
                    operation: .deleteCreated
                ))
            }
        } label: {
            Label("Duplizieren", ankerIcon: AnkerIcon.duplicate)
        }
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button(role: .destructive) {
            performDelete()
        } label: {
            Label("Aufgabe löschen", ankerIcon: AnkerIcon.delete)
        }
        .keyboardShortcut(.delete, modifiers: .command)
    }

    private var metaText: String {
        switch metaLine {
        case .anchor:
            return anchorLabel
        case .day:
            guard let date = task.day?.date else { return "Ohne Tag" }
            return AnkerCalendar.isSameDay(date, Date()) ? "Heute" : AnkerDateFormat.weekdayLongWithDayMonth(date)
        }
    }

    private var metaColor: Color {
        switch metaLine {
        case .anchor:
            return task.linkedGoal == nil ? AnkerColor.inkTertiary : AnkerColor.inkSecond
        case .day:
            let isToday = task.day.map { AnkerCalendar.isSameDay($0.date, Date()) } ?? false
            return isToday ? AnkerColor.accentInk : AnkerColor.inkSecond
        }
    }

    private var currentWeekDates: [Date] {
        guard let week = task.day?.week else { return [] }
        return AnkerCalendar.daysInWeek(starting: week.monday)
    }

    private func performToggleDone() {
        if let onToggle {
            onToggle()
            return
        }

        let snapshot = TaskActions.snapshot(task)
        withAnimation(taskAnimation) {
            TaskActions.toggleDone(task, modelContext: modelContext)
        }
        iOSImpact(.light)
        notifyUndo(message: task.isDone ? "Aufgabe erledigt" : "Aufgabe wieder offen", snapshots: [snapshot])
    }

    private func performDelete() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.delete(task, modelContext: modelContext)
        iOSNotificationSuccess()
        notifyUndo(message: "Aufgabe gelöscht", snapshots: [snapshot])
    }

    private func performMoveByDays(_ offset: Int) {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, byDays: offset, weeks: weeks, modelContext: modelContext)
        iOSImpact(.medium)
        notifyUndo(message: "Aufgabe verschoben", snapshots: [snapshot])
    }

    private func performMove(to date: Date) {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, to: date, weeks: weeks, modelContext: modelContext)
        iOSImpact(.medium)
        notifyUndo(message: "Aufgabe verschoben", snapshots: [snapshot])
    }

    private func notifyUndo(message: String, snapshots: [TaskSnapshot]) {
        guard !snapshots.isEmpty else { return }
        onUndoableAction?(TaskUndoNotice(message: message, snapshots: snapshots))
    }

    private func iOSImpact(_ style: TaskHapticStyle) {
#if os(iOS)
        switch style {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
#endif
    }

    private func iOSNotificationSuccess() {
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }

    private var taskAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.15) : .snappy
    }
}

private extension Priority {
    var shortcutKey: KeyEquivalent {
        switch self {
        case .a: "1"
        case .b: "2"
        case .c: "3"
        }
    }
}

private enum TaskHapticStyle {
    case light
    case medium
}

enum TaskDragEvents {
    static let didEnd = Notification.Name("DaiventoTaskDragDidEnd")

    static func end(taskID: UUID) {
        NotificationCenter.default.post(name: didEnd, object: taskID.uuidString)
    }
}

/// Gemeinsame Behandlung von Task-Drops. Aufgaben werden als reine UUID-Zeichenkette
/// gezogen (`conditionalTaskDrag`), also braucht jedes Drop-Ziel dieselben drei Schritte:
/// ID laden, Aufgabe verschieben, Drag-Ende melden.
enum TaskDropHandling {
    static let draggedTypes = [UTType.plainText]

    /// Laedt die Task-ID aus dem Provider und ruft `completion` auf dem Main Actor auf.
    /// Ueber die Grenze geht bewusst nur die `UUID` — Modellobjekte sind nicht `Sendable`.
    static func loadTaskID(
        from providers: [NSItemProvider],
        completion: @escaping @MainActor (UUID) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else {
            return false
        }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let rawID = object as? String ?? (object as? NSString)?.description,
                  let taskID = UUID(uuidString: rawID) else { return }

            Task { @MainActor in
                completion(taskID)
            }
        }

        return true
    }

    /// Verschiebt die Aufgabe auf `date` und meldet in jedem Fall das Drag-Ende, damit die
    /// Ursprungszeile auf macOS ihre Transparenz verliert — auch wenn die Aufgabe
    /// inzwischen geloescht wurde.
    @MainActor
    @discardableResult
    static func moveTask(
        id: UUID,
        to date: Date,
        weeks: [Week],
        modelContext: ModelContext
    ) -> TaskSnapshot? {
        defer { TaskDragEvents.end(taskID: id) }

        guard let task = task(with: id, in: weeks) else { return nil }

        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, to: date, weeks: weeks, modelContext: modelContext)
        return snapshot
    }

    /// Ziel eines Matrix-Drops. `goalID == nil` ist der Eingangskorb.
    struct MatrixTarget: Equatable, Hashable {
        let date: Date
        let goalID: UUID?
    }

    /// Wie `moveTask`, aber zweidimensional. Dieselben drei Schritte, deshalb hier und nicht
    /// als zweite Umsetzung daneben: das Drag-Nutzlast bleibt die nackte UUID, also landet
    /// **jeder** bestehende Drag (Sidebar, Tagesliste) ohne Aenderung auch in der Matrix.
    @MainActor
    @discardableResult
    static func placeTask(
        id: UUID,
        on target: MatrixTarget,
        weeks: [Week],
        modelContext: ModelContext
    ) -> TaskSnapshot? {
        defer { TaskDragEvents.end(taskID: id) }

        guard let task = task(with: id, in: weeks) else { return nil }

        let snapshot = TaskActions.snapshot(task)
        TaskActions.place(task, on: target.date, goalID: target.goalID, weeks: weeks, modelContext: modelContext)
        return snapshot
    }

    @MainActor
    private static func task(with id: UUID, in weeks: [Week]) -> AnkerTask? {
        weeks
            .lazy
            .flatMap(\.dayList)
            .flatMap(\.taskList)
            .first { $0.id == id }
    }
}

private struct TaskContextPreviewCard: View {
    let task: AnkerTask

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            HStack(spacing: AnkerSpacing.s2) {
                PriorityTag(priority: task.priority)
                TaskCheckmark(isDone: task.isDone)
                Spacer(minLength: 0)
            }

            Text(task.title)
                .ankerType(AnkerType.bodyStrong)
                .foregroundStyle(AnkerColor.ink)
                .lineLimit(3)

            if let goal = task.linkedGoal {
                HStack(spacing: AnkerSpacing.s1) {
                    Image(.goal)
                        .ankerType(AnkerType.caption)
                    Text(goal.title)
                        .lineLimit(1)
                }
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.accentInk)
            }
        }
        .padding(AnkerSpacing.s4)
        .frame(width: 260, alignment: .leading)
        .ankerCard()
    }
}

private struct TaskDragPreviewCard: View {
    let task: AnkerTask

    var body: some View {
        HStack(spacing: AnkerSpacing.s2) {
            PriorityTag(priority: task.priority)
            TaskCheckmark(isDone: task.isDone)
            Text(task.title)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s3)
        .frame(width: 230, alignment: .leading)
        .ankerCard()
    }
}

private struct SelectionCheckmark: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous)
            .fill(isSelected ? AnkerColor.accentFill : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous).stroke(isSelected ? AnkerColor.accentFill : AnkerColor.dividerStrong,
                                   lineWidth: AnkerBorder.rule)
            )
            .overlay {
                if isSelected {
                    Image(.check)
                        .ankerIcon(AnkerIconSize.xs)
                        .foregroundStyle(AnkerColor.onAccent)
                }
            }
            .frame(width: 20, height: 20)
            .contentShape(RoundedRectangle(cornerRadius: AnkerRadius.check, style: .continuous))
            .accessibilityLabel(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
    }
}

/// Nicht `private`: `AnkerMatrixView` braucht denselben Drag-Helfer, und eine zweite
/// Umsetzung daneben waere genau die Doppelung, die `TaskDropHandling` vermeidet.
extension View {
    @ViewBuilder
    func platformTaskContextMenu<MenuItems: View, Preview: View>(
        @ViewBuilder menuItems: @escaping () -> MenuItems,
        @ViewBuilder preview: @escaping () -> Preview
    ) -> some View {
#if os(macOS)
        self.contextMenu(menuItems: menuItems)
#else
        self.contextMenu(menuItems: menuItems, preview: preview)
#endif
    }

    @ViewBuilder
    func conditionalTaskDrag(task: AnkerTask, isEnabled: Bool, isDragging: Binding<Bool>) -> some View {
        if isEnabled {
#if os(macOS)
            self.onDrag {
                withAnimation(.easeOut(duration: 0.12)) {
                    isDragging.wrappedValue = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    if isDragging.wrappedValue {
                        withAnimation(.easeOut(duration: 0.12)) {
                            isDragging.wrappedValue = false
                        }
                    }
                }
                return NSItemProvider(object: task.id.uuidString as NSString)
            } preview: {
                TaskDragPreviewCard(task: task)
            }
#else
            self.onDrag {
                NSItemProvider(object: task.id.uuidString as NSString)
            }
#endif
        } else {
            self
        }
    }
}

/// Ein Anker als Zeile: Nummer, Titel, Fortschrittsbalken, Bruch.
///
/// Der Entwurf zeigt diese Zeile auf Heute (filterbar), im Rueckblick und in der Ankerspalte
/// der Matrix. Ein Baustein statt drei Kopien.
struct AnchorRow: View {
    let number: Int
    let title: String
    let doneCount: Int
    let totalCount: Int
    var tint: Color = AnkerColor.ink
    var isActive = false

    private var progress: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    private var fraction: String {
        totalCount == 0 ? "—" : "\(doneCount)/\(totalCount)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s3) {
            Text(verbatim: String(number))
                .ankerType(AnkerType.numeric)
                .foregroundStyle(isActive ? AnkerColor.accentInk : AnkerColor.ink)
                .frame(width: 20, alignment: .leading)

            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                Text(verbatim: title)
                    .ankerType(isActive ? AnkerType.subheadline : AnkerType.bodyStrong)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                AnkerProgressBar(progress: progress, tint: tint, thickness: AnkerBorder.rule * 2)
            }

            Text(verbatim: fraction)
                .ankerType(AnkerType.numericSmall)
                .foregroundStyle(AnkerColor.inkSecond)
        }
        .padding(.vertical, AnkerSpacing.s2 + 1)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Anker \(number), \(title), \(doneCount) von \(totalCount) erledigt")
    }
}

struct ChipButton: View {
    let title: String
    var isPrimary = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .ankerType(AnkerType.caption)
                .foregroundStyle(isPrimary ? AnkerColor.onAccent : AnkerColor.inkSecond)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s2)
                .ankerControl(
                    fill: isPrimary ? AnkerColor.accentFill : AnkerColor.surface,
                    stroke: isPrimary ? nil : AnkerColor.divider
                )
        }
        .buttonStyle(.plain)
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppDestination

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, title: "Heute", ankerIcon: AnkerIcon.today)
            tab(.week, title: "Woche", ankerIcon: AnkerIcon.week)
            tab(.year, title: "Jahr", ankerIcon: AnkerIcon.year)
            tab(.review, title: "Mehr", ankerIcon: AnkerIcon.more)
        }
        .padding(AnkerSpacing.s1)
        .background(AnkerColor.surface.opacity(0.96), in: Rectangle())
        .overlay(Rectangle().stroke(AnkerColor.divider, lineWidth: AnkerBorder.rule))
        .accessibilityElement(children: .contain)
    }

    private func tab(_ destination: AppDestination, title: String, ankerIcon: AnkerIcon) -> some View {
        Button {
            selection = destination
        } label: {
            VStack(spacing: AnkerSpacing.s1) {
                Image(ankerIcon).ankerIcon(AnkerIconSize.m)
                Text(title)
                    .ankerType(AnkerType.microLabel)
            }
            .foregroundStyle(isSelected(destination) ? AnkerColor.accentInk : AnkerColor.inkSecond)
            // 44pt Mindesthoehe ist Apples Zielgroesse; die Pille darunter ist das
            // anfassbare Objekt und deshalb rund.
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, AnkerSpacing.s1)
            .background(
                isSelected(destination) ? AnkerColor.accent[100] : Color.clear,
                in: RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func isSelected(_ destination: AppDestination) -> Bool {
        switch (selection, destination) {
        case (.today, .today), (.week, .week), (.year, .year), (.review, .review):
            true
        default:
            false
        }
    }
}

