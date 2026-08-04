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
            HStack(spacing: AnkerSpacing.s2) {
                ChipButton(title: "Heute", isPrimary: true, action: onCurrentWeek)
                ChipButton(title: "« KW \(weekLabel(offset: -1))", action: onPreviousWeek)
                ChipButton(title: "KW \(weekLabel(offset: 1)) »", action: onNextWeek)
                Spacer()
                Text("\(AnkerDateFormat.dayMonthYear(week.monday)) – \(AnkerDateFormat.dayMonthYear(week.sunday))")
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s3)
            .background(AnkerColor.surface)
            .ankerEdge(.bottom)

            HStack(spacing: AnkerSpacing.s3) {
                ForEach(GoalOrdering.anchors(in: week), id: \.id) { goal in
                    GoalPill(goal: goal)
                        .contextMenu {
                            Button(role: .destructive) {
                                goalPendingDeletion = goal
                            } label: {
                                Label("Wochenziel löschen", ankerIcon: AnkerIcon.delete)
                            }
                        }
                }
            }
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s4)
            .background(AnkerColor.ground)
            .ankerEdge(.bottom)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                        dayDropButton(day)
                    }
                }
                .padding(.horizontal, AnkerSpacing.s4)
                .padding(.vertical, AnkerSpacing.s3)
            }
            .background(AnkerColor.ground)

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
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            HStack {
                Text(goal.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: AnkerSpacing.s2)
                // Der Ring stand hier zusaetzlich zum Balken darunter — dieselbe Aussage zweimal.
                Text(verbatim: "\(Int(goal.progress * 100))%")
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .accessibilityLabel("\(goal.title), \(Int(goal.progress * 100)) Prozent erreicht")

            AnkerProgressBar(
                progress: goal.progress,
                tint: AnkerColor.goalTint(goal.colorHex),
                thickness: AnkerBorder.rule * 3
            )
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s3)
        .ankerCard()
    }
}

private struct WeekGridRow: View {
    let day: Day
    let isSelected: Bool
    let isDropTarget: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AnkerSpacing.s3) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(AnkerDateFormat.weekdayLong(day.date))
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(isSelected ? AnkerColor.accentInk : AnkerColor.ink)
                Text(AnkerDateFormat.dayMonth(day.date))
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .frame(width: 96, alignment: .leading)

            FlowLayout(spacing: AnkerSpacing.s2) {
                ForEach(day.taskList.sorted { $0.order < $1.order }, id: \.id) { task in
                    MiniTask(task: task)
                }
            }
        }
        .padding(.vertical, AnkerSpacing.s2)
        .padding(.horizontal, (isSelected || isDropTarget) ? 18 : 0)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: AnkerRadius.tile, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AnkerRadius.tile, style: .continuous)
                .stroke(isDropTarget ? AnkerColor.accentFill : Color.clear, lineWidth: AnkerBorder.rule)
        )
        .overlay(alignment: .bottom) { AnkerRule(weight: .row) }
        .scaleEffect(isDropTarget ? 1.01 : 1)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }

    private var rowBackground: some ShapeStyle {
        if isDropTarget {
            return AnyShapeStyle(AnkerColor.accentFill.opacity(0.16))
        }

        if isSelected {
            return AnyShapeStyle(AnkerColor.highlight)
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
            HStack(spacing: AnkerSpacing.s1) {
                Rectangle()
                    .fill(task.isDone ? AnkerColor.ink : task.linkedGoal.map { AnkerColor.goalTint($0.colorHex) } ?? AnkerColor.inkSecond)
                    .frame(width: 6, height: 6)
                Text(task.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(task.isDone ? AnkerColor.inkSecond : AnkerColor.ink)
                    .strikethrough(task.isDone, color: AnkerColor.inkSecond)
                    .lineLimit(1)
            }
            .padding(.horizontal, AnkerSpacing.s2)
            .padding(.vertical, AnkerSpacing.s1)
            .ankerControl()
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
            Label(task.isDone ? "Als offen markieren" : "Als erledigt markieren", ankerIcon: task.isDone ? .open : .checkCircle)
        }

        Button {
            showingEditor = true
        } label: {
            Label("Bearbeiten", ankerIcon: AnkerIcon.edit)
        }

        Button {
            TaskActions.move(task, byDays: 7, weeks: weeks, modelContext: modelContext)
        } label: {
            Label("Nächste Woche", ankerIcon: AnkerIcon.nextMonth)
        }

        Divider()

        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Löschen", ankerIcon: AnkerIcon.delete)
        }
    }
}

#if os(macOS)
private struct TaskShortcutHintBar: View {
    var body: some View {
        HStack(spacing: AnkerSpacing.s3) {
            shortcut("⌘.", "Erledigt")
            divider
            shortcut("⌘⌫", "Löschen")
            divider
            shortcut("⌘⇧M", "Verschieben")
            divider
            shortcut("⌘D", "Duplizieren")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnkerSpacing.s4)
        .padding(.vertical, AnkerSpacing.s2)
        .background(AnkerColor.surface)
        .ankerEdge(.top)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tastaturkurzbefehle: Command Punkt erledigt, Command Rückschritt löschen, Command Shift M verschieben, Command D duplizieren")
    }

    private func shortcut(_ keys: String, _ label: String) -> some View {
        HStack(spacing: AnkerSpacing.s1) {
            Text(keys)
                .ankerType(AnkerType.numericSmall)
                .foregroundStyle(AnkerColor.inkSecond)
            Text(label)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
        }
    }

    private var divider: some View {
        Text("·")
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond.opacity(0.72))
    }
}
#endif
