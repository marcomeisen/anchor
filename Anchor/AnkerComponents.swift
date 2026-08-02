import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AnchorGlyph: View {
    var stroke: Color = .white

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let lineWidth = max(side * 0.08, 1.2)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                Circle()
                    .stroke(stroke, lineWidth: lineWidth)
                    .frame(width: side * 0.24, height: side * 0.24)
                    .position(x: center.x, y: center.y - side * 0.28)

                Path { path in
                    path.move(to: CGPoint(x: center.x, y: center.y - side * 0.16))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + side * 0.28))

                    path.move(to: CGPoint(x: center.x - side * 0.20, y: center.y + side * 0.02))
                    path.addLine(to: CGPoint(x: center.x + side * 0.20, y: center.y + side * 0.02))

                    path.move(to: CGPoint(x: center.x - side * 0.34, y: center.y + side * 0.14))
                    path.addLine(to: CGPoint(x: center.x - side * 0.23, y: center.y + side * 0.27))
                    path.addQuadCurve(
                        to: CGPoint(x: center.x, y: center.y + side * 0.32),
                        control: CGPoint(x: center.x - side * 0.08, y: center.y + side * 0.36)
                    )
                    path.addQuadCurve(
                        to: CGPoint(x: center.x + side * 0.23, y: center.y + side * 0.27),
                        control: CGPoint(x: center.x + side * 0.08, y: center.y + side * 0.36)
                    )
                    path.addLine(to: CGPoint(x: center.x + side * 0.34, y: center.y + side * 0.14))
                }
                .stroke(stroke, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

struct FyndaraLogo: View {
    var body: some View {
        Image("FokusringB")
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

struct AnchorBadge: View {
    var color: Color = AnkerColor.indigo

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color.opacity(0.12))
            .frame(width: 26, height: 26)
            .overlay(FyndaraLogo().padding(3))
    }
}

struct SectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AnkerColor.muted)
            .textCase(.uppercase)
            .tracking(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }
}

struct ProgressRing: View {
    let progress: Double
    var color: Color = AnkerColor.indigo
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(AnkerColor.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel(Text("\(Int(progress * 100)) Prozent erreicht"))
    }
}

struct GoalBanner: View {
    let label: String
    let title: String
    var badgeColor: Color = AnkerColor.indigo
    var background: LinearGradient = LinearGradient(
        colors: [
            Color(light: "#EEF0FF", dark: "#1C1D24"),
            Color(light: "#F7F1E4", dark: "#23242D")
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        HStack(spacing: 10) {
            AnchorBadge(color: badgeColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(label.uppercased())
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(AnkerColor.indigoText)
                    .tracking(0.57)
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 13)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: AnkerRadius.pill)
                .stroke(AnkerColor.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.pill))
        .accessibilityElement(children: .combine)
    }
}

struct PriorityTag: View {
    let priority: Priority

    var color: Color {
        switch priority {
        case .a: AnkerColor.prioA
        case .b: AnkerColor.indigoBadge
        case .c: AnkerColor.prioC
        }
    }

    var body: some View {
        Text(priority.label)
            .font(.system(size: 9, weight: .heavy))
            .foregroundStyle(.white)
            .tracking(0.27)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 5))
            .accessibilityLabel("Priorität \(priority.label)")
    }
}

struct TaskCheckmark: View {
    let isDone: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isDone ? AnkerColor.success : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isDone ? AnkerColor.success : AnkerColor.line, lineWidth: 1.6)
            )
            .overlay {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 17, height: 17)
            .accessibilityLabel(isDone ? "Erledigt" : "Offen")
    }
}

