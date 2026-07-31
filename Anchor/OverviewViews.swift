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

    let weeks: [Week]
    @State private var selectedDestination: AppDestination = .week
    @State private var showingNewTask = false

    private var currentWeek: Week? {
        let today = Date()
        let sortedWeeks = weeks.sorted { $0.monday < $1.monday }

        if let matchingWeek = sortedWeeks.first(where: { contains(today, in: $0) }) {
            return matchingWeek
        }

        return sortedWeeks.last
    }

    private var today: Day? {
        currentWeek?.dayList.first { AnkerCalendar.isSameDay($0.date, Date()) }
            ?? currentWeek?.dayList.sorted { $0.date < $1.date }.first
    }

    var body: some View {
        Group {
            if !hasCompletedOnboarding || weeks.isEmpty {
                OnboardingView {
                    completeOnboarding()
                }
            } else if let currentWeek, let today {
#if os(macOS)
                splitContent(week: currentWeek, day: today)
#else
                if horizontalClass == .regular {
                    splitContent(week: currentWeek, day: today)
                } else {
                    phoneContent(week: currentWeek, day: today)
                }
#endif
            } else {
                OnboardingView {
                    completeOnboarding()
                }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            if let currentWeek, let today {
                NewTaskSheet(day: today, goals: currentWeek.goalList)
                    .presentationDetents([.medium])
            }
        }
        .task {
            removeReferenceDataIfNeeded()
            if hasCompletedOnboarding {
                ensureCurrentWeekForOnboarding()
                try? modelContext.save()
            }
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
                        WeekOverviewView(week: week, selectedDay: day) {
                            showingNewTask = true
                        }
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
            .onAppear {
                if selectedDestination == .week {
                    selectedDestination = .today
                }
            }
        }
    }

    private func splitContent(week: Week, day: Day) -> some View {
        NavigationSplitView {
            SidebarView(week: week, selection: $selectedDestination)
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
                    WeekOverviewView(week: week, selectedDay: day) {
                        showingNewTask = true
                    }
                case .review:
                    WeeklyReviewView(week: week)
                case .goal(let id):
                    if let goal = week.goalList.first(where: { $0.id == id }) {
                        GoalDetailView(goal: goal, week: week)
                    } else {
                        WeekOverviewView(week: week, selectedDay: day) {
                            showingNewTask = true
                        }
                    }
                }
            }
            .toolbar {
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

    private func completeOnboarding() {
        removeReferenceDataIfNeeded()
        ensureCurrentWeekForOnboarding()
        hasCompletedOnboarding = true
        selectedDestination = .week
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
            ensureCurrentWeekForOnboarding()
        }

        try? modelContext.save()
        return true
    }

    @discardableResult
    private func ensureCurrentWeekForOnboarding() -> Week {
        let today = Date()

        if let existingWeek = weeks.first(where: { contains(today, in: $0) }) {
            ensureOnboardingDefaults(in: existingWeek)
            return existingWeek
        }

        return insertWeek(containing: today)
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
        let goal = Goal(title: "Erstes Wochenziel", colorHex: "#5B6EE8", week: week)
        week.goals = [goal]
        week.days = AnkerCalendar.daysInWeek(starting: interval.monday).map { date in
            Day(date: date, week: week)
        }
        modelContext.insert(week)
        return week
    }

    private func ensureOnboardingDefaults(in week: Week) {
        if week.goalList.isEmpty {
            week.goals = [Goal(title: "Erstes Wochenziel", colorHex: "#5B6EE8", week: week)]
        }

        if week.dayList.isEmpty {
            week.days = AnkerCalendar.daysInWeek(starting: week.monday).map { date in
                Day(date: date, week: week)
            }
        }
    }

    private func contains(_ date: Date, in week: Week) -> Bool {
        (week.monday...week.sunday).contains(date)
    }
}

struct SidebarView: View {
    let week: Week
    @Binding var selection: AppDestination

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
            }

            Section("\(week.isoYear)") {
                Button {
                    selection = .year
                } label: {
                    NavigationItemRow(color: AnkerColor.month[0], title: "Januar", isEmphasized: selection == .year)
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

                ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                    Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated).day(.twoDigits).month(.twoDigits)))
                        .font(.system(size: 11))
                        .foregroundStyle(AnkerColor.muted)
                        .padding(.leading, 14)
                }

                ForEach(Array(["Februar", "März"].enumerated()), id: \.offset) { index, month in
                    NavigationItemRow(color: AnkerColor.month[index + 1], title: month)
                }
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

struct WeekOverviewView: View {
    let week: Week
    let selectedDay: Day
    var onAddTask: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ChipButton(title: "◀ Index", isPrimary: true)
                ChipButton(title: "« KW 52")
                ChipButton(title: "KW 02 »")
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
