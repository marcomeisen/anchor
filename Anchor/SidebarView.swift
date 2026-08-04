import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Die Sidebar auf Mac und iPad: **nur Zeit**.
///
/// Der Entwurf begründet den Umbau so: vorher machte sie vier Dinge gleichzeitig
/// (Ansichtswechsel, Zeitnavigation, Zielliste, App-Utility), und drei davon beantworteten
/// dieselbe Frage — „wo bin ich in der Zeit?". Der Ansichtswechsel ist ein Modus des Inhalts und
/// sitzt deshalb in der Toolbar. Die Anker sind Inhalt und stehen als Streifen darüber. Hier
/// bleibt eine Schiene: pro Woche eine Zeile mit sieben Quadraten, die laufende aufgeklappt.
///
/// Es gibt genau **einen** Zeitnavigator: Stepper plus „Heute". Der Kalenderknopf und das zweite
/// Pfeilpaar sind weg — sie beantworteten dieselbe Frage dreimal.
struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared

    let week: Week
    let weeks: [Week]
    @Binding var selection: AppDestination
    let selectedDay: Day
    var onPreviousWeek: () -> Void = {}
    var onNextWeek: () -> Void = {}
    var onCurrentWeek: () -> Void = {}
    var onSelectWeek: (Date) -> Void = { _ in }
    var onSelectDay: (Day) -> Void = { _ in }
    var onFocusDay: (Day) -> Void = { _ in }
    var onSelectSearchResult: (AnkerSearch.Result) -> Void = { _ in }

    @State private var targetedWeekStart: Date?
    @State private var targetedDayID: UUID?
    @State private var showingSettings = false
    @State private var searchQuery = ""

    private var searchResults: [AnkerSearch.Result] {
        AnkerSearch.results(for: searchQuery, in: weeks)
    }

    /// Während gesucht wird, tritt die Schiene zurück. Sonst müsste der Nutzer in einer langen
    /// Sidebar nach den Treffern suchen.
    private var isSearching: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private var rows: [SidebarTimeline.WeekRow] {
        SidebarTimeline.rows(around: week.monday, in: weeks)
    }

    private var readiness: WeekActions.ReviewReadiness {
        WeekActions.readiness(of: week)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField

            if isSearching {
                ScrollView {
                    SearchResultsList(query: searchQuery, results: searchResults) { result in
                        onSelectSearchResult(result)
                        searchQuery = ""
                    }
                    .padding(.horizontal, AnkerSpacing.s3)
                    .padding(.vertical, AnkerSpacing.s3)
                }
            } else {
                timeHeader
                timeline
            }

            footer
        }
        .background(AnkerColor.surface)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
#if os(macOS)
            .frame(minWidth: 460, minHeight: 560)
