import SwiftData
import SwiftUI

/// Verteilt auf Onboarding, iPhone-Layout (Tabs unten) und Fensterlayout (Mac, iPad).
///
/// „Blatt" hat **keine Sidebar** mehr: die Zeit steht im Kopf als ein Schrittschalter, der
/// Bereich (Heute, Woche, Archiv) daneben. Und diese Ansicht legt **nichts** an — weder beim
/// Start noch beim Blättern. Wochen und Tage entstehen erst, wenn etwas geschrieben wird;
/// vorher entstanden auf jedem neuen Gerät Duplikate, bevor der iCloud-Import ankam.
struct AnkerRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalClass
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("onboardingVersion") private var onboardingVersion = 0
    @AppStorage(AppSettingsKey.startupViewMode) private var startupViewRaw = StartupViewMode.lastView.rawValue

    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared

    let weeks: [Week]

    @SceneStorage("navigation") private var storedNavigation: String?
    @State private var navigation = AnkerNavigationState()

    /// Pro Gerät gemerkt: wer die Leiste einklappt, will sie beim nächsten Start nicht
    /// wieder offen sehen.
    @AppStorage("sidebarVisible") private var isSidebarVisible = true
    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var weekStartTarget: Date?
    @State private var reviewTarget: Date?
    /// Die Uhr der Oberfläche. Ein `Date()` als Vorgabewert in den Bildschirmen blieb über
    /// Nacht stehen: „Heute" zeigte gestern, und die Erfassung legte auf gestern. Aktualisiert
    /// beim Aktivwerden, beim Tageswechsel und bei Zeitsprüngen (Zeitzone, Uhr gestellt).
    @State private var now = Date()

    private let requiredOnboardingVersion = 2

    private var needsOnboarding: Bool {
        !WeekPlanning.hasContent(in: weeks, modelContext: modelContext) && !hasCompletedOnboarding
    }

    private var isAwaitingFirstSync: Bool {
        guard CloudSyncPreference.activeAtLaunch else { return false }
        switch cloudSyncStatus.phase {
        case .starting, .ready, .syncing: return true
        case .pendingExport, .synced, .issue, .disabled: return false
        }
    }

    private var isWide: Bool {
#if os(macOS)
        true
#else
        horizontalClass == .regular
#endif
    }

    var body: some View {
        Group {
            if needsOnboarding {
                OnboardingView(
                    weekIntervalTitle: currentWeekTitle,
                    isAwaitingFirstSync: isAwaitingFirstSync,
                    onCreateAnchors: completeOnboarding(with:),
                    onSkip: skipOnboarding
                )
            } else if isWide {
                windowContent
            } else {
#if os(iOS)
                phoneContent
#else
                windowContent
#endif
            }
        }
        .tint(AnkerColor.accentMark)
        .sheet(isPresented: $showingSearch) {
            SearchSheet(weeks: weeks) { open($0) }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(item: Binding(get: { weekStartTarget.map(IdentifiedDate.init) }, set: { weekStartTarget = $0?.date })) { target in
            sheetFrame { WeekStartScreen(weekStart: target.date) }
        }
        .sheet(item: Binding(get: { reviewTarget.map(IdentifiedDate.init) }, set: { reviewTarget = $0?.date })) { target in
            sheetFrame { ReviewScreen(weekStart: target.date) }
        }
        .task { restoreNavigationIfPossible() }
        // Aufräumen nach dem Sync — aber erst, wenn kein Import mehr läuft.
        //
        // Mitten in einem Import kommen Wochen vor ihren Tagen an; ein Aufräumen in diesem
        // Moment sieht einen halben Bestand. Der Schlüssel wechselt bei jeder Remote-Änderung und
        // beim Ende eines Imports, die kurze Pause bündelt Serien von Änderungen.
        .task(id: maintenanceTrigger) {
            // Vor dem ersten Import dieser Sitzung sähe das Aufräumen nur den lokalen Bestand.
            guard !CloudSyncConfiguration.usesCloudKit || cloudSyncStatus.hasCompletedImportThisSession else { return }
            guard cloudSyncStatus.phase != .syncing else { return }
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, cloudSyncStatus.phase != .syncing else { return }
            StoreMaintenance.run(modelContext: modelContext)
        }
        .onChange(of: navigation) { _, newValue in
            storedNavigation = newValue.encoded
        }
        .onOpenURL { url in
            guard navigation.apply(url) else { return }
            // `anchorit://review` öffnet den Rückblick der Woche, nicht nur einen Bereich.
            if navigation.destination == .review {
                navigation.select(.week)
                reviewTarget = navigation.weekStart
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshNow() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // Kommt auf einem beliebigen Thread an; der Zustand gehört dem Hauptthread.
            Task { @MainActor in refreshNow() }
        }
#if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshNow()
        }
#endif
        .focusedSceneValue(\.ankerNavigation, needsOnboarding ? nil : $navigation)
        .focusedSceneValue(\.ankerSceneActions, needsOnboarding ? nil : sceneActions)
    }

    private var maintenanceTrigger: String {
        "\(cloudSyncStatus.remoteChangeCount)-\(cloudSyncStatus.phase == .syncing)-\(cloudSyncStatus.hasCompletedImportThisSession)"
    }

    /// Für die Menübefehle: Setzen und Rückblick gelten der angezeigten Woche, auf Heute der
    /// laufenden.
    private var sceneActions: AnkerSceneActions {
        AnkerSceneActions(
            showSearch: { showingSearch = true },
            startWeek: { weekStartTarget = commandWeekStart },
            review: { reviewTarget = commandWeekStart }
        )
    }

    private var commandWeekStart: Date {
        navigation.topLevel == .week
            ? navigation.weekStart
            : AnkerCalendar.weekInterval(containing: now).monday
    }

    private func refreshNow() {
        let fresh = Date()
        // Nur bei einem neuen Kalendertag neu zeichnen — sonst bei jedem Aktivwerden.
        guard !AnkerCalendar.isSameDay(fresh, now) else { return }
        let wasOnToday = AnkerCalendar.isSameDay(navigation.dayDate, now)
        let wasOnCurrentWeek = AnkerCalendar.weekKey(containing: navigation.weekStart) == AnkerCalendar.weekKey(containing: now)
        now = fresh
        // Wer auf „heute" stand, steht danach wieder auf heute — nicht auf gestern.
        if wasOnToday { navigation.dayDate = fresh }
        if wasOnCurrentWeek && !navigation.isPushed {
            navigation.weekStart = AnkerCalendar.weekInterval(containing: fresh).monday
        }
    }

    private func sheetFrame<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
#if os(macOS)
            .frame(minWidth: 520, minHeight: 620)
#endif
    }

    // MARK: - iPhone

