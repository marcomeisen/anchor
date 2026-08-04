import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared

    let week: Week
    let weeks: [Week]
    @Binding var selection: AppDestination
    let selectedDay: Day
    var onPreviousMonth: () -> Void = {}
    var onNextMonth: () -> Void = {}
    var onCurrentWeek: () -> Void = {}
    var onSelectWeek: (Date) -> Void = { _ in }
    var onSelectDay: (Day) -> Void = { _ in }
    var onFocusDay: (Day) -> Void = { _ in }
    var onSelectSearchResult: (AnkerSearch.Result) -> Void = { _ in }

    @State private var targetedWeekStart: Date?
    @State private var targetedDayID: UUID?
    @State private var goalPendingDeletion: Goal?
    @State private var showingSettings = false
    @State private var searchQuery = ""

    private var searchResults: [AnkerSearch.Result] {
        AnkerSearch.results(for: searchQuery, in: weeks)
    }

    /// Waehrend gesucht wird, treten Monatsnavigation und Zielliste zurueck. Sonst muesste
    /// der Nutzer in einer langen Sidebar nach den Treffern suchen.
    private var isSearching: Bool {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

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

                if isSearching {
                    SearchResultsList(query: searchQuery, results: searchResults) { result in
                        onSelectSearchResult(result)
                        searchQuery = ""
                    }
                } else {
                    primaryNavigation
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
                    settingsSection
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
#if os(macOS)
            .frame(minWidth: 460, minHeight: 560)
#endif
        }
        .background(.regularMaterial)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CloudSyncStatusRow(status: cloudSyncStatus)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(AnkerColor.lineSoft)
                        .frame(height: 1)
                }
        }
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [.black.opacity(0.08), .clear],
                startPoint: .trailing,
                endPoint: .leading
            )
            .frame(width: 18)
            .allowsHitTesting(false)
        }
            .navigationTitle("Daivento")
    }

    private var primaryNavigation: some View {
        VStack(spacing: 4) {
            sidebarNavigationButton(
                title: "Heute",
                systemImage: "sun.max",
                isSelected: selection == .today,
                help: "Heute anzeigen"
            ) {
                onCurrentWeek()
                selection = .today
            }

            sidebarNavigationButton(
                title: "Woche",
                systemImage: "calendar",
                isSelected: selection == .week,
                help: "Wochenübersicht anzeigen"
            ) {
                selection = .week
            }

            sidebarNavigationButton(
                title: "Jahr",
                systemImage: "square.grid.2x2",
                isSelected: selection == .year,
                help: "Jahresübersicht anzeigen"
            ) {
                selection = .year
            }
        }
        .padding(.vertical, 2)
    }

    private func sidebarNavigationButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            SidebarNavigationRow(
                title: title,
                systemImage: systemImage,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)

            TextField("Ziele, Aufgaben, Notizen", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AnkerColor.ink)
                .accessibilityLabel("In Zielen, Aufgaben, Notizen und Zeitblöcken suchen")

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AnkerColor.muted)
                }
                .buttonStyle(.plain)
                .help("Suche zurücksetzen")
                .accessibilityLabel("Suche zurücksetzen")
            }
        }
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("sidebarGoal.\(goal.title)")
                .contextMenu {
                    Button(role: .destructive) {
                        goalPendingDeletion = goal
                    } label: {
                        Label("Wochenziel löschen", systemImage: "trash")
                    }
                }
            }
        }
        .goalDeleteConfirmation(goal: $goalPendingDeletion, week: week) {
            // Falls gerade das geloeschte Ziel offen war, zurueck auf die Wochenuebersicht.
            if case .goal = selection {
                selection = .week
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

    private var settingsSection: some View {
        Button {
            showingSettings = true
        } label: {
            Label("Einstellungen", systemImage: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AnkerColor.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .help("Erscheinungsbild, iCloud-Sync, Daten und Datenschutz")
        .accessibilityLabel("Einstellungen öffnen")
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
        TaskDropHandling.loadTaskID(from: providers) { taskID in
            TaskDropHandling.moveTask(id: taskID, to: target.monday, weeks: weeks, modelContext: modelContext)
            targetedWeekStart = nil
            onSelectWeek(target.monday)
            selection = .week
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
            return AnyShapeStyle(LinearGradient(colors: [AnkerColor.indigoGradientDeep, AnkerColor.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
        }

        return AnyShapeStyle(Color.clear)
    }
}

private struct SidebarNavigationRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 18)
            Text(title)
                .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? .white : AnkerColor.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : AnkerColor.lineSoft)
        )
    }

    private var backgroundStyle: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(LinearGradient(colors: [AnkerColor.indigoGradientDeep, AnkerColor.indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
        }

        return AnyShapeStyle(AnkerColor.card.opacity(0.58))
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
    var isDropTarget = false

    private var openTaskCount: Int {
        day.taskList.filter { !$0.isDone }.count
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(AnkerDateFormat.weekdayShortWithDayMonth(day.date))
                .font(.system(size: 11, weight: isSelected || isDropTarget ? .bold : .medium))

            Spacer(minLength: 4)

            if isDropTarget {
                Text("← Tag")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.indigoText)
            } else if openTaskCount > 0 {
                Text(verbatim: String(openTaskCount))
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(AnkerColor.muted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(AnkerColor.lineSoft, in: Capsule())
                    .accessibilityLabel("\(openTaskCount) offene Aufgaben")
            }
        }
        .foregroundStyle(isDropTarget ? AnkerColor.indigoText : (isSelected ? AnkerColor.indigoText : AnkerColor.muted))
        .padding(.leading, 42)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(dayBackground, in: RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isDropTarget ? AnkerColor.indigo : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isDropTarget ? 1.03 : 1)
        .animation(.easeOut(duration: 0.12), value: isDropTarget)
    }

    private var dayBackground: some ShapeStyle {
        if isDropTarget {
            return AnyShapeStyle(AnkerColor.indigo.opacity(0.16))
        }

        if isSelected {
            return AnyShapeStyle(AnkerColor.indigo.opacity(0.10))
        }

        return AnyShapeStyle(Color.clear)
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
