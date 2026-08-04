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
                    Text("\(AnkerDateFormat.calendarWeek(selectedWeekInterval.isoWeek))")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text("\(AnkerDateFormat.dayMonth(selectedWeekInterval.monday)) - \(AnkerDateFormat.dayMonth(selectedWeekInterval.sunday))")
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
                            Text(AnkerDateFormat.weekdayShort(date))
                                .font(.system(size: 9.5, weight: .bold))
                            Text(AnkerDateFormat.dayNumber(date))
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(AnkerCalendar.isSameDay(date, selectedDate) ? .white : AnkerColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.indigo : AnkerColor.card)
                        .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerCalendar.isSameDay(date, selectedDate) ? Color.clear : AnkerColor.line))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AnkerDateFormat.weekdayLongWithDayMonth(date))
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
        .foregroundStyle(AnkerColor.destructive)
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
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cleanTasks.count == 1 ? "Aufgabe verschieben" : "\(cleanTasks.count) Aufgaben verschieben")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text("Wähle Woche und Zieltag.")
                        .font(.system(size: 12))
                        .foregroundStyle(AnkerColor.muted)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Woche".uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(AnkerColor.muted)

                    HStack(spacing: 8) {
                        moveButton(systemName: "chevron.left", label: "Vorherige Woche") {
                            moveSelectedWeek(by: -1)
                        }

                        VStack(spacing: 2) {
                            Text("\(AnkerDateFormat.calendarWeek(selectedWeekInterval.isoWeek))")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(AnkerColor.ink)
                            Text("\(AnkerDateFormat.dayMonth(selectedWeekInterval.monday)) - \(AnkerDateFormat.dayMonth(selectedWeekInterval.sunday))")
                                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(AnkerColor.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))

                        moveButton(systemName: "chevron.right", label: "Nächste Woche") {
                            moveSelectedWeek(by: 1)
                        }
                    }
                }

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
                                    Text(AnkerDateFormat.weekdayShort(date))
                                        .font(.system(size: 9.5, weight: .bold))
                                    Text(AnkerDateFormat.dayNumber(date))
                                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                }
                                .foregroundStyle(AnkerCalendar.isSameDay(date, selectedDate) ? .white : AnkerColor.ink)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .background(AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.indigo : AnkerColor.card)
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerCalendar.isSameDay(date, selectedDate) ? Color.clear : AnkerColor.line))
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(AnkerColor.paper)
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

    private func moveButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 38, height: 38)
                .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

}
