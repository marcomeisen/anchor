import SwiftData
import SwiftUI

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
    @Query(sort: \Week.monday) private var weeks: [Week]

    let task: AnkerTask
    var showPriority = true
    var onToggle: (() -> Void)?

    @State private var showingEditor = false
    @State private var confirmingDelete = false
    @State private var isHovering = false

    private var isActionable: Bool {
        task.day != nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if showPriority {
                PriorityTag(priority: task.priority)
                    .padding(.top, 1)
            }

            Button {
                if let onToggle {
                    onToggle()
                } else {
                    withAnimation(.snappy) {
                        TaskActions.toggleDone(task, modelContext: modelContext)
                    }
                }
            } label: {
                TaskCheckmark(isDone: task.isDone)
            }
            .buttonStyle(.plain)
            .padding(.top, 1)

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

            if isActionable {
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
        .contextMenu {
            if isActionable {
                taskMenuItems
            }
        }
        .conditionalDrag(taskID: task.id.uuidString, isEnabled: isActionable)
#if os(macOS)
        .onHover { isInside in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = isInside
            }
        }
#endif
        .sheet(isPresented: $showingEditor) {
            TaskEditorSheet(task: task)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Aufgabe löschen?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                TaskActions.delete(task, modelContext: modelContext)
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
                withAnimation(.snappy) {
                    TaskActions.toggleDone(task, modelContext: modelContext)
                }
            }

            hoverAction(systemName: "calendar", tint: AnkerColor.indigo, help: "Aufgabe verschieben oder planen (⌘⇧M)") {
                showingEditor = true
            }

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
            withAnimation(.snappy) {
                TaskActions.toggleDone(task, modelContext: modelContext)
            }
        } label: {
            Label(task.isDone ? "Als offen markieren" : "Als erledigt markieren", systemImage: task.isDone ? "circle" : "checkmark.circle")
        }
        .keyboardShortcut(".", modifiers: .command)

        Button {
            showingEditor = true
        } label: {
            Label("Bearbeiten", systemImage: "pencil")
        }

        Menu {
            Button {
                TaskActions.move(task, byDays: 1, weeks: weeks, modelContext: modelContext)
            } label: {
                Label("Morgen", systemImage: "sunrise")
            }

            Button {
                TaskActions.move(task, byDays: 7, weeks: weeks, modelContext: modelContext)
            } label: {
                Label("Nächste Woche", systemImage: "calendar.badge.plus")
            }

            Button {
                TaskActions.move(task, byDays: -7, weeks: weeks, modelContext: modelContext)
            } label: {
                Label("Vorherige Woche", systemImage: "calendar.badge.minus")
            }
        } label: {
            Label("Verschieben", systemImage: "arrow.right.square")
        }

        Menu {
            if let goals = task.day?.week?.goalList, !goals.isEmpty {
                ForEach(goals, id: \.id) { goal in
                    Button {
                        TaskActions.link(task, to: goal, modelContext: modelContext)
                    } label: {
                        Label(goal.title, systemImage: task.linkedGoal?.id == goal.id ? "checkmark" : "target")
                    }
                }
                Divider()
            }

            Button {
                TaskActions.link(task, to: nil, modelContext: modelContext)
            } label: {
                Label("Kein Ziel", systemImage: task.linkedGoal == nil ? "checkmark" : "xmark.circle")
            }
        } label: {
            Label("Mit Ziel verknüpfen", systemImage: "target")
        }

        Menu {
            ForEach(Priority.allCases, id: \.self) { priority in
                Button {
                    TaskActions.setPriority(task, to: priority, modelContext: modelContext)
                } label: {
                    Label("Priorität \(priority.label)", systemImage: task.priority == priority ? "checkmark" : "flag")
                }
            }
        } label: {
            Label("Priorität", systemImage: "flag")
        }

        Button {
            _ = TaskActions.duplicate(task, modelContext: modelContext)
        } label: {
            Label("Duplizieren", systemImage: "doc.on.doc")
        }
        .keyboardShortcut("d", modifiers: .command)

        Divider()

        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Löschen", systemImage: "trash")
        }
        .keyboardShortcut(.delete, modifiers: .command)
    }
}

private extension View {
    @ViewBuilder
    func conditionalDrag(taskID: String, isEnabled: Bool) -> some View {
        if isEnabled {
            self.onDrag {
                NSItemProvider(object: taskID as NSString)
            }
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
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 14)
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
                    .background(isSelected(destination) ? AnkerColor.indigo.opacity(0.16) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                Text(title)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(isSelected(destination) ? AnkerColor.indigo : AnkerColor.muted)
            .frame(maxWidth: .infinity)
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