#if os(iOS)
    private var phoneContent: some View {
        NavigationStack(path: pushedPath) {
            topLevel
                .safeAreaInset(edge: .top, spacing: 0) { phoneHeader(showsBack: false) }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    AnkerTabBar(selection: topLevelSelection)
                }
                .refreshable { await cloudSyncStatus.requestSync() }
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: AppDestination.self) { destination in
                    detail(destination)
                        .safeAreaInset(edge: .top, spacing: 0) { phoneHeader(showsBack: true) }
                        .toolbar(.hidden, for: .navigationBar)
                }
        }
    }

    private func phoneHeader(showsBack: Bool) -> some View {
        VStack(spacing: 0) {
            AnkerPhoneHeader(showsBack: showsBack) {
                AnkerHeaderButton(icon: .search, label: "Suchen") { showingSearch = true }
                CloudSyncStatusBadge(status: cloudSyncStatus)
                    .frame(width: 44, height: 44)
                AnkerHeaderButton(icon: .settings, label: "Einstellungen öffnen") { showingSettings = true }
            }
            // Nur bei einem Problem. „Nur auf diesem Gerät" ist eine bewusste Wahl — das Symbol
            // daneben zeigt sie, ein Dauerbanner wäre Gängelei.
            if cloudSyncStatus.isShowingManualSync || cloudSyncStatus.phase == .issue {
                CloudSyncStatusRow(status: cloudSyncStatus)
                    .padding(.horizontal, AnkerSpacing.screenPadding)
                    .padding(.bottom, AnkerSpacing.s2)
            }
        }
        .background(AnkerColor.ground)
    }
