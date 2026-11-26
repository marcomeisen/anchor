import SwiftData
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

/// Ein Literal am Aufrufort wird übersetzt, eine `String`-Variable wörtlich gesetzt.
struct SectionLabel: View {
    private let title: Text

    init(title: LocalizedStringKey) {
        self.title = Text(title)
    }

    @_disfavoredOverload
    init<Title: StringProtocol>(title: Title) {
        self.title = Text(verbatim: String(title))
    }

    var body: some View {
        title
            .ankerType(AnkerType.overline)
            .foregroundStyle(AnkerColor.inkSecond)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AnkerSpacing.s4)
            .padding(.bottom, AnkerSpacing.s2)
    }
}

struct TaskCheckmark: View {
    let isDone: Bool
    /// Die Tagesliste hat Platz fuer 22pt, der Matrixchip in einer 108pt-Spalte nicht.
    var size: CGFloat = 22

    var body: some View {
        // Erledigt ist blau gefüllt — das eine Blau von „Blatt" heißt genau das. Offen eine
        // 2pt-Kante in Tinte: das Kästchen ist ein Bedienelement und muss als solches lesbar sein.
        RoundedRectangle(cornerRadius: AnkerRadius.check(size: size), style: .continuous)
            .fill(isDone ? AnkerColor.accentFill : Color.clear)
            .overlay {
                if !isDone {
                    RoundedRectangle(cornerRadius: AnkerRadius.check(size: size), style: .continuous)
                        .strokeBorder(AnkerColor.ink, lineWidth: AnkerBorder.heavy)
                }
            }
            .overlay {
                if isDone {
                    Image(.check)
                        .ankerIcon(size * 0.6)
                        .foregroundStyle(AnkerColor.onAccent)
                }
            }
            .frame(width: size, height: size)
            .contentShape(RoundedRectangle(cornerRadius: AnkerRadius.check(size: size), style: .continuous))
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

    /// Was in der Metazeile steht.
    ///
    /// In der Tagesliste ist der **Anker** die Aussage — die Zuordnung ist der Kern der App. Im
    /// Ankerdetail haben alle Aufgaben denselben Anker; dort ist der **Tag** die Information.
    /// `.none`: nur der Titel, die Ankernummer steht dann rechts (`showsAnchorNumber`).
    enum MetaLine { case anchor, day, none }

    let task: AnkerTask
    var showPriority = true
    var metaLine: MetaLine = .anchor
    /// Die Nummer des Ankers rechts an der Zeile — so zeigt „Blatt" die Zuordnung.
    var showsAnchorNumber = false
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

    /// Aufgaben ohne Tag sind vollwertig: nur was sich auf *ihren* Tag bezieht (Morgen, ein
    /// Tag dieser Woche), entfällt — sie haben keinen.
    private var hasDay: Bool {
        task.day != nil
    }

    /// Die Woche, zu der die Aufgabe gehört: über ihren Tag oder, ohne Tag, über ihren Anker.
    private var owningWeek: Week? {
        task.day?.week ?? task.linkedGoal?.week
    }

    /// „Anker 2 · Security-Review" oder „Ohne Anker".
    private var anchorLabel: String {
        guard let goal = task.linkedGoal else { return String(localized: "Ohne Anker") }
        guard let week = goal.week,
              let number = GoalOrdering.anchorNumber(of: goal, in: week) else {
            return goal.title
        }
        return String(localized: "Anker \(number) · \(goal.title)")
    }

    private var priorityColor: Color {
        switch task.priority {
        case .a: AnkerColor.ink
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
                        .ankerTapTarget(20)
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
                    // Die Hauptaktion der Zeile: auf dem iPhone 44pt Tippfläche um das 22pt-Kästchen.
                    TaskCheckmark(isDone: task.isDone)
                        .ankerTapTarget(22)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)  // optische Ausrichtung, kein Raster. design-guard: erlaubt
                // Kein langes Drücken am Kästchen: es lief gleichzeitig mit dem Kontextmenü der
                // Karte, und beim Loslassen hakte der Knopf die Aufgabe zusätzlich ab. Die
                // Mehrfachauswahl beginnt über „Auswählen" im Kontextmenü oder neben dem Abschnitt.
                .accessibilityLabel(task.isDone ? "Erledigt" : "Offen")
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

                if metaLine != .none {
                    Text(verbatim: metaText)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(metaColor)
                        .lineLimit(1)
                }
            }
            // Doppelklick auf den Titel bearbeitet ihn an der Stelle. Bewusst nicht der
            // einfache Klick: der zieht in der Mehrfachauswahl und darf nicht zweierlei tun.
            .onTapGesture(count: 2) {
                guard !isSelectionMode else { return }
                isEditingTitle = true
            }
            Spacer(minLength: AnkerSpacing.s2)

            if let rule = task.recurrence {
                TaskRecurrenceMark(rule: rule)
                    .padding(.top, AnkerSpacing.s1)
            }

            // Prio-Gruppen entfallen; der Buchstabe steht rechts an der Zeile.
            if showPriority {
                Text(verbatim: task.priority.label)
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(priorityColor)
                    .padding(.top, AnkerSpacing.s1)
            }

            if !isSelectionMode {
#if os(macOS)
                hoverActions
#endif
            }

            // Die Nummer steht ganz rechts, auch wenn die Hover-Aktionen erscheinen.
            if showsAnchorNumber {
                Text(verbatim: anchorNumberText)
                    .ankerType(AnkerType.bodyStrong)
                    .monospacedDigit()
                    .foregroundStyle(task.linkedGoal == nil ? AnkerColor.inkTertiary : AnkerColor.ink)
                    .padding(.top, AnkerSpacing.s0)
                    .accessibilityLabel(anchorLabel)
            }
        }
        .padding(.vertical, AnkerSpacing.s3)
        .frame(minHeight: 46)
        .contentShape(Rectangle())
        .platformTaskContextMenu {
            if !isSelectionMode {
                taskMenuItems
            }
        } preview: {
            if !isSelectionMode {
                TaskContextPreviewCard(task: task)
            }
        }
        .conditionalTaskDrag(task: task, isEnabled: !isSelectionMode, isDragging: $isDragging)
#if os(iOS)
        // `.swipeActions` wirkt nur in einer `List`; die Zeilen stehen aber in `ScrollView`s.
        .taskSwipe(isEnabled: !isSelectionMode, isDone: task.isDone,
                   onDone: performToggleDone, onDelete: performDelete)
#endif
        .accessibilityAction(named: task.isDone ? "Als offen markieren" : "Als erledigt markieren") {
            performToggleDone()
        }
        .accessibilityAction(named: "Titel ändern") {
            isEditingTitle = true
        }
        .accessibilityAction(named: "Aufgabe bearbeiten") {
            showingEditor = true
        }
        .accessibilityAction(named: hasDay ? "Aufgabe verschieben" : "Tag wählen") {
            showingMoveSheet = true
        }
        .accessibilityAction(named: "In die nächste Woche") {
            performMoveToNextWeek()
        }
        .accessibilityAction(named: "Aufgabe löschen") {
            confirmingDelete = true
        }
        .accessibilityActions {
            TaskRecurrenceAccessibilityActions(task: task, perform: performSetRecurrence)
        }
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
            TaskEditorSheet(task: task, onUndoableAction: onUndoableAction)
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

