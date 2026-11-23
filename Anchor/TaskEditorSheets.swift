import SwiftData
import SwiftUI

/// Der vollständige Datensatz einer Aufgabe: Titel, Status, Woche, Tag, Anker.
///
/// Gesichert wird nur, was sich **geändert** hat. Vorher rief `save()` immer `move` auf — eine
/// Titeländerung an einer Aufgabe ohne Tag legte sie still auf heute und löste ihren Anker.
struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    @Bindable var task: AnkerTask
    /// Bekommt nach dem Sichern bzw. Löschen den Rückgängig-Hinweis.
    var onUndoableAction: ((TaskUndoNotice) -> Void)?

    @State private var title = ""
    @State private var isImportant = false
    @State private var isDone = false
    @State private var selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
    /// `nil` heißt „ohne Tag".
    @State private var selectedDate: Date?
    @State private var selectedGoalID: UUID?
    @State private var hasLoadedTask = false
    @State private var confirmsDelete = false

    private var selectedWeek: Week? {
        WeekPlanning.week(startingAt: selectedWeekStart, in: weeks)
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
                    statusAndImportance
                    weekPicker
                    dayPicker
                    goalPicker
                    destructiveActions
                }
                .padding(AnkerSpacing.s4)
            }
            .background(AnkerColor.ground)
            .ankerSheetChrome(
                "Aufgabe bearbeiten",
                cancel: AnkerSheetAction("Abbrechen") { dismiss() },
                confirm: AnkerSheetAction("Sichern", isDisabled: cleanTitle.isEmpty) {
                    save()
                    dismiss()
                }
            )
            .confirmationDialog("Aufgabe löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    let snapshot = TaskActions.snapshot(task)
                    TaskActions.delete(task, modelContext: modelContext)
                    onUndoableAction?(TaskUndoNotice(message: "Aufgabe gelöscht", snapshots: [snapshot]))
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

    /// Priorität zeigt „Blatt" nicht als Stufe A/B/C. Es bleibt ein Schalter „Wichtig" — er
    /// schreibt nur, wenn er umgelegt wird, eine bestehende Stufe C geht also nicht verloren.
    private var statusAndImportance: some View {
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
                Text("Wichtig")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)

                Toggle(isOn: $isImportant) {
                    Text(isImportant ? "Wichtig" : "Normal")
                        .ankerType(AnkerType.caption)
                }
                .toggleStyle(.switch)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .tint(AnkerColor.accentMark)
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
                    Text(verbatim: AnkerDateFormat.calendarWeek(selectedWeekInterval.isoWeek))
                        .ankerType(AnkerType.metaStrong)
                        .foregroundStyle(AnkerColor.ink)
                    Text(verbatim: TaskSheetFormat.span(selectedWeekInterval))
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
                    TaskDayTile(date: date, isSelected: selectedDate.map { AnkerCalendar.isSameDay(date, $0) } ?? false) {
                        selectedDate = date
                    }
                }
            }

            CaptureChip(title: String(localized: "Ohne Tag"), isSelected: selectedDate == nil, selectedColor: AnkerColor.accentFill) {
                selectedDate = nil
            }
            .accessibilityAddTraits(selectedDate == nil ? [.isButton, .isSelected] : .isButton)
        }
    }

    private var goalPicker: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text("Anker")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            FlowLayout(spacing: AnkerSpacing.s2) {
                ForEach(Array(selectedWeekGoals.enumerated()), id: \.element.id) { index, goal in
                    CaptureChip(title: "\(index + 1) · \(goal.title)", isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.accentFill) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: String(localized: "Ohne Anker"), isSelected: selectedGoalID == nil, selectedColor: AnkerColor.accentFill) {
                    selectedGoalID = nil
                }
            }

            if selectedWeekGoals.isEmpty {
                Text("Diese Woche hat noch keine Anker. Setze sie in der Woche, dann kannst du die Aufgabe hier verankern.")
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
        .foregroundStyle(AnkerColor.ink)
        .padding(.top, AnkerSpacing.s2)
    }

    private func iconButton(ankerIcon: AnkerIcon, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                .frame(width: 36, height: 36)
                .ankerControl()
                .ankerTapTarget(36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }

    private func loadTaskIfNeeded() {
        guard !hasLoadedTask else { return }
        title = task.title
        isImportant = task.priority == .a
        isDone = task.isDone
        // Der gemeinte Kalendertag, nicht der gespeicherte Zeitpunkt — ein Tag aus einer
        // anderen Zeitzone stuende sonst auf dem Vortag.
        selectedDate = task.day.flatMap { AnkerCalendar.iso.date(from: AnkerCalendar.nominalDay(ofStored: $0.date)) }
        // Ohne Tag zeigt der Editor die Woche des Ankers — dorthin gehört die Aufgabe.
        let anchorDate = selectedDate
            ?? task.linkedGoal?.week?.monday.addingTimeInterval(12 * 60 * 60)
            ?? Date()
        selectedWeekStart = AnkerCalendar.weekInterval(containing: anchorDate).monday
        selectedGoalID = task.linkedGoal?.id
        hasLoadedTask = true
    }

    private func moveSelectedWeek(by offset: Int) {
        guard let newWeekStart = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) else { return }

        selectedWeekStart = AnkerCalendar.weekInterval(containing: newWeekStart).monday
        if let date = selectedDate {
            selectedDate = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: date)
        }

        if selectedWeekGoals.allSatisfy({ $0.id != selectedGoalID }) {
            selectedGoalID = nil
        }
    }

    /// Schreibt nur die Felder, die sich geändert haben — jeweils über `TaskActions`.
    private func save() {
        let snapshot = TaskActions.snapshot(task)
        var changed = false

        if TaskActions.rename(task, to: cleanTitle, modelContext: modelContext) {
            changed = true
        }

        if let date = selectedDate {
            let isSameDay = task.day.map { AnkerCalendar.storedDay($0.date, isOn: date) } ?? false
            if !isSameDay {
                TaskActions.move(task, to: date, weeks: weeks, modelContext: modelContext)
                changed = true
            }
        } else if task.day != nil {
            TaskActions.unschedule(task, modelContext: modelContext)
            changed = true
        }

        // Nach dem Verschieben: `move` löst den Anker über eine Wochengrenze. Gesucht wird in
        // der gewählten Woche — mit Tag ist das die Woche des Tages, ohne Tag die angezeigte.
        let week = task.day?.week ?? selectedWeek
        let goal = week.flatMap { GoalOrdering.anchors(in: $0).first { $0.id == selectedGoalID } }
        if task.linkedGoal?.id != goal?.id {
            TaskActions.link(task, to: goal, modelContext: modelContext)
            changed = true
        }

        if isImportant != (task.priority == .a) {
            TaskActions.setPriority(task, to: isImportant ? .a : .b, modelContext: modelContext)
            changed = true
        }

        if isDone != task.isDone {
            TaskActions.setDone(task, isDone, modelContext: modelContext)
            changed = true
        }

        if changed {
            onUndoableAction?(TaskUndoNotice(message: "Aufgabe geändert", snapshots: [snapshot]))
        }
    }
}

