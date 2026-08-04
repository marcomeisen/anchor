import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct WeekOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let week: Week
    let selectedDay: Day
    var onCurrentWeek: () -> Void = {}
    var onPreviousWeek: () -> Void = {}
    var onNextWeek: () -> Void = {}
    var onSelectDay: (Day) -> Void = { _ in }
    var onFocusDay: (Day) -> Void = { _ in }

    @State private var targetedDayID: UUID?
    @State private var goalPendingDeletion: Goal?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ChipButton(title: "Heute", isPrimary: true, action: onCurrentWeek)
                ChipButton(title: "« KW \(weekLabel(offset: -1))", action: onPreviousWeek)
                ChipButton(title: "KW \(weekLabel(offset: 1)) »", action: onNextWeek)
                Spacer()
                Text("\(AnkerDateFormat.dayMonthYear(week.monday)) – \(AnkerDateFormat.dayMonthYear(week.sunday))")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(AnkerColor.muted)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }

            HStack(spacing: 10) {
                ForEach(week.goalList.prefix(4), id: \.id) { goal in
                    GoalPill(goal: goal)
                        .contextMenu {
                            Button(role: .destructive) {
                                goalPendingDeletion = goal
                            } label: {
                                Label("Wochenziel löschen", systemImage: "trash")
                            }
                        }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(AnkerColor.paper)
            .overlay(alignment: .bottom) { Rectangle().fill(AnkerColor.line).frame(height: 1) }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                        dayDropButton(day)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(AnkerColor.paper)

#if os(macOS)
            TaskShortcutHintBar()
#endif
        }
        .navigationTitle("Wochenübersicht")
        .goalDeleteConfirmation(goal: $goalPendingDeletion, week: week)
    }

    private func dayDropButton(_ day: Day) -> some View {
        Button {
            onSelectDay(day)
        } label: {
            WeekGridRow(
                day: day,
                isSelected: AnkerCalendar.isSameDay(day.date, selectedDay.date),
                isDropTarget: targetedDayID == day.id
            )
        }
        .buttonStyle(.plain)
        .help("Tag öffnen oder Aufgabe hierher ziehen")
        .onDrop(
            of: TaskDropHandling.draggedTypes,
            isTargeted: Binding(
                get: { targetedDayID == day.id },
                set: { isTargeted in targetedDayID = isTargeted ? day.id : nil }
            )
        ) { providers in
            dropTask(from: providers, on: day)
        }
    }

    private func dropTask(from providers: [NSItemProvider], on targetDay: Day) -> Bool {
        let targetDate = targetDay.date

        return TaskDropHandling.loadTaskID(from: providers) { taskID in
            TaskDropHandling.moveTask(id: taskID, to: targetDate, weeks: weeks, modelContext: modelContext)
            targetedDayID = nil
            onFocusDay(targetDay)
        }
    }


    private func weekLabel(offset: Int) -> String {
        let target = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: week.monday) ?? week.monday
        let interval = AnkerCalendar.weekInterval(containing: target)
        return String(format: "%02d", interval.isoWeek)
    }
}

private struct GoalPill: View {
    let goal: Goal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                ProgressRing(progress: goal.progress, color: Color(hex: goal.colorHex), lineWidth: 4)
                    .frame(width: 22, height: 22)
                    .accessibilityLabel("\(goal.title), \(Int(goal.progress * 100)) Prozent erreicht")
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AnkerColor.lineSoft)
                    Capsule()
                        .fill(Color(hex: goal.colorHex))
                        .frame(width: proxy.size.width * goal.progress)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AnkerColor.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AnkerColor.line))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct WeekGridRow: View {
    let day: Day
    let isSelected: Bool
    let isDropTarget: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AnkerDateFormat.weekdayLong(day.date))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(isSelected ? AnkerColor.indigoText : AnkerColor.ink)
                Text(AnkerDateFormat.dayMonth(day.date))
                    .font(.system(size: 10.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(AnkerColor.muted)
            }
            .frame(width: 96, alignment: .leading)

            FlowLayout(spacing: 6) {
                ForEach(day.taskList.sorted { $0.order < $1.order }, id: \.id) { task in
                    MiniTask(task: task)
                }
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, (isSelected || isDropTarget) ? 18 : 0)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDropTarget ? AnkerColor.indigo : Color.clear, lineWidth: 1.5)
        )
        .overlay(alignment: .bottom) { Rectangle().fill(AnkerColor.lineSoft).frame(height: 1) }
        .scaleEffect(isDropTarget ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }

    private var rowBackground: some ShapeStyle {
        if isDropTarget {
            return AnyShapeStyle(AnkerColor.indigo.opacity(0.16))
        }

        if isSelected {
            return AnyShapeStyle(AnkerColor.selectedRow)
        }

        return AnyShapeStyle(Color.clear)
    }
}

private struct MiniTask: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let task: AnkerTask
    @State private var showingEditor = false
    @State private var confirmingDelete = false

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(task.isDone ? AnkerColor.success : task.linkedGoal.map { Color(hex: $0.colorHex) } ?? AnkerColor.muted)
                    .frame(width: 6, height: 6)
                Text(task.title)
                    .font(.system(size: 10.5))
                    .foregroundStyle(task.isDone ? AnkerColor.muted : AnkerColor.textTask)
                    .strikethrough(task.isDone, color: AnkerColor.muted)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AnkerColor.card)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(AnkerColor.line))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .contextMenu { taskMenuItems }
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
        .onDrag {
            NSItemProvider(object: task.id.uuidString as NSString)
        }
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

        Button {
            showingEditor = true
        } label: {
            Label("Bearbeiten", systemImage: "pencil")
        }

        Button {
            TaskActions.move(task, byDays: 7, weeks: weeks, modelContext: modelContext)
        } label: {
            Label("Nächste Woche", systemImage: "calendar.badge.plus")
        }

        Divider()

        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Löschen", systemImage: "trash")
        }
    }
}

#if os(macOS)
private struct TaskShortcutHintBar: View {
    var body: some View {
        HStack(spacing: 10) {
            shortcut("⌘.", "Erledigt")
            divider
            shortcut("⌘⌫", "Löschen")
            divider
            shortcut("⌘⇧M", "Verschieben")
            divider
            shortcut("⌘D", "Duplizieren")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(AnkerColor.lineSoft).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tastaturkurzbefehle: Command Punkt erledigt, Command Rückschritt löschen, Command Shift M verschieben, Command D duplizieren")
    }

    private func shortcut(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(AnkerColor.muted)
            Text(label)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(AnkerColor.muted)
        }
    }

    private var divider: some View {
        Text("·")
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(AnkerColor.muted.opacity(0.72))
    }
}
#endif
