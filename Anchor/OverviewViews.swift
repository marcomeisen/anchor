import SwiftData
import SwiftUI
import UniformTypeIdentifiers

enum AppDestination: Hashable {
    case today
    case year
    case week
    case review
    case goal(UUID)
}

struct AnkerRootView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingVersion") private var onboardingVersion = 0

    let weeks: [Week]
    @State private var selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
    @State private var selectedDayDate = Date()
    @State private var selectedDestination: AppDestination = .today
    @State private var showingNewTask = false
    @State private var showingNewGoal = false

    private let requiredOnboardingVersion = 2
    private let onboardingPlaceholderTitle = "Erstes Wochenziel"

    private var currentWeek: Week? {
        let today = Date()
        let sortedWeeks = weeks.sorted { $0.monday < $1.monday }
        return sortedWeeks.first(where: { contains(today, in: $0) })
    }

    private var selectedWeek: Week? {
        weeks.first { AnkerCalendar.isSameDay($0.monday, selectedWeekStart) }
    }

    private var selectedDay: Day? {
        let sortedDays = selectedWeek?.dayList.sorted { $0.date < $1.date }
        return sortedDays?.first { AnkerCalendar.isSameDay($0.date, selectedDayDate) }
            ?? sortedDays?.first { AnkerCalendar.isSameDay($0.date, Date()) }
            ?? sortedDays?.first
    }

    private var needsOnboarding: Bool {
        guard let currentWeek else { return !hasCompletedOnboarding }
        return currentWeek.goalList.filter(isUserCreatedGoal).isEmpty
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView(weekIntervalTitle: currentWeekTitle) { title in
                    completeOnboarding(with: title)
                }
            } else if let selectedWeek, let selectedDay {
#if os(macOS)
                splitContent(week: selectedWeek, day: selectedDay)
#else
                if horizontalClass == .regular {
                    splitContent(week: selectedWeek, day: selectedDay)
                } else {
                    phoneContent(week: selectedWeek, day: selectedDay)
                }
#endif
            } else {
                ProgressView()
                    .task {
                        ensureSelectedWeek()
                    }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            if let selectedDay {
                NewTaskSheet(day: selectedDay) { date in
                    moveToPlannedDate(date)
                }
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showingNewGoal) {
            if let selectedWeek {
                NewGoalSheet(week: selectedWeek) { date in
                    moveToPlannedDate(date)
                }
                    .presentationDetents([.medium])
            }
        }
        .task {
            removeReferenceDataIfNeeded()
            ensureCurrentWeek()
            ensureSelectedWeek()
            try? modelContext.save()
        }
    }

    @Environment(\.horizontalSizeClass) private var horizontalClass

    private func phoneContent(week: Week, day: Day) -> some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Group {
                    switch selectedDestination {
                    case .today:
                        TodayView(day: day, week: week) {
                            showingNewTask = true
                        } onSelectDay: { selectedDay in
                            selectDay(selectedDay)
                        }
                    case .week:
                        WeekOverviewView(week: week, selectedDay: day, onCurrentWeek: {
                            moveToCurrentWeek()
                        }, onPreviousWeek: {
                            moveWeek(by: -1)
                        }, onNextWeek: {
                            moveWeek(by: 1)
                        }, onSelectDay: { selectedDay in
                            selectDay(selectedDay)
                        })
                    case .year:
                        YearOverviewView(week: week)
                    case .review:
                        WeeklyReviewView(week: week)
                    case .goal:
                        TodayView(day: day, week: week) {
                            showingNewTask = true
                        } onSelectDay: { selectedDay in
                            selectDay(selectedDay)
                        }
                    }
                }

                GlassTabBar(selection: $selectedDestination)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
            }
            .toolbar {
                creationToolbarItems
            }
