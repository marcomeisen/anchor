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
        selectedWeek.map(GoalOrdering.anchors(in:)) ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                    TextField("Was steht an?", text: $title)
                        .textFieldStyle(.plain)
                        .ankerType(AnkerType.body)
                        .padding(.horizontal, AnkerSpacing.s3)
                        .padding(.vertical, AnkerSpacing.s2)
                        .ankerField()

                    planningPicker

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

                    Text("Wochenziel zuordnen")
                        .ankerType(AnkerType.eyebrow)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .padding(.top, AnkerSpacing.s1)

                    FlowLayout(spacing: AnkerSpacing.s2) {
                        ForEach(selectedWeekGoals.prefix(4), id: \.id) { goal in
                            CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: Color(hex: goal.colorHex)) {
                                selectedGoalID = goal.id
                            }
                            // Eigene Kennung: der Zieltitel allein ist nicht eindeutig, er
                            // steht gleichzeitig in der Sidebar.
                            .accessibilityIdentifier("goalChip.\(goal.title)")
                        }
                        CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.accentFill) {
                            selectedGoalID = nil
                        }
                    }

                    if selectedWeek == nil {
                        Text("Die Woche wird beim Sichern angelegt. Wochenziele kannst du danach direkt für diese Woche erstellen.")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                    }

                    Spacer(minLength: 0)
                }
                .padding(AnkerSpacing.s4)
            }
            .background(AnkerColor.surface)
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
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Planen")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            planningNavigation
            dayPicker
        }
    }

    private var planningNavigation: some View {
        HStack(spacing: AnkerSpacing.s2) {
            planningButton(ankerIcon: .previousMonth, label: "Vorheriger Monat") {
                moveSelectedMonth(by: -1)
            }

            planningButton(ankerIcon: .chevronLeft, label: "Vorherige Woche") {
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

            planningButton(ankerIcon: .chevronRight, label: "Nächste Woche") {
                moveSelectedWeek(by: 1)
            }

            planningButton(ankerIcon: .nextMonth, label: "Nächster Monat") {
                moveSelectedMonth(by: 1)
            }
        }
    }

    private var dayPicker: some View {
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

    private func planningButton(ankerIcon: AnkerIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                .frame(width: 34, height: 34)
                .ankerControl()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private func save() {
        let week = ensureWeek(containing: selectedDate)
        guard let day = week.dayList.first(where: { AnkerCalendar.isSameDay($0.date, selectedDate) }) else { return }

        TaskActions.create(
            title: title,
            priority: priority,
            on: day,
            linkedGoal: week.goalList.first { $0.id == selectedGoalID },
            modelContext: modelContext
        )
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
        currentWeek.map(GoalOrdering.anchors(in:)) ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Schnell erfassen")
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)

            TextField("Was steht an?", text: $title)
                .textFieldStyle(.plain)
                .ankerType(AnkerType.body)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s2)
                .ankerField()

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

            Text("Wochenziel zuordnen")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            FlowLayout(spacing: AnkerSpacing.s2) {
                ForEach(goals, id: \.id) { goal in
                    CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.accentFill) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.accentFill) {
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
            .ankerType(AnkerType.caption)
            .padding(.top, AnkerSpacing.s1)
        }
        .onAppear {
            let week = ensureCurrentWeek()
            selectedGoalID = selectedGoalID ?? GoalOrdering.anchors(in: week).first?.id
            modelContext.saveChanges()
        }
        .padding(AnkerSpacing.s4)
        .frame(width: 300)
        .background(AnkerColor.surface)
    }

    private func save() {
        let week = ensureCurrentWeek()
        guard let currentDay = week.dayList.first(where: { AnkerCalendar.isSameDay($0.date, Date()) })
            ?? week.dayList.sorted(by: { $0.date < $1.date }).first else { return }
        guard TaskActions.create(
            title: title,
            priority: priority,
            on: currentDay,
            linkedGoal: week.goalList.first { $0.id == selectedGoalID },
            modelContext: modelContext
        ) != nil else { return }

        title = ""
        selectedGoalID = GoalOrdering.anchors(in: week).first?.id
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
            VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
                TextField("Was ist dein Wochenziel?", text: $title)
                    .textFieldStyle(.plain)
                    .ankerType(AnkerType.body)
                    .padding(.horizontal, AnkerSpacing.s3)
                    .padding(.vertical, AnkerSpacing.s2)
                    .ankerField()

                Text("Woche")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)

                weekPicker

                Text("Farbe")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)

                HStack(spacing: AnkerSpacing.s2) {
                    ForEach(colorOptions, id: \.self) { colorHex in
                        Button {
                            selectedColor = colorHex
                        } label: {
                            GoalColorSwatch(colorHex: colorHex, isSelected: selectedColor == colorHex)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Zielfarbe")
                    }
                }

                Text("\(selectedGoalCount)/4 Wochenziele")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)

                Spacer()
            }
            .padding(AnkerSpacing.s4)
            .background(AnkerColor.surface)
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
        HStack(spacing: AnkerSpacing.s2) {
            weekButton(ankerIcon: .previousMonth, label: "Vorheriger Monat") {
                moveSelectedMonth(by: -1)
            }

            weekButton(ankerIcon: .chevronLeft, label: "Vorherige Woche") {
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

            weekButton(ankerIcon: .chevronRight, label: "Nächste Woche") {
                moveSelectedWeek(by: 1)
            }

            weekButton(ankerIcon: .nextMonth, label: "Nächster Monat") {
                moveSelectedMonth(by: 1)
            }
        }
    }

    private func weekButton(ankerIcon: AnkerIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                .frame(width: 34, height: 34)
                .ankerControl()
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
        let goal = Goal(
            title: cleanTitle,
            colorHex: selectedColor,
            order: GoalOrdering.nextOrder(in: week),
            week: week
        )
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
                .ankerType(AnkerType.caption)
                .foregroundStyle(isSelected ? AnkerColor.onAccent : AnkerColor.inkSecond)
                .lineLimit(1)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s1)
                .ankerControl(
                    fill: isSelected ? selectedColor : Color.clear,
                    stroke: isSelected ? nil : AnkerColor.divider,
                    radius: AnkerRadius.tile
                )
        }
        .buttonStyle(.plain)
    }
}

/// Ein Farbfeld in der Zielfarbwahl — eine Auswahlkachel, also gerundet.
private struct GoalColorSwatch: View {
    let colorHex: String
    let isSelected: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: AnkerRadius.tile, style: .continuous)
    }

    var body: some View {
        shape
            .fill(AnkerColor.goalTint(colorHex))
            .frame(width: 24, height: 24)
            // Immer 2px — das System kennt keine Haarlinie. Den Zustand traegt die Farbe.
            .overlay(shape.stroke(edgeColor, lineWidth: AnkerBorder.rule))
            .contentShape(shape)
    }

    private var edgeColor: Color {
        isSelected ? AnkerColor.ink : AnkerColor.divider
    }
}
