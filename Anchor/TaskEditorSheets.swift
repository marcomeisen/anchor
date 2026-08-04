import SwiftData
import SwiftUI

struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    @Bindable var task: AnkerTask

    @State private var title = ""
    @State private var priority: Priority = .b
    @State private var isDone = false
    @State private var selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
    @State private var selectedDate = Date()
    @State private var selectedGoalID: UUID?
    @State private var hasLoadedTask = false
    @State private var confirmsDelete = false

    private var selectedWeek: Week? {
        weeks.first { AnkerCalendar.isSameDay($0.monday, selectedWeekStart) }
    }

    private var selectedWeekInterval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        AnkerCalendar.weekInterval(containing: selectedWeekStart)
    }

    private var selectedWeekGoals: [Goal] {
        selectedWeek.map(GoalOrdering.anchors(in:)) ?? []
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                    titleField
                    statusAndPriority
                    weekPicker
                    dayPicker
                    goalPicker
                    destructiveActions
                }
                .padding(AnkerSpacing.s4)
            }
            .background(AnkerColor.ground)
            .navigationTitle("Aufgabe bearbeiten")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                        dismiss()
                    }
                    .disabled(cleanTitle.isEmpty)
                }
            }
            .confirmationDialog("Aufgabe löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    TaskActions.delete(task, modelContext: modelContext)
                    dismiss()
                }
                Button("Abbrechen", role: .cancel) {}
            } message: {
                Text("Diese Aufgabe wird dauerhaft entfernt.")
            }
            .onAppear(perform: loadTaskIfNeeded)
        }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Aufgabe")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            TextField("Was steht an?", text: $title)
                .textFieldStyle(.plain)
                .ankerType(AnkerType.subheadline)
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s3)
                .ankerField()
        }
    }

    private var statusAndPriority: some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s4) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                Text("Status")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)

                Toggle(isOn: $isDone) {
                    Label(isDone ? "Erledigt" : "Offen", ankerIcon: isDone ? .checkCircleLarge : .open)
                        .ankerType(AnkerType.caption)
                }
                .toggleStyle(.switch)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                Text("Priorität")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)

                HStack(spacing: AnkerSpacing.s2) {
                    ForEach(Priority.allCases, id: \.self) { item in
                        CaptureChip(title: item.label, isSelected: priority == item, selectedColor: PriorityTag(priority: item).color) {
                            priority = item
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Woche")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            HStack(spacing: AnkerSpacing.s2) {
                iconButton(ankerIcon: .chevronLeft, label: "Vorherige Woche") {
                    moveSelectedWeek(by: -1)
                }

                VStack(spacing: AnkerSpacing.s1) {
                    Text("\(AnkerDateFormat.calendarWeek(selectedWeekInterval.isoWeek))")
                        .ankerType(AnkerType.metaStrong)
                        .foregroundStyle(AnkerColor.ink)
                    Text("\(AnkerDateFormat.dayMonth(selectedWeekInterval.monday)) - \(AnkerDateFormat.dayMonth(selectedWeekInterval.sunday))")
                        .ankerType(AnkerType.numericSmall)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AnkerSpacing.s2)
                .ankerControl()

                iconButton(ankerIcon: .chevronRight, label: "Nächste Woche") {
                    moveSelectedWeek(by: 1)
                }
            }
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Tag")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            HStack(spacing: AnkerSpacing.s2) {
                ForEach(AnkerCalendar.daysInWeek(starting: selectedWeekStart), id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: AnkerSpacing.s1) {
                            Text(AnkerDateFormat.weekdayShort(date))
                                .ankerType(AnkerType.caption)
                            Text(AnkerDateFormat.dayNumber(date))
                                .ankerType(AnkerType.numericSmall)
                        }
                        .foregroundStyle(AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.onAccent : AnkerColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .ankerControl(
                            fill: AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.accentFill : AnkerColor.surface,
                            stroke: AnkerCalendar.isSameDay(date, selectedDate) ? nil : AnkerColor.divider,
                            radius: AnkerRadius.tile
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AnkerDateFormat.weekdayLongWithDayMonth(date))
                }
            }
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Wochenziel")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            FlowLayout(spacing: AnkerSpacing.s2) {
                ForEach(selectedWeekGoals.prefix(4), id: \.id) { goal in
                    CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: Color(hex: goal.colorHex)) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.accentFill) {
                    selectedGoalID = nil
                }
            }

            if selectedWeek == nil {
                Text("Die Woche wird beim Sichern angelegt. Ziele kannst du anschließend zuordnen.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
        }
    }

    private var destructiveActions: some View {
        Button(role: .destructive) {
            confirmsDelete = true
        } label: {
            Label("Aufgabe löschen", ankerIcon: AnkerIcon.delete)
                .ankerType(AnkerType.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AnkerSpacing.s3)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(AnkerColor.accentMark)
        .padding(.top, AnkerSpacing.s2)
    }

    private func iconButton(ankerIcon: AnkerIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                .frame(width: 36, height: 36)
                .ankerControl()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func loadTaskIfNeeded() {
        guard !hasLoadedTask else { return }
        title = task.title
        priority = task.priority
        isDone = task.isDone
        selectedDate = task.day?.date ?? Date()
        selectedWeekStart = AnkerCalendar.weekInterval(containing: selectedDate).monday
        selectedGoalID = task.linkedGoal?.id
        hasLoadedTask = true
    }

    private func moveSelectedWeek(by offset: Int) {
        guard let newWeekStart = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart),
              let newSelectedDate = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }

        selectedWeekStart = AnkerCalendar.weekInterval(containing: newWeekStart).monday
        selectedDate = newSelectedDate

        if selectedWeekGoals.allSatisfy({ $0.id != selectedGoalID }) {
            selectedGoalID = nil
        }
    }

    private func save() {
        TaskActions.move(task, to: selectedDate, weeks: weeks, modelContext: modelContext)

        task.title = cleanTitle
        task.priority = priority
        TaskActions.setDone(task, isDone, modelContext: modelContext)
        task.linkedGoal = task.day?.week?.goalList.first { $0.id == selectedGoalID }
        modelContext.saveChanges()
    }

}