#if os(iOS)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
#endif
        }
    }

    private func splitContent(week: Week, day: Day) -> some View {
        NavigationSplitView {
            SidebarView(
                week: week,
                weeks: weeks,
                selection: $selectedDestination,
                selectedDay: day,
                onPreviousMonth: { moveMonth(by: -1) },
                onNextMonth: { moveMonth(by: 1) },
                onCurrentWeek: { moveToCurrentWeek() },
                onSelectWeek: { moveToWeek(starting: $0) },
                onSelectDay: { selectedDay in
                    selectDay(selectedDay)
                }
            )
        } detail: {
            Group {
                switch selectedDestination {
                case .today:
                    TodayView(day: day, week: week) {
                        showingNewTask = true
                    } onSelectDay: { selectedDay in
                        selectDay(selectedDay)
                    }
                case .year:
                    YearOverviewView(week: week)
                case .week:
                    WeekOverviewView(week: week, selectedDay: day, onCurrentWeek: {
                        moveToCurrentWeek()
                    }, onPreviousWeek: {
                        moveWeek(by: -1)
                    }, onNextWeek: {
                        moveWeek(by: 1)
                    }, onSelectDay: { selectedDay in
                        selectDay(selectedDay)
                    })
                case .review:
                    WeeklyReviewView(week: week)
                case .goal(let id):
                    if let goal = week.goalList.first(where: { $0.id == id }) {
                        GoalDetailView(goal: goal, week: week)
                    } else {
                        WeekOverviewView(week: week, selectedDay: day, onCurrentWeek: {
                            moveToCurrentWeek()
                        }, onPreviousWeek: {
                            moveWeek(by: -1)
                        }, onNextWeek: {
                            moveWeek(by: 1)
                        }, onSelectDay: { selectedDay in
                            selectDay(selectedDay)
                        })
                    }
                }
            }
            .toolbar {
                creationToolbarItems
            }
#if os(macOS)
            .toolbarBackground(.visible, for: .windowToolbar)
            .toolbarBackground(.regularMaterial, for: .windowToolbar)
#endif
        }
    }

    private var currentWeekTitle: String {
        let interval = AnkerCalendar.weekInterval(containing: Date())
        let start = interval.monday.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits))
        let end = interval.sunday.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
        return "\(start) - \(end)"
    }

    @ToolbarContentBuilder
    private var creationToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showingNewGoal = true
            } label: {
                Image(systemName: "target")
            }
            .help((selectedWeek?.goalList.count ?? 0) >= 4 ? "Maximal 4 Wochenziele pro Woche" : "Neues Wochenziel erstellen")
            .accessibilityLabel("Neues Wochenziel erstellen")
            .disabled((selectedWeek?.goalList.count ?? 0) >= 4)

            Button {
                showingNewTask = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Neue Aufgabe erstellen")
            .accessibilityLabel("Neue Aufgabe erstellen")
        }
    }

    private func completeOnboarding(with title: String) {
        removeReferenceDataIfNeeded()
        let week = ensureCurrentWeek()
        let goal = upsertOnboardingGoal(title: title, in: week)
        hasCompletedOnboarding = true
        onboardingVersion = requiredOnboardingVersion
        selectedWeekStart = week.monday
        selectedDayDate = Date()
        selectedDestination = .goal(goal.id)
        try? modelContext.save()
    }

    @discardableResult
    private func removeReferenceDataIfNeeded() -> Bool {
        let referenceWeeks = weeks.filter(SampleData.isReferenceWeek)
        guard !referenceWeeks.isEmpty else { return false }

        for week in referenceWeeks {
            modelContext.delete(week)
        }

        if hasCompletedOnboarding && weeks.allSatisfy(SampleData.isReferenceWeek) {
            ensureCurrentWeek()
        }

        try? modelContext.save()
        return true
    }

    @discardableResult
    private func ensureCurrentWeek() -> Week {
        ensureWeek(containing: Date())
    }

    @discardableResult
    private func ensureSelectedWeek() -> Week {
        ensureWeek(containing: selectedWeekStart)
    }

    @discardableResult
    private func ensureWeek(containing date: Date) -> Week {
        TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
    }

    private func upsertOnboardingGoal(title: String, in week: Week) -> Goal {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let placeholder = week.goalList.first(where: { isPlaceholderGoal($0) }) {
            placeholder.title = cleanTitle
            placeholder.colorHex = "#5B6EE8"
            return placeholder
        }

        let goal = Goal(title: cleanTitle, colorHex: "#5B6EE8", week: week)
        modelContext.insert(goal)
        week.appendGoal(goal)
        return goal
    }

    private func isUserCreatedGoal(_ goal: Goal) -> Bool {
        let title = goal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && !isPlaceholderGoal(goal)
    }

    private func isPlaceholderGoal(_ goal: Goal) -> Bool {
        goal.title.trimmingCharacters(in: .whitespacesAndNewlines) == onboardingPlaceholderTitle
            && goal.taskList.isEmpty
    }

    private func contains(_ date: Date, in week: Week) -> Bool {
        let nextMonday = AnkerCalendar.iso.date(byAdding: .day, value: 7, to: week.monday) ?? week.sunday
        return date >= week.monday && date < nextMonday
    }

    private func moveWeek(by offset: Int) {
        let target = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedWeekStart) ?? selectedWeekStart
        let targetDay = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: selectedDayDate) ?? target
        selectedWeekStart = AnkerCalendar.weekInterval(containing: target).monday
        selectedDayDate = targetDay
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func moveMonth(by offset: Int) {
        let calendar = AnkerCalendar.iso
        let target = calendar.date(byAdding: .month, value: offset, to: selectedWeekStart) ?? selectedWeekStart
        let targetDay = calendar.date(byAdding: .month, value: offset, to: selectedDayDate) ?? target
        selectedWeekStart = AnkerCalendar.weekInterval(containing: target).monday
        selectedDayDate = targetDay
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func moveToCurrentWeek() {
        selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
        selectedDayDate = Date()
        selectedDestination = .today
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func moveToWeek(starting monday: Date) {
        selectedWeekStart = AnkerCalendar.weekInterval(containing: monday).monday
        selectedDayDate = monday
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func selectDay(_ day: Day) {
        selectedWeekStart = AnkerCalendar.weekInterval(containing: day.date).monday
        selectedDayDate = day.date
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func moveToPlannedDate(_ date: Date) {
        selectedWeekStart = AnkerCalendar.weekInterval(containing: date).monday
        selectedDayDate = date
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }
}

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext

    let week: Week
    let weeks: [Week]
    @Binding var selection: AppDestination
    let selectedDay: Day
    var onPreviousMonth: () -> Void = {}
    var onNextMonth: () -> Void = {}
    var onCurrentWeek: () -> Void = {}
    var onSelectWeek: (Date) -> Void = { _ in }
    var onSelectDay: (Day) -> Void = { _ in }

    @State private var targetedWeekStart: Date?

    private var monthGroups: [SidebarMonthGroup] {
        let calendar = Calendar.current
        let sortedDays = week.dayList.sorted { $0.date < $1.date }
        return sortedDays.reduce(into: [SidebarMonthGroup]()) { groups, day in
            let components = calendar.dateComponents([.year, .month], from: day.date)
            let month = components.month ?? 1
            let year = components.year ?? week.isoYear

            if let lastIndex = groups.indices.last,
               groups[lastIndex].month == month,
               groups[lastIndex].year == year {
                groups[lastIndex].days.append(day)
            } else {
                groups.append(SidebarMonthGroup(year: year, month: month, days: [day]))
            }
        }
    }

    private var sidebarWeekTargets: [SidebarWeekTarget] {
        (-1...2).compactMap { offset in
            guard let date = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: week.monday) else { return nil }
            let interval = AnkerCalendar.weekInterval(containing: date)
            let existingWeek = weeks.first { AnkerCalendar.isSameDay($0.monday, interval.monday) }
            return SidebarWeekTarget(
                id: interval.monday,
                monday: interval.monday,
                isoYear: interval.isoYear,
                isoWeek: interval.isoWeek,
                isActive: AnkerCalendar.isSameDay(interval.monday, week.monday),
                isExisting: existingWeek != nil
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                searchField
                monthNavigation

                Text(verbatim: String(week.isoYear))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)
                    .tracking(0.48)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                ForEach(monthGroups) { group in
                    monthSection(group)
                }

                goalsSection
                reviewSection
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .background(.regularMaterial)
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [.black.opacity(0.08), .clear],
                startPoint: .trailing,
                endPoint: .leading
            )
            .frame(width: 18)
            .allowsHitTesting(false)
        }
        .navigationTitle("Fyndara")
    }

    private var searchField: some View {
        Text("⌕ Ziele, Aufgaben, Notizen")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AnkerColor.muted)
            .lineLimit(1)
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))
    }

    private var monthNavigation: some View {
        HStack(spacing: 8) {
            monthNavigationButton(systemName: "chevron.left", help: "Vorheriger Monat", action: onPreviousMonth)

            Button(action: onCurrentWeek) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnkerColor.indigoText)
                    .frame(width: 28, height: 26)
                    .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AnkerColor.line))
            }
            .buttonStyle(.plain)
            .help("Laufende Woche")

            monthNavigationButton(systemName: "chevron.right", help: "Nächster Monat", action: onNextMonth)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private func monthSection(_ group: SidebarMonthGroup) -> some View {
        let groupTargets = sidebarWeekTargets.filter { belongs($0, to: group) }

        NavigationItemRow(
            color: AnkerColor.month[group.month - 1],
            title: group.title(in: week.isoYear),
            isEmphasized: group.days.contains { day in
                AnkerCalendar.isSameDay(day.date, selectedDay.date)
            },
            isOpen: true
        )

        ForEach(groupTargets) { target in
            weekDropButton(target)

            if target.isActive {
                ForEach(group.days, id: \.id) { day in
                    sidebarDayButton(day)
                }
            }
        }

        if !groupTargets.contains(where: \.isActive) {
            ForEach(group.days, id: \.id) { day in
                sidebarDayButton(day)
            }
        }
    }

    private func sidebarDayButton(_ day: Day) -> some View {
        Button {
            onSelectDay(day)
        } label: {
            SidebarDayRow(
                day: day,
                isSelected: AnkerCalendar.isSameDay(day.date, selectedDay.date)
            )
        }
        .buttonStyle(.plain)
        .help("Tag auswählen und Aufgabe mit + für diesen Tag anlegen")
        .accessibilityLabel("Tag \(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide).day().month())) auswählen")
    }

    private func weekDropButton(_ target: SidebarWeekTarget) -> some View {
        Button {
            onSelectWeek(target.monday)
            selection = target.isActive ? .today : .week
        } label: {
            SidebarWeekDropRow(
                target: target,
                isSelected: target.isActive,
                isDropTarget: targetedWeekStart.map { AnkerCalendar.isSameDay($0, target.monday) } ?? false
            )
        }
        .buttonStyle(.plain)
        .help("Aufgabe auf Woche \(String(format: "%02d", target.isoWeek)) verschieben")
        .onDrop(
            of: [UTType.plainText],
            isTargeted: Binding(
                get: { targetedWeekStart.map { AnkerCalendar.isSameDay($0, target.monday) } ?? false },
                set: { isTargeted in targetedWeekStart = isTargeted ? target.monday : nil }
            )
        ) { providers in
            dropTask(from: providers, on: target)
        }
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            if !week.goalList.isEmpty {
                Text("Ziele")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
            }

            ForEach(week.goalList, id: \.id) { goal in
                Button {
                    selection = .goal(goal.id)
                } label: {
                    Text(goal.title)
                        .font(.system(size: 12, weight: selection == .goal(goal.id) ? .bold : .medium))
                        .foregroundStyle(selection == .goal(goal.id) ? AnkerColor.indigoDark : AnkerColor.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reviewSection: some View {
        Button {
            selection = .review
        } label: {
            Text("Wochenrückblick")
                .font(.system(size: 12, weight: selection == .review ? .bold : .medium))
                .foregroundStyle(selection == .review ? AnkerColor.indigoDark : AnkerColor.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func belongs(_ target: SidebarWeekTarget, to group: SidebarMonthGroup) -> Bool {
        let calendar = Calendar.current
        let targetMonth = calendar.component(.month, from: target.monday)
        let targetYear = calendar.component(.year, from: target.monday)
        return targetMonth == group.month && targetYear == group.year
    }

    private var weekMonthIndex: Int {
        Calendar.current.component(.month, from: week.monday) - 1
    }

    private func monthNavigationButton(systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnkerColor.ink)
                .frame(width: 28, height: 26)
                .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(AnkerColor.line))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func dropTask(from providers: [NSItemProvider], on target: SidebarWeekTarget) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let rawID = object as? String ?? (object as? NSString)?.description,
                  let taskID = UUID(uuidString: rawID) else { return }

            Task { @MainActor in
                guard let task = task(with: taskID) else { return }
                TaskActions.move(task, to: target.monday, weeks: weeks, modelContext: modelContext)
                onSelectWeek(target.monday)
                selection = .week
                targetedWeekStart = nil
                TaskDragEvents.end(taskID: taskID)
            }
        }

        return true
    }

    private func task(with id: UUID) -> AnkerTask? {
        weeks
            .flatMap(\.dayList)
            .flatMap(\.taskList)
            .first { $0.id == id }
    }
}

private struct SidebarWeekTarget: Identifiable {
    let id: Date
    let monday: Date
    let isoYear: Int
    let isoWeek: Int
    let isActive: Bool
    let isExisting: Bool
}

private struct SidebarWeekDropRow: View {
    let target: SidebarWeekTarget
    let isSelected: Bool
    let isDropTarget: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("Woche \(String(format: "%02d", target.isoWeek))")
                .font(.system(size: 12, weight: isSelected || isDropTarget ? .bold : .semibold))
            if isDropTarget {
                Text("← Ziel")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(AnkerColor.indigoText)
            } else if !target.isExisting {
                Image(systemName: "plus.circle")
                    .font(.system(size: 9.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)
                    .help("Woche wird beim Ablegen angelegt")
            }
        }
        .foregroundStyle(isSelected ? .white : (isDropTarget ? AnkerColor.indigoText : AnkerColor.ink))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 28)
        .padding(.trailing, 8)
        .padding(.vertical, 5)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isDropTarget ? AnkerColor.indigo : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isDropTarget ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }

    private var backgroundStyle: some ShapeStyle {
        if isDropTarget {
            return AnyShapeStyle(AnkerColor.indigo.opacity(0.16))
        }

        if isSelected {
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: "#7688EE"), AnkerColor.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
        }

        return AnyShapeStyle(Color.clear)
    }
}

