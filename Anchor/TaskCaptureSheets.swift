import SwiftData
import SwiftUI

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    var onScheduled: (Date) -> Void = { _ in }

    @State private var title = ""
    @State private var priority: Priority = .a
    @State private var selectedGoalID: UUID?
    @State private var selectedWeekStart: Date
    @State private var selectedDate: Date

    init(day: Day, onScheduled: @escaping (Date) -> Void = { _ in }) {
        self.onScheduled = onScheduled
        _selectedDate = State(initialValue: day.date)
        _selectedWeekStart = State(initialValue: AnkerCalendar.weekInterval(containing: day.date).monday)
    }

    private var selectedWeek: Week? {
        weeks.first { AnkerCalendar.isSameDay($0.monday, selectedWeekStart) }
    }

    private var selectedWeekInterval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        AnkerCalendar.weekInterval(containing: selectedWeekStart)
    }

    private var selectedWeekGoals: [Goal] {
        selectedWeek?.goalList ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Was steht an?", text: $title)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 9)
                        .background(AnkerColor.surfaceRaised)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))

                    planningPicker

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

                    Text("Wochenziel zuordnen".uppercased())
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(AnkerColor.muted)
                        .padding(.top, 4)

                    FlowLayout(spacing: 6) {
                        ForEach(selectedWeekGoals.prefix(4), id: \.id) { goal in
                            CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: Color(hex: goal.colorHex)) {
                                selectedGoalID = goal.id
                            }
                            // Eigene Kennung: der Zieltitel allein ist nicht eindeutig, er
                            // steht gleichzeitig in der Sidebar.
                            .accessibilityIdentifier("goalChip.\(goal.title)")
                        }
                        CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.indigoBadge) {
                            selectedGoalID = nil
                        }
                    }

                    if selectedWeek == nil {
                        Text("Die Woche wird beim Sichern angelegt. Wochenziele kannst du danach direkt fuer diese Woche erstellen.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(AnkerColor.muted)
                    }

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .background(AnkerColor.card)
            .navigationTitle("Schnell erfassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var planningPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planen".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            planningNavigation
            dayPicker
        }
    }

    private var planningNavigation: some View {
        HStack(spacing: 8) {
            planningButton(systemName: "calendar.badge.minus", label: "Vorheriger Monat") {
                moveSelectedMonth(by: -1)
            }

            planningButton(systemName: "chevron.left", label: "Vorherige Woche") {
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
            .background(AnkerColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))

            planningButton(systemName: "chevron.right", label: "Nächste Woche") {
                moveSelectedWeek(by: 1)
            }

            planningButton(systemName: "calendar.badge.plus", label: "Nächster Monat") {
                moveSelectedMonth(by: 1)
            }
        }
    }

    private var dayPicker: some View {
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
                    .background(AnkerCalendar.isSameDay(date, selectedDate) ? AnkerColor.indigo : AnkerColor.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerCalendar.isSameDay(date, selectedDate) ? Color.clear : AnkerColor.line))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(AnkerDateFormat.weekdayLongWithDayMonth(date))
            }
        }
    }

    private func planningButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 34, height: 34)
                .background(AnkerColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let week = ensureWeek(containing: selectedDate)
        guard let day = week.dayList.first(where: { AnkerCalendar.isSameDay($0.date, selectedDate) }) else { return }
        let goal = week.goalList.first { $0.id == selectedGoalID }
        let task = AnkerTask(
            title: cleanTitle,
            priority: priority,
            order: day.taskList.count,
            day: day,
            linkedGoal: goal
        )
        modelContext.insert(task)
        day.appendTask(task)
        modelContext.saveChanges()
        onScheduled(selectedDate)
    }

    private func moveSelectedWeek(by offset: Int) {
        guard let newWeekStart = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart),
              let newSelectedDate = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }

        selectedWeekStart = AnkerCalendar.weekInterval(containing: newWeekStart).monday
        selectedDate = newSelectedDate
        clearGoalIfNeeded()
    }

    private func moveSelectedMonth(by offset: Int) {
        let calendar = AnkerCalendar.iso
        guard let newSelectedDate = calendar.date(byAdding: .month, value: offset, to: selectedDate) else { return }
        selectedDate = newSelectedDate
        selectedWeekStart = AnkerCalendar.weekInterval(containing: newSelectedDate).monday
        clearGoalIfNeeded()
    }

    private func clearGoalIfNeeded() {
        if selectedWeekGoals.allSatisfy({ $0.id != selectedGoalID }) {
            selectedGoalID = nil
        }
    }

    @discardableResult
    private func ensureWeek(containing date: Date) -> Week {
        TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
    }

}