#endif

    // MARK: - Mac und iPad

    /// Mac und iPad: einklappbare Seitenleiste mit den Wochen, rechts der Inhalt.
    ///
    /// Die Leiste ist der Ort für die Zeit — Wochen ansehen und Aufgaben in eine andere Woche
    /// ziehen. Ist sie eingeklappt, übernimmt der Schrittschalter im Kopf; beide zugleich gibt
    /// es nicht, damit es bei genau einem Zeitnavigator bleibt.
    private var windowContent: some View {
        NavigationSplitView(columnVisibility: sidebarVisibility) {
            BlattSidebar(
                selectedWeekStart: navigation.weekStart,
                now: now,
                onSelectWeek: { monday in
                    navigation.moveToWeek(startingAt: monday)
                    navigation.select(.week)
                },
                onToday: {
                    navigation.moveToToday(now: now)
                    navigation.select(.week)
                },
                onArchive: { navigation.select(.archive) }
            )
            .navigationSplitViewColumnWidth(min: 250, ideal: 270, max: 340)
#if os(macOS)
            .toolbar(removing: .sidebarToggle)
#endif
        } detail: {
            NavigationStack(path: pushedPath) {
                VStack(spacing: 0) {
                    windowHeader
                    AnkerRule()
                    topLevel
                }
                .background(AnkerColor.ground)
                .navigationDestination(for: AppDestination.self) { destination in
                    detail(destination)
                        .safeAreaInset(edge: .top, spacing: 0) { BlattBackBar() }
                        .background(AnkerColor.ground)
#if os(iOS)
                        .toolbar(.hidden, for: .navigationBar)
#endif
                }
#if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
#endif
            }
        }
        .navigationSplitViewStyle(.balanced)
#if os(macOS)
        // Darunter wird das Raster unlesbar und die Leiste verliert ihre Beschriftung.
        .frame(minWidth: 960, minHeight: 620)
#endif
    }

    private var sidebarVisibility: Binding<NavigationSplitViewVisibility> {
        Binding(
            get: { isSidebarVisible ? .all : .detailOnly },
            set: { isSidebarVisible = $0 != .detailOnly }
        )
    }

    private func toggleSidebar() {
        withAnimation(.easeOut(duration: 0.2)) { isSidebarVisible.toggle() }
    }

    private var windowHeader: some View {
        let interval = AnkerCalendar.weekInterval(containing: navigation.weekStart)
        let isCurrent = AnkerCalendar.weekKey(containing: now) == AnkerCalendar.weekKey(containing: navigation.weekStart)
        return HStack(spacing: AnkerSpacing.s4) {
            BlattIconButton(icon: .sidebar, label: isSidebarVisible ? "Seitenleiste ausblenden" : "Seitenleiste einblenden") {
                toggleSidebar()
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            if navigation.topLevel == .week {
                HStack(spacing: AnkerSpacing.s3) {
                    if !isSidebarVisible {
                    WeekStepper(
                        onPrevious: { navigation.moveWeek(by: -1) },
                        onNext: { navigation.moveWeek(by: 1) },
                        onToday: { navigation.moveToToday(now: now); navigation.select(.week) },
                        isCurrent: isCurrent
                    )
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: AnkerDateFormat.calendarWeek(interval.isoWeek))
                            .ankerType(AnkerType.headline)
                            .foregroundStyle(AnkerColor.ink)
                        Text(verbatim: AnkerDateFormat.weekSpan(monday: interval.monday, sunday: interval.sunday))
                            .ankerType(AnkerType.meta)
                            .foregroundStyle(AnkerColor.inkSecond)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }

            Spacer(minLength: AnkerSpacing.s2)

            // Breit: Bereichswahl in voller Breite und „Rückblick" als Text. Eng (iPad hochkant
            // mit offener Leiste): schmalere Bereichswahl, „Rückblick" als Symbol. Nie breiter
            // als der Platz — sonst rutscht der Kopf unter die Seitenleiste.
            ViewThatFits(in: .horizontal) {
                headerActions(segmentWidth: 280, compactReview: false)
                headerActions(segmentWidth: 220, compactReview: true)
                headerActions(segmentWidth: 180, compactReview: true)
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
#if os(macOS)
        // Platz für die Ampelknöpfe, die bei verborgener Titelleiste über dem Kopf liegen —
        // nur, wenn die Seitenleiste sie nicht schon trägt.
        .padding(.leading, isSidebarVisible ? 0 : AnkerSpacing.s6 + AnkerSpacing.s5)
#endif
        .frame(minHeight: 64)
        .background(AnkerColor.ground)
    }

    private func headerActions(segmentWidth: CGFloat, compactReview: Bool) -> some View {
        HStack(spacing: AnkerSpacing.s3) {
            AnkerSegmented(
                options: [
                    (AppDestination.today, String(localized: "Heute")),
                    (.week, String(localized: "Woche")),
                    (.archive, String(localized: "Archiv")),
                ],
                selection: topLevelSelection,
                accessibilityLabel: String(localized: "Bereich")
            )
            .frame(width: segmentWidth)

            if navigation.topLevel == .week {
                if compactReview {
                    BlattIconButton(icon: .checkCircle, label: "Rückblick") { reviewTarget = navigation.weekStart }
                } else {
                    Button("Rückblick") { reviewTarget = navigation.weekStart }
                        .buttonStyle(AnkerButtonStyle.secondary)
                        .fixedSize()
                }
            }

            // ⌘F trägt der Menübefehl „Gehe zu › Suchen" (`AnkerCommands`).
            BlattIconButton(icon: .search, label: "Suchen") { showingSearch = true }
            CloudSyncStatusBadge(status: cloudSyncStatus)
                .frame(width: 40, height: 40)
#if os(iOS)
            BlattIconButton(icon: .settings, label: "Einstellungen öffnen") { showingSettings = true }
#endif
        }
        .fixedSize()
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var topLevel: some View {
        switch navigation.topLevel {
        case .week:
            WeekScreen(
                weekStart: navigation.weekStart,
                now: now,
                onPreviousWeek: { navigation.moveWeek(by: -1) },
                onNextWeek: { navigation.moveWeek(by: 1) },
                onToday: { navigation.moveToToday(now: now); navigation.select(.week) },
                onOpenAnchor: { navigation.select(.goal($0.id)) },
                onOpenDay: { navigation.openDay(on: $0) },
                onStartWeek: { weekStartTarget = navigation.weekStart },
                onReview: { reviewTarget = navigation.weekStart },
                showsNavigation: !isWide
            )
        case .archive, .year, .review:
            ArchiveScreen { monday in
                navigation.moveToWeek(startingAt: monday)
                navigation.select(.week)
            }
        default:
            TodayScreen(
                now: now,
                onOpenAnchor: { navigation.select(.goal($0.id)) },
                onStartWeek: { weekStartTarget = AnkerCalendar.weekInterval(containing: now).monday },
                onOpenWeek: {
                    navigation.moveToToday(now: now)
                    navigation.select(.week)
                },
                onReview: { monday in reviewTarget = monday }
            )
        }
    }

    @ViewBuilder
    private func detail(_ destination: AppDestination) -> some View {
        switch destination {
        case .goal(let id):
            if let goal = weeks.lazy.flatMap(\.goalList).first(where: { $0.id == id }) {
                AnchorScreen(goal: goal, now: now) { navigation.popToTopLevel() }
            } else {
                BlattEmptyNote(text: String(localized: "Dieser Anker ist nicht mehr da — vielleicht auf einem anderen Gerät gelöscht."))
                    .padding(AnkerSpacing.screenPadding)
            }
        case .day:
            dayDetail
        default:
            topLevel
        }
    }

    /// Das Tagesdetail rendert mit dem Datum allein. Woche und Tag entstehen erst, wenn darin
    /// etwas geschrieben wird — nicht beim Öffnen, Wiederherstellen oder über `anchorit://day/…`.
    private var dayDetail: some View {
        DayDetailView(
            date: navigation.dayDate,
            now: now,
            onSelectGoal: { navigation.select(.goal($0.id)) }
        )
    }

    // MARK: - Bindungen

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
            get: {
                switch navigation.topLevel {
                case .year, .review: .archive
                default: navigation.topLevel
                }
            },
            set: { navigation.select($0) }
        )
    }

    private var currentWeekTitle: String {
        let interval = AnkerCalendar.weekInterval(containing: now)
        return AnkerDateFormat.weekSpan(monday: interval.monday, sunday: interval.sunday)
    }

    // MARK: - Aktionen

    private func open(_ result: AnkerSearch.Result) {
        let dayDate = result.dayID.flatMap { WeekPlanning.day(withID: $0, in: weeks)?.date }
        navigation.open(result, dayDate: dayDate)
    }

    private func skipOnboarding() {
        hasCompletedOnboarding = true
        onboardingVersion = requiredOnboardingVersion
        navigation.moveToToday()
    }

    private func completeOnboarding(with titles: [String]) {
        guard !WeekPlanning.hasContent(in: weeks, modelContext: modelContext) else {
            skipOnboarding()
            return
        }
        let week = TaskActions.ensureWeek(containing: Date(), weeks: weeks, modelContext: modelContext)
        WeekPlanning.createOnboardingAnchors(titles, in: week, modelContext: modelContext)
        hasCompletedOnboarding = true
        onboardingVersion = requiredOnboardingVersion
        navigation.moveToToday()
        navigation.select(.today)
        modelContext.saveChanges()
    }

    private func restoreNavigationIfPossible() {
#if DEBUG
        if UITestMode.isActive {
            // `-AnchoritTab week` — Startbereich für Bildschirmfotos und UI-Tests. Startargumente
            // landen in der Argument-Domain der Defaults; gelesen wird nur, nichts geschrieben.
            switch UserDefaults.standard.string(forKey: "AnchoritTab") {
            case "week": navigation.select(.week)
            case "archive": navigation.select(.archive)
            case "review":
                navigation.select(.week)
                reviewTarget = navigation.weekStart
            case "settings":
                showingSettings = true
            case "setzen":
                navigation.select(.week)
                weekStartTarget = navigation.weekStart
            default: break
            }
            return
        }
#endif
        let mode = StartupViewMode(rawValue: startupViewRaw) ?? .lastView
        guard let initial = mode.initialNavigation(storedNavigation: storedNavigation) else { return }
        navigation = initial
    }
}

/// `sheet(item:)` braucht `Identifiable`.
private struct IdentifiedDate: Identifiable {
    let date: Date
    var id: TimeInterval { date.timeIntervalSince1970 }
}
