import SwiftData
import SwiftUI

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
    @State private var selectedDestination: AppDestination = .week
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
        return sortedDays?.first { AnkerCalendar.isSameDay($0.date, Date()) } ?? sortedDays?.first
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
            if let selectedWeek, let selectedDay {
                NewTaskSheet(day: selectedDay, goals: selectedWeek.goalList)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showingNewGoal) {
            if let selectedWeek {
                NewGoalSheet(week: selectedWeek)
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
                        }
                    case .week:
                        WeekOverviewView(week: week, selectedDay: day, onAddTask: {
                            showingNewTask = true
                        }, onAddGoal: {
                            showingNewGoal = true
                        }, onCurrentWeek: {
                            moveToCurrentWeek()
                        }, onPreviousWeek: {
                            moveWeek(by: -1)
                        }, onNextWeek: {
                            moveWeek(by: 1)
                        })
                    case .year:
                        YearOverviewView(week: week)
                    case .review:
                        WeeklyReviewView(week: week)
                    case .goal:
                        TodayView(day: day, week: week) {
                            showingNewTask = true
                        }
                    }
                }

                GlassTabBar(selection: $selectedDestination)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 16)
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
                selection: $selectedDestination,
                onPreviousMonth: { moveMonth(by: -1) },
                onNextMonth: { moveMonth(by: 1) },
                onCurrentWeek: { moveToCurrentWeek() },
                onAddGoal: {
                    showingNewGoal = true
                }
            )
        } detail: {
            Group {
                switch selectedDestination {
                case .today:
                    TodayView(day: day, week: week) {
                        showingNewTask = true
                    }
                case .year:
                    YearOverviewView(week: week)
                case .week:
                    WeekOverviewView(week: week, selectedDay: day, onAddTask: {
                        showingNewTask = true
                    }, onAddGoal: {
                        showingNewGoal = true
                    }, onCurrentWeek: {
                        moveToCurrentWeek()
                    }, onPreviousWeek: {
                        moveWeek(by: -1)
                    }, onNextWeek: {
                        moveWeek(by: 1)
                    })
                case .review:
                    WeeklyReviewView(week: week)
                case .goal(let id):
                    if let goal = week.goalList.first(where: { $0.id == id }) {
                        GoalDetailView(goal: goal, week: week)
                    } else {
                        WeekOverviewView(week: week, selectedDay: day, onAddTask: {
                            showingNewTask = true
                        }, onAddGoal: {
                            showingNewGoal = true
                        }, onCurrentWeek: {
                            moveToCurrentWeek()
                        }, onPreviousWeek: {
                            moveWeek(by: -1)
                        }, onNextWeek: {
                            moveWeek(by: 1)
                        })
                    }
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showingNewGoal = true
                    } label: {
                        Label("Neues Wochenziel", systemImage: "target")
                    }
                }
                ToolbarItem {
                    Button {
                        showingNewTask = true
                    } label: {
                        Label("Neue Aufgabe", systemImage: "plus")
                    }
                }
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

    private func completeOnboarding(with title: String) {
        removeReferenceDataIfNeeded()
        let week = ensureCurrentWeek()
        let goal = upsertOnboardingGoal(title: title, in: week)
        hasCompletedOnboarding = true
        onboardingVersion = requiredOnboardingVersion
        selectedWeekStart = week.monday
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
        let interval = AnkerCalendar.weekInterval(containing: date)

        if let existingWeek = weeks.first(where: { AnkerCalendar.isSameDay($0.monday, interval.monday) }) {
            ensureWeekDays(in: existingWeek)
            return existingWeek
        }

        return insertWeek(containing: date)
    }

    @discardableResult
    private func insertWeek(containing date: Date) -> Week {
        let interval = AnkerCalendar.weekInterval(containing: date)
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
        selectedWeekStart = AnkerCalendar.weekInterval(containing: target).monday
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func moveMonth(by offset: Int) {
        let calendar = AnkerCalendar.iso
        let target = calendar.date(byAdding: .month, value: offset, to: selectedWeekStart) ?? selectedWeekStart
        selectedWeekStart = AnkerCalendar.weekInterval(containing: target).monday
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }

    private func moveToCurrentWeek() {
        selectedWeekStart = AnkerCalendar.weekInterval(containing: Date()).monday
        selectedDestination = .week
        ensureSelectedWeek()
        try? modelContext.save()
    }
}

struct SidebarView: View {
    let week: Week
    @Binding var selection: AppDestination
    var onPreviousMonth: () -> Void = {}
    var onNextMonth: () -> Void = {}
    var onCurrentWeek: () -> Void = {}
    var onAddGoal: () -> Void = {}

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

    var body: some View {
        List {
            Section {
                Text("⌕ Ziele, Aufgaben, Notizen")
                    .font(.system(size: 11.5))
                    .foregroundStyle(AnkerColor.muted)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 9)
                    .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(AnkerColor.line))
                    .listRowBackground(Color.clear)

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
                }
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    selection = .year
                } label: {
                    NavigationItemRow(color: AnkerColor.month[max(weekMonthIndex, 0)], title: "Jahr", isEmphasized: selection == .year)
                }
                .buttonStyle(.plain)

                Button {
                    selection = .week
                } label: {
                    Text("Woche \(String(format: "%02d", week.isoWeek))")
                        .font(.system(size: 11.5, weight: selection == .week ? .bold : .semibold))
                        .foregroundStyle(selection == .week ? AnkerColor.indigoDark : AnkerColor.ink)
                }
                .buttonStyle(.plain)

                ForEach(monthGroups) { group in
                    NavigationItemRow(color: AnkerColor.month[group.month - 1], title: group.title(in: week.isoYear))
                        .padding(.top, 5)
                    ForEach(group.days, id: \.id) { day in
                        Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated).day(.twoDigits).month(.twoDigits)))
                            .font(.system(size: 11))
                            .foregroundStyle(AnkerColor.muted)
                            .padding(.leading, 18)
                    }
                }
            } header: {
                Text(verbatim: String(week.isoYear))
            }

            Section("Ziele") {
                ForEach(week.goalList, id: \.id) { goal in
                    Button {
                        selection = .goal(goal.id)
                    } label: {
                        Text(goal.title)
                            .font(.system(size: 12, weight: selection == .goal(goal.id) ? .bold : .medium))
                            .foregroundStyle(selection == .goal(goal.id) ? AnkerColor.indigoDark : AnkerColor.ink)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onAddGoal) {
                    Label("Neues Wochenziel", systemImage: "plus.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AnkerColor.indigoText)
                }
                .buttonStyle(.plain)
                .disabled(week.goalList.count >= 4)
            }

            Section {
                Button {
                    selection = .review
                } label: {
                    Text("Wochenrückblick")
                        .font(.system(size: 12, weight: selection == .review ? .bold : .medium))
                        .foregroundStyle(selection == .review ? AnkerColor.indigoDark : AnkerColor.ink)
                }
                .buttonStyle(.plain)
            }
        }
        .scrollContentBackground(.hidden)
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
        .navigationTitle("Anker")
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
}