#if os(macOS)
struct QuickCapturePopover: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    @State private var title = "Foliensatz für Steering-Meeting"
    @State private var priority: Priority = .a
    @State private var selectedGoalID: UUID?

    private var currentWeek: Week? {
        let interval = AnkerCalendar.weekInterval(containing: Date())
        return weeks.first { AnkerCalendar.isSameDay($0.monday, interval.monday) }
    }

    private var currentDay: Day? {
        currentWeek?.dayList.first { AnkerCalendar.isSameDay($0.date, Date()) }
            ?? currentWeek?.dayList.sorted { $0.date < $1.date }.first
    }

    private var goals: [Goal] {
        Array((currentWeek?.goalList ?? []).prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schnell erfassen")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AnkerColor.ink)

            TextField("Was steht an?", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(AnkerColor.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))

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

            Text("Wochenziel zuordnen".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            FlowLayout(spacing: 6) {
                ForEach(goals, id: \.id) { goal in
                    CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.indigoBadge) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.indigoBadge) {
                    selectedGoalID = nil
                }
            }

            HStack {
                Spacer()
                Button("Abbrechen") {
                    title = ""
                    selectedGoalID = nil
                }
                Button("Sichern") {
                    save()
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.top, 2)
        }
        .onAppear {
            let week = ensureCurrentWeek()
            selectedGoalID = selectedGoalID ?? week.goalList.first?.id
            modelContext.saveChanges()
        }
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private func save() {
        let week = ensureCurrentWeek()
        guard let currentDay = week.dayList.first(where: { AnkerCalendar.isSameDay($0.date, Date()) })
            ?? week.dayList.sorted(by: { $0.date < $1.date }).first else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let goal = week.goalList.first { $0.id == selectedGoalID }
        let task = AnkerTask(
            title: cleanTitle,
            priority: priority,
            order: currentDay.taskList.count,
            day: currentDay,
            linkedGoal: goal
        )
        modelContext.insert(task)
        currentDay.appendTask(task)
        modelContext.saveChanges()
        title = ""
        selectedGoalID = week.goalList.first?.id
    }

    @discardableResult
    private func ensureCurrentWeek() -> Week {
        let interval = AnkerCalendar.weekInterval(containing: Date())

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

    private func ensureWeekDays(in week: Week) {
        if week.dayList.isEmpty {
            week.days = AnkerCalendar.daysInWeek(starting: week.monday).map { date in
                Day(date: date, week: week)
            }
        }
    }
}
#endif

struct NewGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    var onScheduled: (Date) -> Void = { _ in }

    @State private var title = ""
    @State private var selectedColor = "#5B6EE8"
    @State private var selectedWeekStart: Date

    private let colorOptions = ["#5B6EE8", "#C9974B", "#7FCDA8", "#8FA8E8", "#F0C955", "#F09EA9"]

    init(week: Week, onScheduled: @escaping (Date) -> Void = { _ in }) {
        self.onScheduled = onScheduled
        _selectedWeekStart = State(initialValue: week.monday)
    }

    private var selectedWeek: Week? {
        weeks.first { AnkerCalendar.isSameDay($0.monday, selectedWeekStart) }
    }

    private var selectedWeekInterval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        AnkerCalendar.weekInterval(containing: selectedWeekStart)
    }

    private var selectedGoalCount: Int {
        selectedWeek?.goalList.count ?? 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 13) {
                TextField("Was ist dein Wochenziel?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AnkerColor.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))

                Text("Woche".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)

                weekPicker

                Text("Farbe".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)

                HStack(spacing: 8) {
                    ForEach(colorOptions, id: \.self) { colorHex in
                        Button {
                            selectedColor = colorHex
                        } label: {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 25, height: 25)
                                .overlay(Circle().stroke(selectedColor == colorHex ? AnkerColor.ink : AnkerColor.line, lineWidth: selectedColor == colorHex ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Zielfarbe")
                    }
                }

                Text("\(selectedGoalCount)/4 Wochenziele")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AnkerColor.muted)

                Spacer()
            }
            .padding(16)
            .background(AnkerColor.card)
            .navigationTitle("Neues Wochenziel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                        dismiss()
                    }
                    .disabled(cleanTitle.isEmpty || selectedGoalCount >= 4)
                }
            }
        }
    }

    private var weekPicker: some View {
        HStack(spacing: 8) {
            weekButton(systemName: "calendar.badge.minus", label: "Vorheriger Monat") {
                moveSelectedMonth(by: -1)
            }

            weekButton(systemName: "chevron.left", label: "Vorherige Woche") {
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
            .background(AnkerColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))

            weekButton(systemName: "chevron.right", label: "Nächste Woche") {
                moveSelectedWeek(by: 1)
            }

            weekButton(systemName: "calendar.badge.plus", label: "Nächster Monat") {
                moveSelectedMonth(by: 1)
            }
        }
    }

    private func weekButton(systemName: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 34, height: 34)
                .background(AnkerColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        let week = ensureWeek(containing: selectedWeekStart)
        guard !cleanTitle.isEmpty, week.goalList.count < 4 else { return }
        let goal = Goal(title: cleanTitle, colorHex: selectedColor, week: week)
        modelContext.insert(goal)
        week.appendGoal(goal)
        modelContext.saveChanges()
        onScheduled(week.monday)
    }

    private func moveSelectedWeek(by offset: Int) {
        guard let newWeekStart = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) else { return }
        selectedWeekStart = AnkerCalendar.weekInterval(containing: newWeekStart).monday
    }

    private func moveSelectedMonth(by offset: Int) {
        let calendar = AnkerCalendar.iso
        guard let newDate = calendar.date(byAdding: .month, value: offset, to: selectedWeekStart) else { return }
        selectedWeekStart = AnkerCalendar.weekInterval(containing: newDate).monday
    }

    @discardableResult
    private func ensureWeek(containing date: Date) -> Week {
        TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
    }

}

struct CaptureChip: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : AnkerColor.textChip)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? selectedColor : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(isSelected ? selectedColor : AnkerColor.line))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}