    /// Drei Knöpfe, die beim Überfahren erscheinen. **Ohne** Tastenkürzel: jede Zeile trüge
    /// sonst dasselbe Kürzel, und mit vielen Zeilen wäre es mehrdeutig.
    private var hoverActions: some View {
        HStack(spacing: AnkerSpacing.s2) {
            hoverAction(
                ankerIcon: task.isDone ? .open : .check,
                help: task.isDone ? "Als offen markieren" : "Als erledigt markieren"
            ) {
                performToggleDone()
            }

            hoverAction(ankerIcon: .week, help: "In die nächste Woche verschieben") {
                performMoveToNextWeek()
            }

            hoverAction(ankerIcon: .delete, help: "Aufgabe löschen") {
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
        help: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(ankerIcon)
                .ankerIcon(AnkerIconSize.xs)
                .foregroundStyle(AnkerColor.ink)
                .frame(width: 26, height: 26)
                .ankerControl(fill: AnkerColor.divider, stroke: nil)
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    /// Die vollständige Handlungsmenge. Bewusst **ohne** Tastenkürzel: Einträge eines
    /// Kontextmenüs greifen nur, solange das Menü offen ist — ein angezeigtes ⌘. versprach
    /// etwas, das in der Liste nie funktionierte.
    @ViewBuilder
    private var taskMenuItems: some View {
        Button {
            performToggleDone()
        } label: {
            Label(task.isDone ? "Als offen markieren" : "Als erledigt markieren", ankerIcon: task.isDone ? .open : .checkCircle)
        }

        Button {
            isEditingTitle = true
        } label: {
            Label("Titel ändern", ankerIcon: AnkerIcon.edit)
        }

        if let onStartSelection {
            Button {
                iOSImpact(.medium)
                onStartSelection()
            } label: {
                Label("Auswählen", ankerIcon: AnkerIcon.checkCircle)
            }
        }

        Button {
            showingEditor = true
        } label: {
            Label("Bearbeiten …", ankerIcon: AnkerIcon.edit)
        }

        Menu {
            Button {
                performMove(to: Date())
            } label: {
                Label("Heute", ankerIcon: AnkerIcon.today)
            }

            if hasDay {
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
            }

            Button {
                performMoveToNextWeek()
            } label: {
                Label("Nächste Woche", ankerIcon: AnkerIcon.nextMonth)
            }

            Button {
                showingMoveSheet = true
            } label: {
                Label(hasDay ? "Datum wählen …" : "Tag wählen …", ankerIcon: AnkerIcon.pickDate)
            }

            if hasDay {
                Divider()
                Button {
                    let snapshot = TaskActions.snapshot(task)
                    TaskActions.unschedule(task, modelContext: modelContext)
                    iOSImpact(.medium)
                    notifyUndo(message: "Ohne Tag", snapshots: [snapshot])
                } label: {
                    Label("Ohne Tag", ankerIcon: AnkerIcon.clear)
                }
            }
        } label: {
            Label("Verschieben", ankerIcon: AnkerIcon.move)
        }

        Menu {
            if let week = owningWeek {
                let anchors = GoalOrdering.anchors(in: week)
                ForEach(Array(anchors.enumerated()), id: \.element.id) { index, goal in
                    Button {
                        performLink(goal)
                    } label: {
                        Label(verbatim: "\(index + 1) · \(goal.title)", ankerIcon: task.linkedGoal?.id == goal.id ? .check : .goal)
                    }
                }
                if !anchors.isEmpty {
                    Divider()
                }
            }

            Button {
                performLink(nil)
            } label: {
                Label("Ohne Anker", ankerIcon: task.linkedGoal == nil ? .check : .clear)
            }
        } label: {
            Label("Anker wählen", ankerIcon: AnkerIcon.goal)
        }

        TaskRecurrenceMenu(current: task.recurrence, perform: performSetRecurrence)

        Button {
            let snapshot = TaskActions.snapshot(task)
            let isImportant = task.priority == .a
            TaskActions.setPriority(task, to: isImportant ? .b : .a, modelContext: modelContext)
            iOSImpact(.light)
            notifyUndo(message: isImportant ? "Nicht mehr wichtig" : "Als wichtig markiert", snapshots: [snapshot])
        } label: {
            Label(task.priority == .a ? "Nicht mehr wichtig" : "Als wichtig markieren", ankerIcon: AnkerIcon.priority)
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

        Divider()

        Button(role: .destructive) {
            performDelete()
        } label: {
            Label("Aufgabe löschen", ankerIcon: AnkerIcon.delete)
        }
    }

    private var anchorNumberText: String {
        guard let goal = task.linkedGoal, let week = goal.week,
              let number = GoalOrdering.anchorNumber(of: goal, in: week) else { return "–" }
        return "\(number)"
    }

    private var metaText: String {
        switch metaLine {
        case .none:
            return ""
        case .anchor:
            return anchorLabel
        case .day:
            guard let day = task.day else { return String(localized: "Ohne Tag") }
            let date = AnkerCalendar.nominalDate(of: day)
            return AnkerCalendar.isSameDay(date, Date()) ? String(localized: "Heute") : AnkerDateFormat.weekdayLongWithDayMonth(date)
        }
    }

    private var metaColor: Color {
        switch metaLine {
        case .none:
            return AnkerColor.inkSecond
        case .anchor:
            return task.linkedGoal == nil ? AnkerColor.inkTertiary : AnkerColor.inkSecond
        case .day:
            let isToday = task.day.map { AnkerCalendar.storedDay($0, isOn: Date()) } ?? false
            return isToday ? AnkerColor.accentInk : AnkerColor.inkSecond
        }
    }

    private var currentWeekDates: [Date] {
        guard let week = task.day?.week else { return [] }
        // Der gemeinte Montag — sonst bot das Menü westlich der anlegenden Zone So–Sa an.
        return AnkerCalendar.daysInWeek(starting: week.nominalMonday)
    }

    private func performToggleDone() {
        if let onToggle {
            onToggle()
            return
        }

        let snapshot = TaskActions.snapshot(task)
        var next: AnkerTask?
        withAnimation(taskAnimation) {
            next = TaskActions.toggleDone(task, modelContext: modelContext)
        }
        iOSImpact(.light)
        if let message = TaskRecurrenceText.spawnedMessage(for: next) {
            onUndoableAction?(TaskUndoNotice(message: message, snapshots: [snapshot]))
        } else {
            notifyUndo(message: task.isDone ? "Aufgabe erledigt" : "Aufgabe wieder offen", snapshots: [snapshot])
        }
    }

    private func performSetRecurrence(_ rule: TaskRecurrence?) {
        let snapshot = TaskActions.snapshot(task)
        guard TaskActions.setRecurrence(task, to: rule, modelContext: modelContext) else { return }
        iOSImpact(.light)
        notifyUndo(message: rule == nil ? "Wiederholung beendet" : "Wiederholung gesetzt", snapshots: [snapshot])
    }

    private func performDelete() {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.delete(task, modelContext: modelContext)
        iOSNotificationSuccess()
        notifyUndo(message: "Aufgabe gelöscht", snapshots: [snapshot])
    }

    // `weeks: []` — `TaskActions.ensureWeek` sucht dann per Abfrage über ISO-Jahr und -Woche.
    // Eine `@Query` über alle Wochen in **jeder** Zeile kostete bei jeder Änderung einen
    // Neuaufbau der ganzen Liste.

    private func performMoveByDays(_ offset: Int) {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, byDays: offset, weeks: [], modelContext: modelContext)
        iOSImpact(.medium)
        notifyUndo(message: "Aufgabe verschoben", snapshots: [snapshot])
    }

    private func performMove(to date: Date) {
        let snapshot = TaskActions.snapshot(task)
        TaskActions.move(task, to: date, weeks: [], modelContext: modelContext)
        iOSImpact(.medium)
        notifyUndo(message: "Aufgabe verschoben", snapshots: [snapshot])
    }

    /// Derselbe Wochentag eine Woche später; ohne Tag der Montag der Woche nach ihrer
    /// Ankerwoche (bzw. nach der laufenden Woche im Eingang).
    private func performMoveToNextWeek() {
        let snapshot = TaskActions.snapshot(task)
        let base = task.day.map { AnkerCalendar.nominalDate(of: $0) } ?? owningWeek?.nominalMonday ?? Date()
        let monday = AnkerCalendar.weekInterval(containing: base).monday
        guard let next = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: monday) else { return }
        TaskActions.move(task, toWeekStarting: next, weeks: [], modelContext: modelContext)
        iOSImpact(.medium)
        notifyUndo(message: "In die nächste Woche verschoben", snapshots: [snapshot])
    }

    private func performLink(_ goal: Goal?) {
        guard task.linkedGoal?.id != goal?.id else { return }
        let snapshot = TaskActions.snapshot(task)
        TaskActions.link(task, to: goal, modelContext: modelContext)
        iOSImpact(.light)
        notifyUndo(message: goal == nil ? "Anker gelöst" : "Anker gesetzt", snapshots: [snapshot])
    }

    private func notifyUndo(message: LocalizedStringResource, snapshots: [TaskSnapshot]) {
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

// MARK: - Wiederholen

/// Das kleine Wiederhol-Symbol an `TaskCard` und `TaskChip`: Tinte, keine Farbe — die eine
/// Farbe heißt „erledigt" oder „heute", nicht „wiederholt sich".
struct TaskRecurrenceMark: View {
    let rule: TaskRecurrence
    var size: CGFloat = AnkerIconSize.xs

    var body: some View {
        Image(.refresh)
            .ankerIcon(size)
            .foregroundStyle(AnkerColor.inkSecond)
            .accessibilityLabel(rule.accessibilityDescription)
    }
}

/// „Wiederholen ▸" im Kontextmenü: Nie und die fünf Regeln, die gesetzte mit Haken.
struct TaskRecurrenceMenu: View {
    let current: TaskRecurrence?
    let perform: (TaskRecurrence?) -> Void

    var body: some View {
        Menu {
            Button {
                perform(nil)
            } label: {
                Label("Nie", ankerIcon: current == nil ? .check : .clear)
            }
            Divider()
            ForEach(TaskRecurrence.allCases) { rule in
                Button {
                    perform(rule)
                } label: {
                    Label(verbatim: rule.label, ankerIcon: current == rule ? .check : .refresh)
                }
            }
        } label: {
            Label("Wiederholen", ankerIcon: AnkerIcon.refresh)
        }
    }
}

/// Dieselben Einträge als Bedienungshilfen-Aktionen.
struct TaskRecurrenceAccessibilityActions: View {
    let task: AnkerTask
    let perform: (TaskRecurrence?) -> Void

    var body: some View {
        ForEach(TaskRecurrence.allCases.filter { $0 != task.recurrence }) { rule in
            Button("Wiederholen: \(rule.label)") { perform(rule) }
        }
        if task.recurrence != nil {
            Button("Nicht mehr wiederholen") { perform(nil) }
        }
    }
}

enum TaskRecurrenceText {
    /// Der Rückgängig-Hinweis, wenn das Abhaken eine Folgeinstanz erzeugt hat — er nennt, wann
    /// sie wiederkommt.
    static func spawnedMessage(for next: AnkerTask?) -> String? {
        guard let stored = next?.day else { return nil }
        let date = AnkerCalendar.nominalDate(of: stored)
        return String(localized: "Erledigt – wieder am \(AnkerDateFormat.weekdayShortWithDayMonth(date))")
    }
}

private enum TaskHapticStyle {
    case light
    case medium
}

extension View {
    /// Eine Tippfläche von mindestens 44 pt auf dem iPhone, ohne dass sich Optik oder Layout
    /// ändern: der Rahmen wächst, ein negativer Rand gibt den Platz im Layout zurück.
    /// Auf dem Mac bleibt es beim sichtbaren Maß — dort zielt ein Zeiger, kein Finger.
    @ViewBuilder
    func ankerTapTarget(_ visibleSize: CGFloat, minimum: CGFloat = 44) -> some View {
#if os(iOS)
        let inset = max(0, (minimum - visibleSize) / 2)
        self
            .frame(width: visibleSize + inset * 2, height: visibleSize + inset * 2)
            .contentShape(Rectangle())
            .padding(-inset)
#else
        self.contentShape(Rectangle())
#endif
    }
}

private struct TaskContextPreviewCard: View {
    let task: AnkerTask

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            TaskCheckmark(isDone: task.isDone)

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
                .foregroundStyle(AnkerColor.inkSecond)
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