private struct NavigationItemRow: View {
    let color: Color
    let title: String
    var isEmphasized = false

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 12.5, weight: isEmphasized ? .bold : .regular))
                .foregroundStyle(AnkerColor.ink)
        }
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
    let week: Week
    let selectedDay: Day
    var onAddTask: () -> Void = {}
    var onAddGoal: () -> Void = {}
    var onCurrentWeek: () -> Void = {}
    var onPreviousWeek: () -> Void = {}
    var onNextWeek: () -> Void = {}

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
                Button(action: onAddTask) {
                    Label("Neue Aufgabe", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                Button(action: onAddGoal) {
                    Image(systemName: "target")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Neues Wochenziel")
                .disabled(week.goalList.count >= 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }

            HStack(spacing: 10) {
                ForEach(week.goalList.prefix(4), id: \.id) { goal in
                    GoalPill(goal: goal)
                }
                if week.goalList.count < 4 {
                    Button(action: onAddGoal) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AnkerColor.indigoText)
                            .frame(maxWidth: .infinity, minHeight: 82)
                            .background(AnkerColor.card)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AnkerColor.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .help("Neues Wochenziel")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(AnkerColor.paper)
            .overlay(alignment: .bottom) { Rectangle().fill(AnkerColor.line).frame(height: 1) }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                        WeekGridRow(day: day, isToday: AnkerCalendar.isSameDay(day.date, selectedDay.date))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .background(AnkerColor.paper)
        }
        .navigationTitle("Wochenübersicht")
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
    let isToday: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide)))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(AnkerColor.ink)
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
        .padding(.horizontal, isToday ? 18 : 0)
        .background(isToday ? Color(hex: "#F3F4FF", darkHex: "#20243A") : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .bottom) { Rectangle().fill(AnkerColor.lineSoft).frame(height: 1) }
    }
}

private struct MiniTask: View {
    let task: AnkerTask

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(task.linkedGoal.map { Color(hex: $0.colorHex) } ?? AnkerColor.muted)
                .frame(width: 6, height: 6)
            Text(task.title)
                .font(.system(size: 10.5))
                .foregroundStyle(Color(hex: "#3A3D4A", darkHex: "#D8D9E0"))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AnkerColor.card)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(AnkerColor.line))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

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