struct TaskCard: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Week.monday) private var weeks: [Week]

    let task: AnkerTask
    var showPriority = true
    var onToggle: (() -> Void)?
    var isSelectionMode = false
    var isSelected = false
    var onSelectionToggle: (() -> Void)?
    var onStartSelection: (() -> Void)?
    var onUndoableAction: ((TaskUndoNotice) -> Void)?

    @State private var showingEditor = false
    @State private var showingMoveSheet = false
    @State private var confirmingDelete = false
    @State private var isHovering = false
    @State private var isDragging = false

    private var isActionable: Bool {
        task.day != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if isSelectionMode {
                Button {
                    onSelectionToggle?()
                } label: {
                    SelectionCheckmark(isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
                .onLongPressGesture {
                    onStartSelection?()
                }
            }

            if showPriority {
                PriorityTag(priority: task.priority)
                    .padding(.top, 1)
            }

            if !isSelectionMode {
                Button {
                    performToggleDone()
                } label: {
                    TaskCheckmark(isDone: task.isDone)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .strikethrough(task.isDone, color: AnkerColor.muted)
                    .lineLimit(3)

                if let goal = task.linkedGoal {
                    HStack(spacing: 4) {
                        FyndaraLogo()
                            .frame(width: 10, height: 10)
                        Text(goal.title)
                            .lineLimit(1)
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AnkerColor.indigoText)
                    .accessibilityLabel("Zugeordnet zu \(goal.title)")
                }
            }
            Spacer(minLength: 0)

            if isActionable && !isSelectionMode {
#if os(macOS)
                hoverActions
#else
                taskMenu
#endif
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 10)
        .background(AnkerColor.card)
        .overlay(
            RoundedRectangle(cornerRadius: AnkerRadius.card)
                .stroke(AnkerColor.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
        .overlay {
            if isHovering && isActionable {
                RoundedRectangle(cornerRadius: AnkerRadius.card)
                    .stroke(AnkerColor.indigo.opacity(0.34), lineWidth: 1.5)
            }
        }
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
                    Label(task.isDone ? "Offen" : "Erledigt", systemImage: task.isDone ? "arrow.uturn.backward" : "checkmark")
                }
                .tint(AnkerColor.success)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if isActionable && !isSelectionMode {
                Button(role: .destructive) {
                    performDelete()
                } label: {
                    Label("Aufgabe löschen", systemImage: "trash")
                }

                Button {
                    iOSImpact(.medium)
                    showingMoveSheet = true
                } label: {
                    Label("Verschieben", systemImage: "calendar")
                }
                .tint(AnkerColor.indigo)
            }
        }
        .accessibilityAction(named: task.isDone ? "Als offen markieren" : "Als erledigt markieren") {
            performToggleDone()
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
    }

    private var hoverActions: some View {
        HStack(spacing: 6) {
            hoverAction(
                systemName: task.isDone ? "circle" : "checkmark",
                tint: AnkerColor.success,
                help: task.isDone ? "Als offen markieren (⌘.)" : "Als erledigt markieren (⌘.)"
            ) {
                performToggleDone()
            }

            hoverAction(systemName: "calendar", tint: AnkerColor.indigo, help: "In die nächste Woche verschieben (⌘⇧M)") {
                performMoveByDays(7)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            hoverAction(systemName: "trash", tint: Color(hex: "#E0392E"), help: "Aufgabe löschen (⌘⌫)", isDestructive: true) {
                confirmingDelete = true
            }
        }
        .opacity(isHovering ? 1 : 0)
        .allowsHitTesting(isHovering)
        .frame(width: 90, alignment: .trailing)
        .accessibilityHidden(!isHovering)
    }

    private func hoverAction(
        systemName: String,
        tint: Color,
        help: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background((isDestructive ? tint.opacity(0.10) : AnkerColor.lineSoft), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var taskMenu: some View {
        Menu {
            taskMenuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AnkerColor.muted)
                .frame(width: 26, height: 26)
                .background(AnkerColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AnkerColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Aufgabenaktionen")
    }

    @ViewBuilder
    private var taskMenuItems: some View {
        Button {
            performToggleDone()
        } label: {
            Label(task.isDone ? "Als offen markieren" : "Als erledigt markieren", systemImage: task.isDone ? "circle" : "checkmark.circle")
        }
        .keyboardShortcut(".", modifiers: .command)

        Menu {
            Button {
                let snapshot = TaskActions.snapshot(task)
                TaskActions.move(task, to: Date(), weeks: weeks, modelContext: modelContext)
                notifyUndo(message: "Aufgabe verschoben", snapshots: [snapshot])
            } label: {
                Label("Heute", systemImage: "calendar")
            }

            Button {
                performMoveByDays(1)
            } label: {
                Label("Morgen", systemImage: "sunrise")
            }

            Menu {
                ForEach(currentWeekDates, id: \.self) { date in
                    Button {
                        performMove(to: date)
                    } label: {
                        Label(date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide).day().month()), systemImage: "calendar")
                    }
                }
            } label: {
                Label("Diese Woche", systemImage: "calendar")
            }

            Button {
                performMoveByDays(7)
            } label: {
                Label("Nächste Woche", systemImage: "calendar.badge.plus")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

#if !os(macOS)
            Button {
                showingMoveSheet = true
            } label: {
                Label("Datum wählen ...", systemImage: "calendar.badge.clock")
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
#endif
        } label: {
            Label("Verschieben", systemImage: "arrow.right.square")
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
                        Label(goal.title, systemImage: task.linkedGoal?.id == goal.id ? "checkmark" : "target")
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
                Label("Kein Ziel", systemImage: task.linkedGoal == nil ? "checkmark" : "xmark.circle")
            }
        } label: {
            Label("Mit Ziel verknüpfen", systemImage: "target")
        }

        Menu {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    let snapshot = TaskActions.snapshot(task)
                    TaskActions.setPriority(task, to: priority, modelContext: modelContext)
                    iOSImpact(.light)
                    notifyUndo(message: "Priorität geändert", snapshots: [snapshot])
                } label: {
                    Label("Priorität \(priority.label)", systemImage: task.priority == priority ? "checkmark" : "flag")
                }
                .keyboardShortcut(priority.shortcutKey, modifiers: .command)
            }
        } label: {
            Label("Priorität", systemImage: "flag")
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
            Label("Duplizieren", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button(role: .destructive) {
            performDelete()
        } label: {
            Label("Aufgabe löschen", systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: .command)
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
    static let didEnd = Notification.Name("FyndaraTaskDragDidEnd")

    static func end(taskID: UUID) {
        NotificationCenter.default.post(name: didEnd, object: taskID.uuidString)
    }
}

private struct TaskContextPreviewCard: View {
    let task: AnkerTask

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                PriorityTag(priority: task.priority)
                TaskCheckmark(isDone: task.isDone)
                Spacer(minLength: 0)
            }

            Text(task.title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
                .lineLimit(3)

            if let goal = task.linkedGoal {
                HStack(spacing: 5) {
                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .bold))
                    Text(goal.title)
                        .lineLimit(1)
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(AnkerColor.indigoText)
            }
        }
        .padding(14)
        .frame(width: 260, alignment: .leading)
        .background(AnkerColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct TaskDragPreviewCard: View {
    let task: AnkerTask

    var body: some View {
        HStack(spacing: 9) {
            PriorityTag(priority: task.priority)
            TaskCheckmark(isDone: task.isDone)
            Text(task.title)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(width: 230, alignment: .leading)
        .background(AnkerColor.card)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

private struct SelectionCheckmark: View {
    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? AnkerColor.indigo : Color.clear)
            .overlay(Circle().stroke(isSelected ? AnkerColor.indigo : AnkerColor.line, lineWidth: 1.6))
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 20, height: 20)
            .accessibilityLabel(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
    }
}

private extension View {
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

struct WeekDot: View {
    let date: Date
    let isActive: Bool
    let hasGoal: Bool

    private var weekday: String {
        date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated))
            .replacing(".", with: "")
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(weekday)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)

            ZStack(alignment: .bottom) {
                Text(date.formatted(.dateTime.day(.twoDigits)))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnkerColor.ink)
                    .frame(width: 28, height: 28)
                    .background(
                        isActive
                            ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#96A6F2"), AnkerColor.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(AnkerColor.surfaceRaised),
                        in: Circle()
                    )
                    .overlay(Circle().stroke(isActive ? Color.clear : AnkerColor.line, lineWidth: 1))
                    .overlay {
                        if isActive {
                            Circle()
                                .stroke(AnkerColor.card, lineWidth: 2)
                                .padding(-2)
                            Circle()
                                .stroke(AnkerColor.month[0], lineWidth: 1.5)
                                .padding(-3.5)
                        }
                    }

                if hasGoal {
                    Circle()
                        .fill(AnkerColor.brass)
                        .frame(width: 4, height: 4)
                        .offset(y: 2)
                }
            }
            .frame(width: 32, height: 32)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ChipButton: View {
    let title: String
    var isPrimary = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isPrimary ? AnkerColor.indigoText : AnkerColor.muted)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 7, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct GlassTabBar: View {
    @Binding var selection: AppDestination

    var body: some View {
        HStack(spacing: 0) {
            tab(.today, title: "Heute", systemImage: "sun.max")
            tab(.week, title: "Woche", systemImage: "calendar")
            tab(.year, title: "Jahr", systemImage: "square.grid.2x2")
            tab(.review, title: "Mehr", systemImage: "ellipsis.circle")
        }
        .padding(4)
        .background(AnkerColor.card.opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .contain)
    }

    private func tab(_ destination: AppDestination, title: String, systemImage: String) -> some View {
        Button {
            selection = destination
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22, height: 20)
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isSelected(destination) ? AnkerColor.indigo : AnkerColor.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(isSelected(destination) ? AnkerColor.indigo.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
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

struct GlassFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(.ultraThinMaterial, in: Circle())
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#8C9BF5").opacity(0.92), AnkerColor.indigoText.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.46))
                        .frame(width: 16, height: 16)
                        .blur(radius: 6)
                        .offset(x: 8, y: 7)
                }
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: AnkerColor.indigoText.opacity(0.5), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Neue Aufgabe")
    }
}