#endif
        }
        .overlay(alignment: .trailing) {
            AnkerRule(axis: .vertical)
                .allowsHitTesting(false)
        }
        .navigationTitle("Daivento")
    }

    // MARK: - Suche

    private var searchField: some View {
        HStack(spacing: AnkerSpacing.s2) {
            Image(.search)
                .ankerIcon(AnkerIconSize.xs)
                .foregroundStyle(AnkerColor.inkSecond)

            // Der Platzhalter nennt das Archiv ausdrücklich: die Suche geht über **alle** Wochen,
            // auch die, die nicht mehr in der Schiene stehen. Sonst wäre das Fenster um die
            // laufende Woche eine Sackgasse.
            TextField("Suchen · auch im Archiv", text: $searchQuery)
                .textFieldStyle(.plain)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.ink)
                .accessibilityLabel("In Zielen, Aufgaben, Notizen und Zeitblöcken suchen, auch im Archiv")

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(.clear)
                        .ankerIcon(AnkerIconSize.xs)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Suche zurücksetzen")
                .accessibilityLabel("Suche zurücksetzen")
            }
        }
        .padding(.vertical, AnkerSpacing.s2)
        .padding(.horizontal, AnkerSpacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnkerColor.ground, in: Rectangle())
        .overlay(Rectangle().stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule))
        .padding(AnkerSpacing.s3)
        .ankerEdge(.bottom)
    }

    // MARK: - Jahr und der eine Zeitnavigator

    private var timeHeader: some View {
        HStack(spacing: AnkerSpacing.s2) {
            Text(verbatim: String(week.isoYear))
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(AnkerColor.inkSecond)

            Spacer(minLength: AnkerSpacing.s2)

            HStack(spacing: 0) {
                stepperButton("‹", help: "Vorherige Woche", action: onPreviousWeek)
                AnkerRule(axis: .vertical)
                stepperButton("Heute", help: "Zur laufenden Woche", isLabel: true, action: onCurrentWeek)
                AnkerRule(axis: .vertical)
                stepperButton("›", help: "Nächste Woche", action: onNextWeek)
            }
            .fixedSize()
            .overlay(Rectangle().stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule))
        }
        .padding(.horizontal, AnkerSpacing.s4)
        .padding(.top, AnkerSpacing.s4)
        .padding(.bottom, AnkerSpacing.s2)
    }

    private func stepperButton(
        _ title: String,
        help: String,
        isLabel: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .ankerType(isLabel ? AnkerType.microLabel : AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: - Die Schiene

    private var timeline: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    weekRow(row)

                    // Aufgeklappt wird genau eine Woche: die angezeigte. Der Entwurf ersetzt die
                    // Tagesliste vergangener Wochen durch die sieben Quadrate — sie bleiben
                    // lesbar, ohne Platz zu kosten.
                    if AnkerCalendar.isSameDay(row.monday, week.monday) {
                        ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                            dayRow(day)
                        }
                        .padding(.bottom, AnkerSpacing.s2)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private func weekRow(_ row: SidebarTimeline.WeekRow) -> some View {
        Button {
            onSelectWeek(row.monday)
        } label: {
            SidebarWeekRow(
                row: row,
                isSelected: AnkerCalendar.isSameDay(row.monday, week.monday),
                isDropTarget: targetedWeekStart.map { AnkerCalendar.isSameDay($0, row.monday) } ?? false
            )
        }
        .buttonStyle(.plain)
        .help(row.exists ? "Woche öffnen oder Aufgabe hierher ziehen" : "Woche wird beim Ablegen angelegt")
        .accessibilityIdentifier("sidebarWeek.\(row.isoWeek)")
        .accessibilityLabel(row.accessibilityLabel)
        .onDrop(
            of: TaskDropHandling.draggedTypes,
            isTargeted: Binding(
                get: { targetedWeekStart.map { AnkerCalendar.isSameDay($0, row.monday) } ?? false },
                set: { isTargeted in targetedWeekStart = isTargeted ? row.monday : nil }
            )
        ) { providers in
            dropTask(from: providers, onWeekStartingAt: row.monday)
        }
    }

    private func dayRow(_ day: Day) -> some View {
        Button {
            onSelectDay(day)
        } label: {
            SidebarDayRow(
                day: day,
                isSelected: AnkerCalendar.isSameDay(day.date, selectedDay.date),
                isDropTarget: targetedDayID == day.id
            )
        }
        .buttonStyle(.plain)
        .help("Tag öffnen oder Aufgabe auf diesen Tag ziehen")
        .accessibilityLabel("Tag \(AnkerDateFormat.weekdayLongWithDayMonth(day.date)) öffnen")
        .onDrop(
            of: TaskDropHandling.draggedTypes,
            isTargeted: Binding(
                get: { targetedDayID == day.id },
                set: { isTargeted in targetedDayID = isTargeted ? day.id : nil }
            )
        ) { providers in
            dropTask(from: providers, on: day)
        }
    }

    // MARK: - Fuß

    private var footer: some View {
        VStack(spacing: 0) {
            AnkerRule(color: AnkerColor.ink)

            reviewRow
            AnkerRule()
            archiveRow
            AnkerRule()
            settingsRow

            CloudSyncStatusRow(status: cloudSyncStatus)
                .padding(.horizontal, AnkerSpacing.s4)
                .padding(.vertical, AnkerSpacing.s2)
                .ankerEdge(.top)
        }
        .background(AnkerColor.surface)
    }

    /// „Scharf, nicht laut": erreichbar ist der Rückblick immer, aber bis die Woche endet bleibt
    /// die Zeile grau und ohne Zähler. Ab Sonntag wird sie rot und nennt, was offen ist.
    private var reviewRow: some View {
        let readiness = self.readiness
        let isArmed = readiness.isArmed

        return Button {
            selection = .review
        } label: {
            HStack(spacing: AnkerSpacing.s2) {
                Rectangle()
                    .fill(isArmed ? AnkerColor.onAccent : Color.clear)
                    .frame(width: 9, height: 9)
                    .overlay(
                        Rectangle().stroke(
                            isArmed ? Color.clear : AnkerColor.inkTertiary,
                            lineWidth: AnkerBorder.rule
                        )
                    )

                Text(verbatim: "\(AnkerDateFormat.calendarWeek(week.isoWeek)) abschließen")
                    .ankerType(AnkerType.metaStrong)

                Spacer(minLength: AnkerSpacing.s2)

                Text(verbatim: readiness.meta)
                    .ankerType(AnkerType.microLabel)
            }
            .foregroundStyle(isArmed ? AnkerColor.onAccent : AnkerColor.inkSecond)
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isArmed ? AnkerColor.accentFill : Color.clear, in: Rectangle())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("sidebarReview")
        .accessibilityLabel(reviewAccessibilityLabel(readiness))
    }

    private func reviewAccessibilityLabel(_ readiness: WeekActions.ReviewReadiness) -> String {
        let base = "\(AnkerDateFormat.calendarWeek(week.isoWeek)) abschließen"
        switch readiness {
        case .quiet:
            return "\(base), ab Sonntag fällig"
        case .armed(let open):
            return open == 0 ? "\(base), nichts offen" : "\(base), \(open) Aufgaben offen"
        case .closed(let date):
            return "\(base), geschlossen am \(AnkerDateFormat.dayMonth(date))"
        }
    }

    private var archiveRow: some View {
        let count = AnkerArchive.count(in: weeks)

        return Button {
            selection = .archive
        } label: {
            HStack(spacing: AnkerSpacing.s2) {
                Image(.archive)
                    .ankerIcon(AnkerIconSize.xs)
                Text(verbatim: "Archiv")
                    .ankerType(selection == .archive ? AnkerType.metaStrong : AnkerType.meta)
                Spacer(minLength: AnkerSpacing.s2)
                if count > 0 {
                    Text(verbatim: "\(count) KW")
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(AnkerColor.inkTertiary)
                }
            }
            .foregroundStyle(selection == .archive ? AnkerColor.accentInk : AnkerColor.inkSecond)
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Abgeschlossene Wochen")
        .accessibilityIdentifier("sidebarArchive")
        .accessibilityLabel(count > 0 ? "Archiv, \(count) Wochen" : "Archiv")
    }

    private var settingsRow: some View {
        Button {
            showingSettings = true
        } label: {
            HStack(spacing: AnkerSpacing.s2) {
                Image(.settings)
                    .ankerIcon(AnkerIconSize.xs)
                Text(verbatim: "Einstellungen")
                    .ankerType(AnkerType.meta)
                Spacer(minLength: 0)
            }
            .foregroundStyle(AnkerColor.inkSecond)
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Erscheinungsbild, iCloud-Sync, Daten und Datenschutz")
        .accessibilityLabel("Einstellungen öffnen")
    }

    // MARK: - Drops

    private func dropTask(from providers: [NSItemProvider], onWeekStartingAt monday: Date) -> Bool {
        TaskDropHandling.loadTaskID(from: providers) { taskID in
            TaskDropHandling.moveTask(id: taskID, to: monday, weeks: weeks, modelContext: modelContext)
            targetedWeekStart = nil
            onSelectWeek(monday)
        }
    }

    private func dropTask(from providers: [NSItemProvider], on day: Day) -> Bool {
        let targetDate = day.date

        return TaskDropHandling.loadTaskID(from: providers) { taskID in
            TaskDropHandling.moveTask(id: taskID, to: targetDate, weeks: weeks, modelContext: modelContext)
            targetedDayID = nil
            // Absichtlich nur den Zieltag setzen statt zu navigieren: beim Ablegen soll der
            // Blick dort bleiben, wo gezogen wurde.
            onFocusDay(day)
        }
    }
}

/// Eine Woche in der Schiene: Beschriftung, sieben Quadrate, offene Aufgaben.
private struct SidebarWeekRow: View {
    let row: SidebarTimeline.WeekRow
    let isSelected: Bool
    var isDropTarget = false

    var body: some View {
        HStack(spacing: AnkerSpacing.s2) {
            Text(verbatim: row.label)
                .ankerType(row.isCurrent ? AnkerType.metaStrong : AnkerType.meta)
                .foregroundStyle(row.isPast ? AnkerColor.inkSecond : AnkerColor.ink)
                // Feste Breite, damit die Quadrate aller Zeilen in einer Spalte stehen. Ohne das
                // wandert das Raster mit der Textbreite und die Schiene wirkt schief.
                .frame(width: 66, alignment: .leading)

            HStack(spacing: AnkerSpacing.markerGap) {
                ForEach(Array(row.marks.enumerated()), id: \.offset) { _, mark in
                    DayMarkSquare(mark: mark)
                }
            }

            Spacer(minLength: AnkerSpacing.s1)

            if isDropTarget {
                Text(verbatim: "← Woche")
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(AnkerColor.accentInk)
            } else if row.openCount > 0 {
                Text(verbatim: "\(row.openCount)")
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            } else if !row.exists {
                Image(.addCircle)
                    .ankerIcon(AnkerIconSize.xs)
                    .foregroundStyle(AnkerColor.inkTertiary)
            }
        }
        .padding(.horizontal, AnkerSpacing.s4)
        .padding(.vertical, AnkerSpacing.s2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: Rectangle())
        .ankerEdge(.top)
        // Der Marker an der Kante statt einer starken Füllung: dasselbe Idiom, mit dem der
        // Entwurf überall das Aktive auszeichnet.
        .overlay(alignment: .leading) {
            if isSelected {
                Rectangle()
                    .fill(AnkerColor.accentMark)
                    .frame(width: AnkerBorder.heavy)
            }
        }
        .contentShape(Rectangle())
    }

    private var background: Color {
        if isDropTarget { return AnkerColor.accent[100] }
        return isSelected ? AnkerColor.ground : .clear
    }
}

/// Ein Tag als Quadrat. Die vier Zustände sind der Kern der Zeile — deshalb eigene Ansicht mit
/// eigener Vorlesebeschriftung.
private struct DayMarkSquare: View {
    let mark: SidebarTimeline.DayMark

    var body: some View {
        Rectangle()
            .fill(fill)
            .frame(width: 9, height: 9)
            .overlay(Rectangle().stroke(edge, lineWidth: AnkerBorder.rule))
            .accessibilityHidden(true)
    }

    private var fill: Color {
        switch mark {
        case .today: AnkerColor.accentMark
        case .done: AnkerColor.ink
        case .open, .empty: .clear
        }
    }

    private var edge: Color {
        switch mark {
        case .today, .done: .clear
        case .open: AnkerColor.ink
        case .empty: AnkerColor.divider
        }
    }
}

private struct SidebarDayRow: View {
    let day: Day
    let isSelected: Bool
    var isDropTarget = false

    private var openTaskCount: Int {
        day.taskList.filter { !$0.isDone }.count
    }

    private var isToday: Bool {
        AnkerCalendar.isSameDay(day.date, Date())
    }

    var body: some View {
        HStack(spacing: AnkerSpacing.s2) {
            Text(verbatim: AnkerDateFormat.weekdayShortWithDayMonth(day.date))
                .ankerType(isToday ? AnkerType.metaStrong : AnkerType.numericSmall)

            Spacer(minLength: AnkerSpacing.s1)

            if isDropTarget {
                Text(verbatim: "← Tag")
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(AnkerColor.accentInk)
            } else if openTaskCount > 0 {
                Text(verbatim: String(openTaskCount))
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .accessibilityLabel("\(openTaskCount) offene Aufgaben")
            }
        }
        .foregroundStyle(foreground)
        .padding(.leading, AnkerSpacing.sidebarIndent)
        .padding(.trailing, AnkerSpacing.s4)
        .padding(.vertical, AnkerSpacing.s1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected || isDropTarget ? AnkerColor.ground : Color.clear, in: Rectangle())
        .overlay(alignment: .leading) {
            if isDropTarget {
                Rectangle()
                    .fill(AnkerColor.accentMark)
                    .frame(width: AnkerBorder.heavy)
            }
        }
        .contentShape(Rectangle())
    }

    private var foreground: Color {
        if isDropTarget { return AnkerColor.accentInk }
        if isToday { return AnkerColor.accentInk }
        return AnkerColor.inkSecond
    }
}