struct TaskMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let tasks: [AnkerTask]
    var onMoved: (([TaskSnapshot]) -> Void)?

    @State private var selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
    @State private var selectedDate = Date()
    @State private var hasLoaded = false

    private var selectedWeekInterval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        AnkerCalendar.weekInterval(containing: selectedWeekStart)
    }

    private var cleanTasks: [AnkerTask] {
        tasks.filter { $0.day != nil }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(cleanTasks.count == 1 ? "Aufgabe verschieben" : "\(cleanTasks.count) Aufgaben verschieben")
                        .ankerType(AnkerType.taskTitle)
                        .foregroundStyle(AnkerColor.ink)
                    Text("Wähle Woche und Zieltag.")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    Text("Woche")
                        .ankerType(AnkerType.eyebrow)
                        .foregroundStyle(AnkerColor.inkSecond)

                    HStack(spacing: AnkerSpacing.s2) {
                        moveButton(ankerIcon: .chevronLeft, label: "Vorherige Woche") {
                            moveSelectedWeek(by: -1)
                        }

                        VStack(spacing: AnkerSpacing.s1) {
                            Text("\(AnkerDateFormat.calendarWeek(selectedWeekInterval.isoWeek))")
                                .ankerType(AnkerType.metaStrong)
                                .foregroundStyle(AnkerColor.ink)
                            Text("\(AnkerDateFormat.dayMonth(selectedWeekInterval.monday)) - \(AnkerDateFormat.dayMonth(selectedWeekInterval.sunday))")
                                .ankerType(AnkerType.numericSmall)
                                .foregroundStyle(AnkerColor.inkSecond)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AnkerSpacing.s3)
                        .ankerControl()

                        moveButton(ankerIcon: .chevronRight, label: "Nächste Woche") {
                            moveSelectedWeek(by: 1)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    Text("Tag")
                        .ankerType(AnkerType.eyebrow)
                        .foregroundStyle(AnkerColor.inkSecond)

                    HStack(spacing: AnkerSpacing.s2) {
                        ForEach(AnkerCalendar.daysInWeek(starting: selectedWeekStart), id: \.self) { date in
                            Button {
                                selectedDate = date
                            } label: {
                                VStack(spacing: AnkerSpacing.s1) {
                                    Text(AnkerDateFormat.weekdayShort(date))
                                        .ankerType(AnkerType.caption)
                                    Text(AnkerDateFormat.dayNumber(date))
                                        .ankerType(AnkerType.numericSmall)
                                }
                                .foregroundStyle(AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.onAccent : AnkerColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .ankerControl(
                                    fill: AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.accentFill : AnkerColor.surface,
                                    stroke: AnkerCalendar.isSameDay(date, selectedDate) ? nil : AnkerColor.divider,
                                    radius: AnkerRadius.tile
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(AnkerSpacing.s4)
            .background(AnkerColor.ground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Verschieben") {
                        moveTasks()
                        dismiss()
                    }
                    .disabled(cleanTasks.isEmpty)
                }
            }
            .onAppear(perform: loadInitialDate)
        }
    }

    private func loadInitialDate() {
        guard !hasLoaded else { return }
        selectedDate = cleanTasks.first?.day?.date ?? Date()
        selectedWeekStart = AnkerCalendar.weekInterval(containing: selectedDate).monday
        hasLoaded = true
    }

    private func moveTasks() {
        let snapshots = cleanTasks.map { TaskActions.snapshot($0) }
        for task in cleanTasks {
            TaskActions.move(task, to: selectedDate, weeks: weeks, modelContext: modelContext)
        }
        onMoved?(snapshots)
    }

    private func moveSelectedWeek(by offset: Int) {
        guard let newWeekStart = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart),
              let newSelectedDate = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }

        selectedWeekStart = AnkerCalendar.weekInterval(containing: newWeekStart).monday
        selectedDate = newSelectedDate
    }

    private func moveButton(ankerIcon: AnkerIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                .frame(width: 38, height: 38)
                .ankerControl()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

}