private struct NavigationItemRow: View {
    let color: Color
    let title: String
    var isEmphasized = false
    var isOpen = false

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 12.5, weight: isEmphasized ? .bold : .regular))
                .foregroundStyle(AnkerColor.ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isOpen ? AnkerColor.indigo.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SidebarDayRow: View {
    let day: Day
    let isSelected: Bool

    var body: some View {
        Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated).day(.twoDigits).month(.twoDigits)))
            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
            .foregroundStyle(isSelected ? AnkerColor.indigoText : AnkerColor.muted)
            .padding(.leading, 42)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AnkerColor.indigo.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct SidebarMonthGroup: Identifiable {
    let year: Int
    let month: Int
    var days: [Day]

    var id: String { "\(year)-\(month)" }

    func title(in currentYear: Int) -> String {
        let monthName = Calendar.current.monthSymbols[month - 1]
        return year == currentYear ? monthName : "\(monthName) \(year)"
    }
}

struct WeekOverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let week: Week
    let selectedDay: Day
    var onCurrentWeek: () -> Void = {}
    var onPreviousWeek: () -> Void = {}
    var onNextWeek: () -> Void = {}
    var onSelectDay: (Day) -> Void = { _ in }

    @State private var targetedDayID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ChipButton(title: "Heute", isPrimary: true, action: onCurrentWeek)
                ChipButton(title: "« KW \(weekLabel(offset: -1))", action: onPreviousWeek)
                ChipButton(title: "KW \(weekLabel(offset: 1)) »", action: onNextWeek)
                Spacer()
                Text("\(shortDate(week.monday)) – \(shortDate(week.sunday))")
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
        .help("Tag auswählen oder Aufgabe hierher ziehen")
        .onDrop(
            of: [UTType.plainText],
            isTargeted: Binding(
                get: { targetedDayID == day.id },
                set: { isTargeted in targetedDayID = isTargeted ? day.id : nil }
            )
        ) { providers in
            dropTask(from: providers, on: day)
        }
    }

    private func dropTask(from providers: [NSItemProvider], on targetDay: Day) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: NSString.self) }) else { return false }

        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let rawID = object as? String ?? (object as? NSString)?.description,
                  let taskID = UUID(uuidString: rawID) else { return }

            Task { @MainActor in
                guard let task = task(with: taskID) else { return }
                TaskActions.move(task, to: targetDay.date, weeks: weeks, modelContext: modelContext)
                targetedDayID = nil
                onSelectDay(targetDay)
                TaskDragEvents.end(taskID: taskID)
            }
        }

        return true
    }

    private func task(with id: UUID) -> AnkerTask? {
        weeks
            .flatMap(\.dayList)
            .flatMap(\.taskList)
            .first { $0.id == id }
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
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
                Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide)))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(isSelected ? AnkerColor.indigoText : AnkerColor.ink)
                Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits)))
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
            return AnyShapeStyle(Color(hex: "#F3F4FF", darkHex: "#20243A"))
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
                    .foregroundStyle(task.isDone ? AnkerColor.muted : Color(hex: "#3A3D4A", darkHex: "#D8D9E0"))
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

struct YearOverviewView: View {
    let week: Week

    private let monthNames = Calendar.current.monthSymbols

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(week.isoYear) — 52 Wochen, 3 von 4 Wochenzielen aktiv")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AnkerColor.ink)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(0..<12, id: \.self) { index in
                    VStack(alignment: .leading) {
                        Text(monthNames[index])
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(Color(hex: "#1C1E27"))
                        Spacer()
                        Text(index == 0 ? "3/4 Ziele erreicht" : "—")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "#1C1E27").opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                    .padding(12)
                    .background(AnkerColor.month[index])
                    .overlay {
                        if index == 0 {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AnkerColor.indigo, lineWidth: 2)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("\(monthNames[index]), \(index == 0 ? "3 von 4 Ziele erreicht" : "keine Ziele")")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(AnkerColor.paper)
        }
        .navigationTitle("Jahresübersicht")
    }
}
