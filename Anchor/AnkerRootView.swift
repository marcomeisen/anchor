import SwiftData
import SwiftUI

/// Verteilt auf Onboarding, Split-Layout (Mac, iPad) und iPhone-Layout und haelt den
/// Navigationszustand.
///
/// Die Logik selbst liegt nicht mehr hier: Wochen und Tage aufloesen macht `WeekPlanning`,
/// Navigation und Deep Links `AnkerNavigationState`. Uebrig bleibt die Verdrahtung.
struct AnkerRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalClass

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingVersion") private var onboardingVersion = 0

    /// Injizierbar, damit Previews und Tests eine stille Instanz einsetzen koennen.
    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared

    let weeks: [Week]

    /// `@SceneStorage` statt `@State`: damit steht die App nach einem Neustart wieder in der
    /// Woche und auf dem Tag, an denen zuletzt gearbeitet wurde. Auf dem Mac gilt das je
    /// Fenster.
    @SceneStorage("navigation") private var storedNavigation: String?
    @State private var navigation = AnkerNavigationState()

    @State private var showingNewTask = false
    @State private var showingNewGoal = false
    @State private var showingSearch = false

    /// Beim Erhoehen zeigt das Onboarding erneut. Bisher nur fuer den Schritt von der ersten
    /// auf die zweite Fassung genutzt.
    private let requiredOnboardingVersion = 2

    private var selectedWeek: Week? {
        WeekPlanning.week(startingAt: navigation.weekStart, in: weeks)
    }

    private var selectedDay: Day? {
        WeekPlanning.day(on: navigation.dayDate, in: selectedWeek)
    }

    private var needsOnboarding: Bool {
        WeekPlanning.needsOnboarding(in: weeks, hasCompletedOnboarding: hasCompletedOnboarding)
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
                    .task { ensureSelectedWeek() }
            }
        }
        .sheet(isPresented: $showingNewTask) {
            if let selectedDay {
                NewTaskSheet(day: selectedDay) { date in
                    navigation.moveToPlannedDate(date)
                    ensureSelectedWeek()
                }
                .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $showingNewGoal) {
            if let selectedWeek {
                NewGoalSheet(week: selectedWeek) { date in
                    navigation.moveToPlannedDate(date)
                    ensureSelectedWeek()
                }
                .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchSheet(weeks: weeks) { result in
                open(result)
            }
        }
        .task {
            restoreNavigationIfPossible()
            ensureCurrentWeek()
            ensureSelectedWeek()
            modelContext.saveChanges()
        }
        // Laeuft beim Start und nach jedem CloudKit-Import erneut.
        //
        // Vorher war der Schluessel `StoreMaintenance.duplicateSignature(for: weeks)` — das
        // gruppierte bei **jeder** `body`-Auswertung alle Wochen und Tage, bei einem Jahr
        // Nutzung also rund 364 Tage pro Durchlauf. Der Zaehler aus dem Sync-Status ist nicht
        // nur billiger, er trifft die Absicht genauer: Duplikate entstehen ausschliesslich
        // dadurch, dass ein Import eine Woche einspielt, die lokal schon existiert.
        .task(id: cloudSyncStatus.remoteChangeCount) {
            StoreMaintenance.normalize(weeks: weeks, modelContext: modelContext)
        }
        .onChange(of: navigation) { _, newValue in
            storedNavigation = newValue.encoded
        }
        .onOpenURL { url in
            guard navigation.apply(url) else { return }
            ensureSelectedWeek()
            modelContext.saveChanges()
        }
    }

    // MARK: - Layouts

    /// iPhone: Tabs unten, Detailansichten auf einem echten Navigationsstapel.
    ///
    /// Der Stapel wird aus dem Navigationszustand abgeleitet statt getrennt gefuehrt — so
    /// bleiben Zurueck-Gestik, Tab-Auswahl und Wiederherstellung dieselbe Quelle. Vorher war
    /// `.day` ein Tab-Ziel ohne Stapel: kein Zurueckwischen, nur ein Schliessen-Knopf.
    private func phoneContent(week: Week, day: Day) -> some View {
        NavigationStack(path: pushedPath) {
            ZStack(alignment: .bottom) {
                topLevelContent(week: week, day: day)

                GlassTabBar(selection: topLevelSelection)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
            .navigationDestination(for: AppDestination.self) { destination in
                detailContent(for: destination, week: week, day: day)
            }
            .toolbar {
                creationToolbarItems
#if os(iOS)
                searchToolbarItem
                syncStatusToolbarItem
#endif
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
                selection: destinationSelection,
                selectedDay: day,
                onPreviousMonth: { move { $0.moveMonth(by: -1) } },
                onNextMonth: { move { $0.moveMonth(by: 1) } },
                onCurrentWeek: { move { $0.moveToToday() } },
                onSelectWeek: { monday in move { $0.moveToWeek(startingAt: monday) } },
                onSelectDay: { day in move { $0.openDay(on: day.date) } },
                onFocusDay: { day in move { $0.focus(on: day.date) } },
                onSelectSearchResult: { open($0) }
            )
        } detail: {
            Group {
                if navigation.destination.isTopLevel {
                    topLevelContent(week: week, day: day)
                } else {
                    detailContent(for: navigation.destination, week: week, day: day)
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

    @ViewBuilder
    private func topLevelContent(week: Week, day: Day) -> some View {
        switch navigation.topLevel {
        case .today:
            todayView(day: day, week: week)
        case .week:
            weekOverview(week: week, day: day)
        case .year:
            YearOverviewView(week: week, weeks: weeks)
        case .review:
            WeeklyReviewView(week: week)
        case .day, .goal:
            // Kann nicht auftreten: `topLevel` nimmt nur oberste Ebenen an.
            todayView(day: day, week: week)
        }
    }

    @ViewBuilder
    private func detailContent(for destination: AppDestination, week: Week, day: Day) -> some View {
        switch destination {
        case .day:
            dayDetail(day: day, week: week)
        case .goal(let id):
            if let goal = week.goalList.first(where: { $0.id == id }) {
                GoalDetailView(goal: goal, week: week) { navigation.popToTopLevel() }
            } else {
                // Etwa nach einem Sync, der das Ziel auf einem anderen Geraet entfernt hat.
                weekOverview(week: week, day: day)
            }
        case .today, .week, .year, .review:
            topLevelContent(week: week, day: day)
        }
    }

    // MARK: - Bindings

    /// Genau ein Element auf dem Stapel, solange eine Detailansicht offen ist. Leert der
    /// Nutzer den Stapel per Zurueck-Gestik, fuehrt das auf die Ebene zurueck, aus der die
    /// Detailansicht geoeffnet wurde.
    private var pushedPath: Binding<[AppDestination]> {
        Binding(
            get: { navigation.isPushed ? [navigation.destination] : [] },
            set: { path in
                if let last = path.last {
                    navigation.select(last)
                } else {
                    navigation.popToTopLevel()
                }
            }
        )
    }

    private var topLevelSelection: Binding<AppDestination> {
        Binding(
            get: { navigation.topLevel },
            set: { navigation.select($0) }
        )
    }

    private var destinationSelection: Binding<AppDestination> {
        Binding(
            get: { navigation.destination },
            set: { navigation.select($0) }
        )
    }

    // MARK: - Einzelansichten

    private func todayView(day: Day, week: Week) -> some View {
        TodayView(
            day: day,
            week: week,
            onAddTask: { showingNewTask = true },
            onSelectDay: { day in move { $0.openDay(on: day.date) } },
            onFocusDay: { day in move { $0.focus(on: day.date) } }
        )
    }

    private func weekOverview(week: Week, day: Day) -> some View {
        WeekOverviewView(
            week: week,
            selectedDay: day,
            onCurrentWeek: { move { $0.moveToToday() } },
            onPreviousWeek: { move { $0.moveWeek(by: -1) } },
            onNextWeek: { move { $0.moveWeek(by: 1) } },
            onSelectDay: { day in move { $0.openDay(on: day.date) } },
            onFocusDay: { day in move { $0.focus(on: day.date) } }
        )
    }

    private func dayDetail(day: Day, week: Week) -> some View {
        DayDetailView(
            day: day,
            week: week,
            onAddTask: { showingNewTask = true },
            onSelectGoal: { goal in navigation.select(.goal(goal.id)) },
            onClose: { navigation.popToTopLevel() }
        )
    }

    // MARK: - Werkzeugleiste

#if os(iOS)
    /// Nur im iPhone-Zweig: die Sidebar mit `CloudSyncStatusRow` gibt es hier nicht,
    /// im iPad-Split dagegen schon — dort waere das Badge doppelt.
    @ToolbarContentBuilder
    private var syncStatusToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            CloudSyncStatusBadge(status: cloudSyncStatus)
        }
    }

    /// Links, weil rechts schon Anlegen-Buttons und der Sync-Status sitzen — und nicht
    /// `.principal`, das den Titel der jeweiligen Ansicht ersetzen wuerde.
    @ToolbarContentBuilder
    private var searchToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .help("Ziele, Aufgaben und Notizen durchsuchen")
            .accessibilityLabel("Suchen")
        }
    }
#endif

    @ToolbarContentBuilder
    private var creationToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                showingNewGoal = true
            } label: {
                Image(systemName: "target")
            }
            .help(hasMaximumGoals ? "Maximal 4 Wochenziele pro Woche" : "Neues Wochenziel erstellen")
            .accessibilityLabel("Neues Wochenziel erstellen")
            .disabled(hasMaximumGoals)

            Button {
                showingNewTask = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Neue Aufgabe erstellen")
            .accessibilityLabel("Neue Aufgabe erstellen")
        }
    }

    private var hasMaximumGoals: Bool {
        (selectedWeek?.goalList.count ?? 0) >= 4
    }

    private var currentWeekTitle: String {
        let interval = AnkerCalendar.weekInterval(containing: Date())
        return AnkerDateFormat.weekSpan(monday: interval.monday, sunday: interval.sunday)
    }

    // MARK: - Aktionen

    /// Jede Navigationsaenderung nach demselben Muster: Zustand aendern, Zielwoche anlegen,
    /// speichern. Vorher stand diese Dreierfolge in acht Methoden je einmal.
    private func move(_ change: (inout AnkerNavigationState) -> Void) {
        change(&navigation)
        ensureSelectedWeek()
        modelContext.saveChanges()
    }

    private func open(_ result: AnkerSearch.Result) {
        let dayDate = result.dayID.flatMap { WeekPlanning.day(withID: $0, in: weeks)?.date }
        move { $0.open(result, dayDate: dayDate) }
    }

    private func completeOnboarding(with title: String) {
        let week = ensureCurrentWeek()
        let goal = WeekPlanning.upsertOnboardingGoal(title: title, in: week, modelContext: modelContext)
        hasCompletedOnboarding = true
        onboardingVersion = requiredOnboardingVersion
        navigation.moveToWeek(startingAt: week.monday)
        navigation.focus(on: Date())
        navigation.select(.goal(goal.id))
        modelContext.saveChanges()
    }

    /// Nur beim Start und nur, wenn wirklich etwas gespeichert war — sonst wuerde der
    /// Standardzustand die Auswahl ueberschreiben, die ein Deep Link gerade gesetzt hat.
    private func restoreNavigationIfPossible() {
#if DEBUG
        // UI-Tests sollen immer gleich anfangen; `@SceneStorage` ueberlebt sonst den Neustart.
        if UITestMode.isActive { return }
#endif
        guard let restored = AnkerNavigationState(encoded: storedNavigation) else { return }
        navigation = restored
    }

    @discardableResult
    private func ensureCurrentWeek() -> Week {
        WeekPlanning.ensureWeek(containing: Date(), weeks: weeks, modelContext: modelContext)
    }

    @discardableResult
    private func ensureSelectedWeek() -> Week {
        WeekPlanning.ensureWeek(containing: navigation.weekStart, weeks: weeks, modelContext: modelContext)
    }
}
