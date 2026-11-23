import SwiftData
import SwiftUI

/// Wie die Woche gezeigt wird. Beide Ansichten zeigen **dieselben** Daten — was in der einen
/// eingeplant wird, steht in der anderen.
enum WeekLayout: String, CaseIterable, Identifiable {
    /// iPhone: sieben Tageszeilen. Mac und iPad: das Raster, Zeile Anker, Spalte Tag.
    case byDay
    /// Eine Gruppe bzw. Spalte pro Anker.
    case byAnchor

    var id: String { rawValue }
}

/// Die Woche zum Planen.
struct WeekScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalClass
    @Query(sort: \Week.monday) private var weeks: [Week]
    @Query(filter: #Predicate<AnkerTask> { $0.day == nil && $0.linkedGoal == nil }, sort: \AnkerTask.order)
    private var inbox: [AnkerTask]

    @AppStorage("weekLayout") private var layoutRaw = WeekLayout.byDay.rawValue
    @StateObject private var undo = TaskUndoCoordinator()
    /// Die Aufgabe, die auf dem iPhone gerade eingeplant wird: erst antippen, dann den Tag.
    @State private var placing: AnkerTask?

    let weekStart: Date
    var now: Date = Date()
    var onPreviousWeek: () -> Void
    var onNextWeek: () -> Void
    var onToday: () -> Void
    var onOpenAnchor: (Goal) -> Void
    var onOpenDay: (Date) -> Void
    var onStartWeek: () -> Void
    /// Rückblick der angezeigten Woche. Auf Mac und iPad trägt ihn der Fensterkopf.
    var onReview: () -> Void = {}
    /// Auf Mac und iPad sitzt die Wochennavigation im Fensterkopf.
    var showsNavigation = true

    private var layout: Binding<WeekLayout> {
        Binding(
            get: { WeekLayout(rawValue: layoutRaw) ?? .byDay },
            set: { layoutRaw = $0.rawValue }
        )
    }

    private var isWide: Bool {
#if os(macOS)
        true
#else
        horizontalClass == .regular
#endif
    }

    var body: some View {
        let sheet = WeekSheet(monday: weekStart, weeks: weeks, inbox: inbox)

        VStack(spacing: 0) {
            header(sheet)
                .padding(.horizontal, AnkerSpacing.screenPadding)
                .padding(.top, AnkerSpacing.s3)
                .padding(.bottom, AnkerSpacing.s3)

            if isWide {
                switch layout.wrappedValue {
                case .byDay: WeekGrid(sheet: sheet, now: now, undo: undo, onOpenAnchor: onOpenAnchor, onOpenDay: onOpenDay)
                case .byAnchor: WeekColumns(sheet: sheet, now: now, undo: undo, onOpenAnchor: onOpenAnchor)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
                        switch layout.wrappedValue {
                        case .byDay: phoneByDay(sheet)
                        case .byAnchor: phoneByAnchor(sheet)
                        }
                    }
                    .padding(.horizontal, AnkerSpacing.screenPadding)
                    .padding(.bottom, AnkerSpacing.s6)
                }
            }
        }
        .background(AnkerColor.ground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AnkerSpacing.s2) {
                BlattUndoBar(coordinator: undo, weeks: weeks)
                CaptureBar(
                    week: sheet.week,
                    weekStart: sheet.monday,
                    fallbackDate: sheet.dates.first { BlattDates.isToday($0, now: now) } ?? sheet.monday,
                    placeholder: "Was steht an?  ·  #1–#4 Anker, mo–so Tag"
                )
                .frame(maxWidth: 640)
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s3)
            .background(AnkerColor.ground)
            .animation(.easeOut(duration: 0.2), value: undo.notice?.id)
        }
    }

    // MARK: - Kopf

    private func header(_ sheet: WeekSheet) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            if showsNavigation {
                HStack(alignment: .bottom) {
                    BlattHeading(
                        eyebrow: AnkerDateFormat.weekSpan(monday: sheet.monday, sunday: sheet.sunday),
                        title: AnkerDateFormat.calendarWeek(sheet.isoWeek)
                    )
                    WeekStepper(onPrevious: onPreviousWeek, onNext: onNextWeek, onToday: onToday,
                                isCurrent: sheet.dates.contains { BlattDates.isToday($0, now: now) })
                }
            }
            HStack(spacing: AnkerSpacing.s3) {
                AnkerSegmented(
                    options: [(WeekLayout.byDay, isWide ? "Raster" : "Nach Tag"), (WeekLayout.byAnchor, "Nach Anker")],
                    selection: layout,
                    accessibilityLabel: "Darstellung der Woche"
                )
                .frame(maxWidth: isWide ? 260 : .infinity)
                if isWide {
                    Spacer()
                    if sheet.anchorLanes.count < 4 {
                        Button(sheet.anchorLanes.isEmpty ? "Woche setzen" : "Anker setzen", action: onStartWeek)
                            .buttonStyle(AnkerButtonStyle.secondary)
                    }
                }
            }
            if !isWide {
                // Auf dem iPhone gibt es keinen Fensterkopf: Setzen und Rückblick der angezeigten
                // Woche stehen deshalb hier — für jede Woche, nicht nur sonntags auf Heute.
                HStack(spacing: AnkerSpacing.s2) {
                    if sheet.anchorLanes.count < 4 && !sheet.anchorLanes.isEmpty {
                        Button("Anker setzen", action: onStartWeek)
                            .buttonStyle(AnkerButtonStyle.secondary)
                    }
                    Spacer(minLength: 0)
                    if sheet.week != nil {
                        Button(sheet.week?.isReviewed == true ? "Rückblick ansehen" : "Rückblick", action: onReview)
                            .buttonStyle(AnkerButtonStyle.secondary)
                    }
                }
            }
        }
    }

    // MARK: - iPhone: nach Tag

    @ViewBuilder
    private func phoneByDay(_ sheet: WeekSheet) -> some View {
        if sheet.anchorLanes.isEmpty {
            Button(action: onStartWeek) {
                BlattEmptyNote(text: "Noch keine Anker für diese Woche. Tippe hier, um sie zu setzen.")
            }
            .buttonStyle(.plain)
        } else {
            WeekOverviewGrid(sheet: sheet, now: now)
        }

        let unplanned = sheet.unplanned
        if let placing, placing.day != nil {
            // Eine geplante Aufgabe wird umgelegt: der Hinweis steht oben, der Vorrat bleibt,
            // wie er ist.
            HStack {
                Text(verbatim: "Neuen Tag wählen: \(placing.title)")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.accentInk)
                Spacer()
                Button { self.placing = nil } label: {
                    Text("Abbrechen")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .frame(minHeight: 44)
            .ankerCard(fill: AnkerColor.accentTint, elevated: false)
        }
        if !unplanned.isEmpty || (placing != nil && placing?.day == nil) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                Text(verbatim: placing.flatMap { $0.day == nil ? "Jetzt einen Tag wählen: \($0.title)" : nil } ?? "Noch ohne Tag · antippen, dann Tag wählen")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                FlowLayout(spacing: AnkerSpacing.s1 + 2) {
                    ForEach(unplanned) { task in
                        let isOn = placing?.id == task.id
                        Button {
                            placing = isOn ? nil : task
                        } label: {
                            HStack(spacing: AnkerSpacing.s1h) {
                                Text(verbatim: sheet.anchorNumber(of: task).map(String.init) ?? "–")
                                    .fontWeight(.heavy)
                                    .monospacedDigit()
                                Text(verbatim: task.title)
                            }
                            .ankerType(AnkerType.meta)
                            .foregroundStyle(isOn ? AnkerColor.onAccent : AnkerColor.ink)
                            .padding(.horizontal, AnkerSpacing.s3)
                            .frame(minHeight: 36)
                            .ankerControl(fill: isOn ? AnkerColor.accentFill : AnkerColor.card, stroke: isOn ? nil : AnkerColor.divider)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isOn ? .isSelected : [])
                    }
                }
            }
            .padding(AnkerSpacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .ankerLooseArea()
        }

        VStack(spacing: 0) {
            ForEach(Array(sheet.dates.enumerated()), id: \.offset) { index, date in
                if index > 0 { AnkerRule(weight: .row) }
                dayRow(sheet, index: index, date: date)
            }
        }
        .ankerCard()
    }

    private func dayRow(_ sheet: WeekSheet, index: Int, date: Date) -> some View {
        let isToday = BlattDates.isToday(date, now: now)
        let tasks = sheet.tasks(on: date)
        // Oben ausgerichtet: bei vielen Aufgaben stünde der Tag sonst mitten neben der Liste.
        return HStack(alignment: .top, spacing: AnkerSpacing.s2) {
            Button { onOpenDay(date) } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: isToday ? "Heute" : BlattDates.weekdayNames[index])
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(isToday ? AnkerColor.accentInk : AnkerColor.ink)
                    Text(verbatim: "\(AnkerDateFormat.dayNumber(date)).")
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                .frame(width: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(AnkerDateFormat.weekdayLongWithDayMonth(date)) öffnen")

            FlowLayout(spacing: AnkerSpacing.s1) {
                ForEach(tasks) { task in
                    TaskChip(
                        task: task,
                        number: sheet.anchorNumber(of: task).map(String.init) ?? "–",
                        onPick: task.isDone ? nil : {
                            placing = placing?.id == task.id ? nil : task
                        },
                        isPicked: placing?.id == task.id,
                        onUndoableAction: undo.present
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let placing, !(placing.day.map { AnkerCalendar.storedDay($0.date, isOn: date) } ?? false) {
                Button("Hierher") {
                    let snapshot = TaskActions.snapshot(placing)
                    TaskActions.place(placing, on: date, goalID: placing.linkedGoal?.id, weeks: weeks, modelContext: modelContext)
                    undo.present(TaskUndoNotice(message: "Auf \(AnkerDateFormat.weekdayLong(date)) gelegt", snapshots: [snapshot]))
                    self.placing = nil
                }
                .buttonStyle(AnkerButtonStyle.accent)
                .accessibilityLabel("\(placing.title) auf \(AnkerDateFormat.weekdayLong(date)) legen")
            }
        }
        .padding(.vertical, AnkerSpacing.s2)
        .padding(.horizontal, AnkerSpacing.s3)
        .frame(minHeight: 48)
        .background(isToday ? AnkerColor.todayTint : Color.clear)
    }

    // MARK: - iPhone: nach Anker

    @ViewBuilder
    private func phoneByAnchor(_ sheet: WeekSheet) -> some View {
        ForEach(sheet.lanes) { lane in
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    if let goal = lane.goal { onOpenAnchor(goal) }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s2) {
                        Text(verbatim: lane.numberLabel)
                            .ankerType(AnkerType.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(lane.isLoose ? AnkerColor.inkTertiary : AnkerColor.ink)
                            .frame(width: 22, alignment: .leading)
                        Text(verbatim: lane.title)
                            .ankerType(AnkerType.bodyStrong)
                            .foregroundStyle(AnkerColor.ink)
                        Spacer()
                        Text(verbatim: lane.isLoose ? BlattCount.tasks(lane.tasks.count) : "\(lane.doneCount) von \(lane.tasks.count)")
                            .ankerType(AnkerType.caption)
                            .monospacedDigit()
                            .foregroundStyle(AnkerColor.inkSecond)
                    }
                    .padding(.horizontal, AnkerSpacing.s3)
                    .padding(.top, AnkerSpacing.s3)
                    .padding(.bottom, AnkerSpacing.s2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(lane.isLoose)

                ForEach(lane.tasks) { task in
                    HStack(spacing: AnkerSpacing.s2) {
                        TaskChip(task: task, showsCheckbox: true, onUndoableAction: undo.present)
                        Spacer(minLength: AnkerSpacing.s2)
                        if task.day == nil && !task.isDone {
                            Button {
                                placing = task
                                layout.wrappedValue = .byDay
                            } label: {
                                Text("Tag wählen")
                                    .ankerType(AnkerType.caption)
                                    .foregroundStyle(AnkerColor.accentInk)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else if let day = task.day {
                            Text(verbatim: BlattDates.isToday(day.date, now: now) ? "Heute" : AnkerDateFormat.weekdayShort(day.date))
                                .ankerType(AnkerType.caption)
                                .foregroundStyle(BlattDates.isToday(day.date, now: now) ? AnkerColor.accentInk : AnkerColor.inkSecond)
                        }
                    }
                    .padding(.horizontal, AnkerSpacing.s3)
                    .frame(minHeight: 36)
                }
                Spacer(minLength: AnkerSpacing.s2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(LaneSurface(isLoose: lane.isLoose))
        }
    }
}

/// Ein Anker ist eine Karte, „ohne Anker" ein gestrichelter Bereich.
struct LaneSurface: ViewModifier {
    let isLoose: Bool

    func body(content: Content) -> some View {
        if isLoose {
            content.ankerLooseArea()
        } else {
            content.ankerCard()
        }
    }
}

/// ‹  Heute  › — der eine Zeitnavigator.
struct WeekStepper: View {
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onToday: () -> Void
    var isCurrent: Bool

    var body: some View {
        HStack(spacing: AnkerSpacing.s1 + 2) {
            stepButton(.chevronLeft, label: "Vorherige Woche", action: onPrevious)
            if !isCurrent {
                Button("Heute", action: onToday)
                    .buttonStyle(AnkerButtonStyle.secondary)
                    .accessibilityLabel("Zur laufenden Woche")
            }
            stepButton(.chevronRight, label: "Nächste Woche", action: onNext)
        }
    }

    private func stepButton(_ icon: AnkerIcon, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .ankerIcon(AnkerIconSize.s)
                .foregroundStyle(AnkerColor.ink)
                .frame(width: 40, height: 40)
                .ankerControl()
#if os(iOS)
                // Die Kachel bleibt 40pt, die Tippfläche ist Apples Mindestmaß.
                .frame(minWidth: 44, minHeight: 44)
#endif
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Der Überblick oben auf dem iPhone: vier Anker × sieben Tage, Zahl = Aufgaben an dem Tag.
/// Hellblau heißt geplant, dunkelblau alles erledigt — wo die Woche zu voll oder zu leer ist,
/// sieht man auf einen Blick.
struct WeekOverviewGrid: View {
    let sheet: WeekSheet
    let now: Date

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                Color.clear.frame(width: 16, height: 1)
                ForEach(Array(sheet.dates.enumerated()), id: \.offset) { index, date in
                    Text(verbatim: BlattDates.weekdayNames[index])
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(BlattDates.isToday(date, now: now) ? AnkerColor.accentInk : AnkerColor.inkSecond)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(sheet.anchorLanes) { lane in
                GridRow {
                    Text(verbatim: lane.numberLabel)
                        .ankerType(AnkerType.caption)
                        .monospacedDigit()
                        .foregroundStyle(AnkerColor.ink)
                    ForEach(Array(sheet.dates.enumerated()), id: \.offset) { _, date in
                        cell(sheet.tasks(in: lane, on: date), isToday: BlattDates.isToday(date, now: now))
                    }
                }
            }
        }
        .padding(AnkerSpacing.s3)
        .ankerCard()
        // Ein Element pro Anker statt vierzig Zellen: „Anker 1, Launch: Montag 2 Aufgaben, 1 erledigt; …"
        .accessibilityElement(children: .contain)
        .accessibilityLabel(overviewLabel)
        .accessibilityChildren {
            ForEach(sheet.anchorLanes) { lane in
                Text(verbatim: rowLabel(lane))
            }
        }
    }

    private var overviewLabel: String {
        let count = sheet.anchorLanes.count
        return "Überblick: \(count == 1 ? "ein Anker" : "\(count) Anker") über sieben Tage"
    }

    private func rowLabel(_ lane: WeekSheet.Lane) -> String {
        let days = sheet.dates.map { date -> String in
            let tasks = sheet.tasks(in: lane, on: date)
            let name = AnkerDateFormat.weekdayLong(date)
            guard !tasks.isEmpty else { return "\(name) keine" }
            let done = tasks.filter(\.isDone).count
            return "\(name) \(BlattCount.tasks(tasks.count)), \(done) erledigt"
        }
        return "Anker \(lane.numberLabel), \(lane.title): " + days.joined(separator: "; ")
    }

    private func cell(_ tasks: [AnkerTask], isToday: Bool) -> some View {
        let done = tasks.filter(\.isDone).count
        let allDone = !tasks.isEmpty && done == tasks.count
        return Text(verbatim: tasks.isEmpty ? "" : "\(tasks.count)")
            .ankerType(AnkerType.caption)
            .monospacedDigit()
            .foregroundStyle(allDone ? AnkerColor.onAccent : AnkerColor.accentInk)
            .frame(maxWidth: .infinity, minHeight: 22)
            .background(
                allDone ? AnkerColor.accentFill : (tasks.isEmpty ? AnkerColor.surface : AnkerColor.accentTint),
                in: RoundedRectangle(cornerRadius: AnkerRadius.cell, style: .continuous)
            )
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: AnkerRadius.cell, style: .continuous)
                        .strokeBorder(AnkerColor.accentMark, lineWidth: 1.5)
                }
            }
    }
}

// MARK: - Mac und iPad: das Raster

/// Zeile = Anker, Spalte = Tag, rechts der Vorrat „ohne Tag". Ziehen setzt Tag **und** Anker.
struct WeekGrid: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let sheet: WeekSheet
    let now: Date
    @ObservedObject var undo: TaskUndoCoordinator
    var onOpenAnchor: (Goal) -> Void
    var onOpenDay: (Date) -> Void

    private let looseColumn: CGFloat = 116

    /// Unter dieser Breite wird ein Chip unlesbar; dann scrollt das Raster waagerecht. Mit
    /// 150 + 116 + 7 × 84 = 854 passt das Raster bei 960pt Inhalt samt Rand ohne Querscroll.
    private let minimumDayColumn: CGFloat = 84

    /// Die Ankerspalte wächst mit dem Fenster, aber nie unter 150 und nie über 210.
    static func anchorColumnWidth(for available: CGFloat) -> CGFloat {
        min(210, max(150, (available * 0.18).rounded()))
    }

    var body: some View {
        GeometryReader { proxy in
            // Die Polsterung liegt außen, die Breite kommt aus dem Fenster: so füllt das Raster
            // den Platz, statt bei breitem Fenster in der Mitte zu hängen.
            let available = proxy.size.width - 2 * AnkerSpacing.screenPadding
            let anchorColumn = Self.anchorColumnWidth(for: available)
            let minimum = anchorColumn + looseColumn + 7 * minimumDayColumn
            ScrollView(available < minimum ? [.vertical, .horizontal] : .vertical) {
                VStack(spacing: 0) {
                    headerRow(anchorColumn: anchorColumn)
                    AnkerRule()
                    ForEach(Array(sheet.lanes.enumerated()), id: \.element.id) { index, lane in
                        if index > 0 { AnkerRule(weight: lane.isLoose ? .section : .row) }
                        row(lane, anchorColumn: anchorColumn)
                    }
                }
                .ankerCard()
                .frame(width: max(available, minimum))
                .padding(.horizontal, AnkerSpacing.screenPadding)
                .padding(.bottom, AnkerSpacing.s4)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
    }

    private func headerRow(anchorColumn: CGFloat) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: anchorColumn, height: 40)
            ForEach(Array(sheet.dates.enumerated()), id: \.offset) { index, date in
                let isToday = BlattDates.isToday(date, now: now)
                Button { onOpenDay(date) } label: {
                    HStack(spacing: AnkerSpacing.s1) {
                        Text(verbatim: isToday ? "Heute" : BlattDates.weekdayNames[index])
                            .foregroundStyle(isToday ? AnkerColor.accentInk : AnkerColor.ink)
                        Text(verbatim: "\(AnkerDateFormat.dayNumber(date)).")
                            .foregroundStyle(AnkerColor.inkSecond)
                            .monospacedDigit()
                    }
                    .ankerType(AnkerType.caption)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(isToday ? AnkerColor.todayTint : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .ankerEdge(.leading, color: AnkerColor.cardDivider)
            }
            Text("Ohne Tag")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .frame(width: looseColumn, height: 40)
                .background(AnkerColor.surface)
                .ankerEdge(.leading)
        }
    }

    private func row(_ lane: WeekSheet.Lane, anchorColumn: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            laneHeader(lane)
                .frame(width: anchorColumn, alignment: .topLeading)
            ForEach(Array(sheet.dates.enumerated()), id: \.offset) { _, date in
                cell(lane, date: date)
                    .background(BlattDates.isToday(date, now: now) ? AnkerColor.todayTint : Color.clear)
                    .ankerEdge(.leading, color: AnkerColor.cardDivider)
            }
            cell(lane, date: nil)
                .frame(width: looseColumn)
                .background(AnkerColor.surface)
                .ankerEdge(.leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: 104)
        .background(lane.isLoose ? AnkerColor.surface.opacity(0.5) : Color.clear)
    }

    private func laneHeader(_ lane: WeekSheet.Lane) -> some View {
        Button {
            if let goal = lane.goal { onOpenAnchor(goal) }
        } label: {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s2) {
                    Text(verbatim: lane.numberLabel)
                        .ankerType(AnkerType.anchorNumber)
                        .foregroundStyle(lane.isLoose ? AnkerColor.inkTertiary : AnkerColor.ink)
                    Text(verbatim: lane.title)
                        .ankerType(AnkerType.bodyStrong)
                        .foregroundStyle(AnkerColor.ink)
                        .lineLimit(2)
                }
                if let why = lane.why {
                    Text(verbatim: why)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .lineLimit(2)
                } else if lane.isLoose {
                    Text("Muss sein, zählt nicht zur Woche.")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                Spacer(minLength: AnkerSpacing.s2)
                if !lane.isLoose {
                    AnkerPips(done: lane.doneCount, total: lane.tasks.count, size: 8)
                }
            }
            .padding(AnkerSpacing.s3)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(lane.isLoose)
    }

    private func cell(_ lane: WeekSheet.Lane, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            ForEach(sheet.tasks(in: lane, on: date)) { task in
                TaskChip(task: task, compact: true, showsCheckbox: true, onUndoableAction: undo.present)
            }
            Spacer(minLength: 0)
        }
        .padding(AnkerSpacing.s1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            drop(items, on: date, goal: lane.goal)
        }
    }

    /// Snapshot vor der Mutation, damit „Rückgängig" die Aufgabe genau zurücklegt.
    private func drop(_ items: [String], on date: Date?, goal: Goal?) -> Bool {
        guard let task = WeekDropSupport.task(from: items, modelContext: modelContext) else { return false }
        let id = task.id
        let snapshot = TaskActions.snapshot(task)
        let placed: Bool = BlattDrop.place(items, on: date, goal: goal, weeks: weeks, modelContext: modelContext)
        TaskDragEvents.end(taskID: id)
        if placed {
            let message = date.map { "Auf \(AnkerDateFormat.weekdayLong($0)) gelegt" } ?? "Ohne Tag gelegt"
            undo.present(TaskUndoNotice(message: message, snapshots: [snapshot]))
        }
        return placed
    }
}

/// Gemeinsames der beiden Drop-Ziele der Woche.
enum WeekDropSupport {
    @MainActor
    static func task(from items: [String], modelContext: ModelContext) -> AnkerTask? {
        guard let raw = items.first, let id = UUID(uuidString: raw) else { return nil }
        return try? modelContext.fetch(FetchDescriptor<AnkerTask>(predicate: #Predicate { $0.id == id })).first
    }
}

/// Zählwörter mit richtiger Einzahl.
enum BlattCount {
    static func tasks(_ count: Int) -> String {
        count == 1 ? "1 Aufgabe" : "\(count) Aufgaben"
    }
}

// MARK: - Mac und iPad: nach Anker

/// Eine Spalte pro Anker, rechts „ohne Anker". Ablegen auf einer Spalte setzt den Anker.
struct WeekColumns: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let sheet: WeekSheet
    let now: Date
    @ObservedObject var undo: TaskUndoCoordinator
    var onOpenAnchor: (Goal) -> Void

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: AnkerSpacing.s3) {
                ForEach(sheet.lanes) { lane in
                    column(lane)
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.bottom, AnkerSpacing.s4)
        }
    }

    @ViewBuilder
    private func dayLabel(for task: AnkerTask) -> some View {
        if let day = task.day {
            let isToday = BlattDates.isToday(day.date, now: now)
            Text(verbatim: isToday ? "Heute" : AnkerDateFormat.weekdayShort(day.date))
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(isToday ? AnkerColor.accentInk : AnkerColor.inkSecond)
        } else {
            Text("Ohne Tag")
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(AnkerColor.inkTertiary)
        }
    }

    private func column(_ lane: WeekSheet.Lane) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Button {
                if let goal = lane.goal { onOpenAnchor(goal) }
            } label: {
                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: lane.numberLabel)
                            .ankerType(AnkerType.title3)
                            .foregroundStyle(lane.isLoose ? AnkerColor.inkTertiary : AnkerColor.ink)
                        Spacer()
                        Text(verbatim: lane.isLoose ? BlattCount.tasks(lane.tasks.count) : "\(lane.doneCount) von \(lane.tasks.count)")
                            .ankerType(AnkerType.caption)
                            .monospacedDigit()
                            .foregroundStyle(AnkerColor.inkSecond)
                    }
                    Text(verbatim: lane.title)
                        .ankerType(AnkerType.subheadline)
                        .foregroundStyle(AnkerColor.ink)
                    if let why = lane.why {
                        Text(verbatim: why)
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.inkSecond)
                    }
                    if !lane.isLoose {
                        AnkerProgressBar(progress: lane.tasks.isEmpty ? 0 : Double(lane.doneCount) / Double(lane.tasks.count))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(lane.isLoose)

            VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                ForEach(lane.tasks) { task in
                    // Der Tag steht über dem Chip, nicht daneben: in schmalen Spalten (iPad mit
                    // Seitenleiste) blieb dem Titel neben „Heute" sonst kaum Breite.
                    VStack(alignment: .leading, spacing: AnkerSpacing.s0) {
                        dayLabel(for: task)
                        TaskChip(task: task, compact: true, showsCheckbox: true, onUndoableAction: undo.present)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, minHeight: 320, alignment: .topLeading)
        .modifier(LaneSurface(isLoose: lane.isLoose))
        .contentShape(Rectangle())
        .dropDestination(for: String.self) { items, _ in
            guard let task = WeekDropSupport.task(from: items, modelContext: modelContext) else { return false }
            let snapshot = TaskActions.snapshot(task)
            TaskActions.link(task, to: lane.goal, modelContext: modelContext)
            TaskDragEvents.end(taskID: task.id)
            undo.present(TaskUndoNotice(
                message: lane.goal == nil ? "Ohne Anker gelegt" : "An Anker \(lane.numberLabel) gehängt",
                snapshots: [snapshot]
            ))
            return true
        }
    }
}