/// Wochenspanne mit Halbgeviertstrich: „24.11.–30.11.".
enum TaskSheetFormat {
    static func span(_ interval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int)) -> String {
        "\(AnkerDateFormat.dayMonth(interval.monday))–\(AnkerDateFormat.dayMonth(interval.sunday))"
    }
}

/// Ein Tag in den Wochenwählern der Aufgabenblätter.
private struct TaskDayTile: View {
    let date: Date
    let isSelected: Bool
    var minHeight: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AnkerSpacing.s1) {
                Text(AnkerDateFormat.weekdayShort(date))
                    .ankerType(AnkerType.caption)
                Text(AnkerDateFormat.dayNumber(date))
                    .ankerType(AnkerType.numericSmall)
            }
            .foregroundStyle(isSelected ? AnkerColor.onAccent : AnkerColor.ink)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .ankerControl(
                fill: isSelected ? AnkerColor.accentFill : AnkerColor.surface,
                stroke: isSelected ? nil : AnkerColor.divider,
                radius: AnkerRadius.tile
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AnkerDateFormat.weekdayLongWithDayMonth(date))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct TaskMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    /// Auch Aufgaben ohne Tag: sie landen auf dem gewählten Tag. Ihr Anker bleibt, wenn der Tag
    /// in seiner Woche liegt — das entscheidet `TaskActions.move`.
    let tasks: [AnkerTask]
    var onMoved: (([TaskSnapshot]) -> Void)?

    @State private var selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
    @State private var selectedDate = Date()
    @State private var hasLoaded = false

    private var selectedWeekInterval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        AnkerCalendar.weekInterval(containing: selectedWeekStart)
    }

    private var movableTasks: [AnkerTask] {
        tasks.filter { !$0.isDeleted }
    }

    private var isPlanningOnly: Bool {
        movableTasks.allSatisfy { $0.day == nil }
    }

    private var heading: String {
        let count = movableTasks.count
        if count == 1 {
            return isPlanningOnly ? String(localized: "Aufgabe einplanen") : String(localized: "Aufgabe verschieben")
        }
        return isPlanningOnly
            ? String(localized: "\(count) Aufgaben einplanen")
            : String(localized: "\(count) Aufgaben verschieben")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(verbatim: heading)
                        .ankerType(AnkerType.taskTitle)
                        .foregroundStyle(AnkerColor.ink)
                    Text("Wähle Woche und Tag.")
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
                            Text(verbatim: AnkerDateFormat.calendarWeek(selectedWeekInterval.isoWeek))
                                .ankerType(AnkerType.metaStrong)
                                .foregroundStyle(AnkerColor.ink)
                            Text(verbatim: TaskSheetFormat.span(selectedWeekInterval))
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
                            TaskDayTile(date: date, isSelected: AnkerCalendar.isSameDay(date, selectedDate), minHeight: 46) {
                                selectedDate = date
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(AnkerSpacing.s4)
            .background(AnkerColor.ground)
            .ankerSheetChrome(
                isPlanningOnly ? "Einplanen" : "Verschieben",
                cancel: AnkerSheetAction("Abbrechen") { dismiss() },
                confirm: AnkerSheetAction(isPlanningOnly ? "Einplanen" : "Verschieben", isDisabled: movableTasks.isEmpty) {
                    moveTasks()
                    dismiss()
                }
            )
            .onAppear(perform: loadInitialDate)
        }
    }

    /// Mit Tag: der Tag der ersten Aufgabe. Ohne Tag: heute, wenn es in der Ankerwoche liegt,
    /// sonst deren Montag.
    private func loadInitialDate() {
        guard !hasLoaded else { return }
        if let stored = movableTasks.compactMap({ $0.day?.date }).first,
           let date = AnkerCalendar.iso.date(from: AnkerCalendar.nominalDay(ofStored: stored)) {
            selectedDate = date
        } else if let monday = movableTasks.compactMap({ $0.linkedGoal?.week?.monday }).first {
            let week = AnkerCalendar.weekInterval(containing: monday.addingTimeInterval(12 * 60 * 60))
            let today = Date()
            selectedDate = AnkerCalendar.weekInterval(containing: today).monday == week.monday ? today : week.monday
        } else {
            selectedDate = Date()
        }
        selectedWeekStart = AnkerCalendar.weekInterval(containing: selectedDate).monday
        hasLoaded = true
    }

    private func moveTasks() {
        let targets = movableTasks
        let snapshots = targets.map { TaskActions.snapshot($0) }
        for task in targets {
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

    private func moveButton(ankerIcon: AnkerIcon, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(ankerIcon).ankerIcon(AnkerIconSize.s)
                .frame(width: 38, height: 38)
                .ankerControl()
                .ankerTapTarget(38)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}
