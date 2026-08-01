import SwiftData
import SwiftUI

enum TaskActions {
    static func toggleDone(_ task: AnkerTask, modelContext: ModelContext) {
        task.isDone.toggle()
        try? modelContext.save()
    }

    static func delete(_ task: AnkerTask, modelContext: ModelContext) {
        if let day = task.day {
            day.tasks = day.taskList.filter { $0.id != task.id }
            normalizeOrders(in: day)
        }

        if let goal = task.linkedGoal {
            goal.tasks = goal.taskList.filter { $0.id != task.id }
        }

        modelContext.delete(task)
        try? modelContext.save()
    }

    @discardableResult
    static func duplicate(_ task: AnkerTask, modelContext: ModelContext) -> AnkerTask? {
        guard let day = task.day else { return nil }

        let copy = AnkerTask(
            title: task.title,
            priority: task.priority,
            isDone: false,
            order: day.taskList.count,
            day: day,
            linkedGoal: task.linkedGoal
        )
        modelContext.insert(copy)
        day.appendTask(copy)
        normalizeOrders(in: day)
        try? modelContext.save()
        return copy
    }

    static func setPriority(_ task: AnkerTask, to priority: Priority, modelContext: ModelContext) {
        task.priority = priority
        try? modelContext.save()
    }

    static func link(_ task: AnkerTask, to goal: Goal?, modelContext: ModelContext) {
        task.linkedGoal = goal
        try? modelContext.save()
    }

    static func move(_ task: AnkerTask, to targetDate: Date, weeks: [Week], modelContext: ModelContext) {
        let targetWeek = ensureWeek(containing: targetDate, weeks: weeks, modelContext: modelContext)
        let targetDay = ensureDay(containing: targetDate, in: targetWeek)

        if let currentDay = task.day, currentDay.id == targetDay.id {
            try? modelContext.save()
            return
        }

        if let oldDay = task.day {
            oldDay.tasks = oldDay.taskList.filter { $0.id != task.id }
            normalizeOrders(in: oldDay)
        }

        if task.linkedGoal?.week?.id != targetWeek.id {
            task.linkedGoal = nil
        }

        task.day = targetDay
        task.order = targetDay.taskList.count
        targetDay.tasks = targetDay.taskList.filter { $0.id != task.id } + [task]
        normalizeOrders(in: targetDay)
        try? modelContext.save()
    }

    static func move(_ task: AnkerTask, byDays offset: Int, weeks: [Week], modelContext: ModelContext) {
        guard let sourceDate = task.day?.date,
              let targetDate = AnkerCalendar.iso.date(byAdding: .day, value: offset, to: sourceDate) else { return }
        move(task, to: targetDate, weeks: weeks, modelContext: modelContext)
    }

    @discardableResult
    static func ensureWeek(containing date: Date, weeks: [Week], modelContext: ModelContext) -> Week {
        let interval = AnkerCalendar.weekInterval(containing: date)

        if let existingWeek = weeks.first(where: { AnkerCalendar.isSameDay($0.monday, interval.monday) }) {
            ensureWeekDays(in: existingWeek)
            return existingWeek
        }

        let week = Week(
            isoYear: interval.isoYear,
            isoWeek: interval.isoWeek,
            monday: interval.monday,
            sunday: interval.sunday
        )
        week.days = AnkerCalendar.daysInWeek(starting: interval.monday).map { date in
            Day(date: date, week: week)
        }
        modelContext.insert(week)
        return week
    }

    static func ensureWeekDays(in week: Week) {
        if week.dayList.isEmpty {
            week.days = AnkerCalendar.daysInWeek(starting: week.monday).map { date in
                Day(date: date, week: week)
            }
        }
    }

    static func ensureDay(containing date: Date, in week: Week) -> Day {
        ensureWeekDays(in: week)

        if let day = week.dayList.first(where: { AnkerCalendar.isSameDay($0.date, date) }) {
            return day
        }

        let day = Day(date: date, week: week)
        week.days = (week.days ?? []) + [day]
        return day
    }

    static func normalizeOrders(in day: Day) {
        let orderedTasks = day.taskList.sorted {
            if $0.order == $1.order {
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return $0.order < $1.order
        }

        for (index, task) in orderedTasks.enumerated() {
            task.order = index
        }

        day.tasks = orderedTasks
    }
}

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
        selectedWeek?.goalList ?? []
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleField
                    statusAndPriority
                    weekPicker
                    dayPicker
                    goalPicker
                    destructiveActions
                }
                .padding(18)
            }
            .background(AnkerColor.paper)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Aufgabe".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            TextField("Was steht an?", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AnkerColor.card)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))
        }
    }

    private var statusAndPriority: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Status".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)

                Toggle(isOn: $isDone) {
                    Label(isDone ? "Erledigt" : "Offen", systemImage: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 12.5, weight: .semibold))
                }
                .toggleStyle(.switch)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Priorität".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)

                HStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Woche".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            HStack(spacing: 8) {
                iconButton(systemName: "chevron.left", label: "Vorherige Woche") {
                    moveSelectedWeek(by: -1)
                }

                VStack(spacing: 2) {
                    Text("KW \(String(format: "%02d", selectedWeekInterval.isoWeek))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text("\(shortDate(selectedWeekInterval.monday)) - \(shortDate(selectedWeekInterval.sunday))")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AnkerColor.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))

                iconButton(systemName: "chevron.right", label: "Nächste Woche") {
                    moveSelectedWeek(by: 1)
                }
            }
        }
    }

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tag".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            HStack(spacing: 6) {
                ForEach(AnkerCalendar.daysInWeek(starting: selectedWeekStart), id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 3) {
                            Text(date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated)).replacing(".", with: ""))
                                .font(.system(size: 9.5, weight: .bold))
                            Text(date.formatted(.dateTime.day(.twoDigits)))
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(AnkerCalendar.isSameDay(date, selectedDate) ? .white : AnkerColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.indigo : AnkerColor.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerCalendar.isSameDay(date, selectedDate) ? Color.clear : AnkerColor.line))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide).day().month()))
                }
            }
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wochenziel".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            FlowLayout(spacing: 6) {
                ForEach(selectedWeekGoals.prefix(4), id: \.id) { goal in
                    CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: Color(hex: goal.colorHex)) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.indigoBadge) {
                    selectedGoalID = nil
                }
            }

            if selectedWeek == nil {
                Text("Die Woche wird beim Sichern angelegt. Ziele kannst du anschließend zuordnen.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AnkerColor.muted)
            }
        }
    }

    private var destructiveActions: some View {
        Button(role: .destructive) {
            confirmsDelete = true
        } label: {
            Label("Aufgabe löschen", systemImage: "trash")
                .font(.system(size: 12.5, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(Color(hex: "#D93327"))
        .padding(.top, 6)
    }

    private func iconButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 36, height: 36)
                .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerColor.line))
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
        task.isDone = isDone
        task.linkedGoal = task.day?.week?.goalList.first { $0.id == selectedGoalID }
        try? modelContext.save()
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits))
    }
}
