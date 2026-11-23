import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Detailansicht eines einzelnen Tages: Kennzahlen, Tagesfokus, Anker dieses Tages, Zeitplan,
/// Aufgaben (offen, dann erledigt) und freie Notizen.
///
/// Die Ansicht rendert mit einem **Datum** — ein gespeicherter `Day` ist optional. Wochen und
/// Tage entstehen erst beim Schreiben (Fokus, Notiz, abgelegte oder erfasste Aufgabe); vorher
/// legte schon das Öffnen eines Tages beides an, auch beim Wiederherstellen und über Deep Links,
/// und auf einem frischen Gerät entstanden so Duplikate vor dem iCloud-Import.
struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Week.monday) private var weeks: [Week]

    let date: Date
    var now: Date = Date()
    var onSelectGoal: (Goal) -> Void = { _ in }

    @StateObject private var undo = TaskUndoCoordinator()

    @State private var focusDraft = ""
    @State private var notesDraft = ""
    @State private var hasLoadedDrafts = false
    @State private var commitTask: Task<Void, Never>?
    @State private var isDropTargeted = false

    private var monday: Date { AnkerCalendar.weekInterval(containing: date).monday }

    private var week: Week? { WeekPlanning.week(startingAt: monday, in: weeks) }

    private var day: Day? { WeekPlanning.existingDay(on: date, in: week) }

    private var sheet: WeekSheet { WeekSheet(monday: monday, weeks: weeks, inbox: []) }

    private var isToday: Bool {
        AnkerCalendar.isSameDay(date, now)
    }

    var body: some View {
        let sheet = sheet
        let tasks = sheet.tasks(on: date)

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(tasks: tasks, isoWeek: sheet.isoWeek)
                statsRow(tasks: tasks)
                focusSection
                goalSection(sheet: sheet, tasks: tasks)
                scheduleSection
                taskSection(sheet: sheet, tasks: tasks)
                notesSection
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.bottom, AnkerSpacing.s5)
        }
        .background(AnkerColor.ground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AnkerSpacing.s2) {
                BlattUndoBar(coordinator: undo, weeks: weeks)
                // Legt Woche und Tag erst beim Sichern an — wie überall.
                CaptureBar(
                    week: sheet.week,
                    weekStart: sheet.monday,
                    fallbackDate: date,
                    placeholder: "Was steht an diesem Tag an?  ·  #1–#4 Anker"
                )
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(AnkerColor.ground)
            .animation(.easeOut(duration: 0.2), value: undo.notice?.id)
        }
        .navigationTitle(navigationTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear(perform: loadDraftsIfNeeded)
        .onDisappear(perform: commitNow)
        .onDrop(
            of: TaskDropHandling.draggedTypes,
            isTargeted: $isDropTargeted
        ) { providers in
            dropTask(from: providers)
        }
    }

    private var navigationTitle: String {
        let weekday = AnkerDateFormat.weekdayLong(date)
        return isToday ? "\(weekday) — Heute" : weekday
    }

    // MARK: - Kopf

    private func header(tasks: [AnkerTask], isoWeek: Int) -> some View {
        let progress = Self.progress(tasks)
        return VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            HStack(alignment: .top, spacing: AnkerSpacing.s3) {
                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(verbatim: "\(AnkerDateFormat.dayMonthYear(date)) · \(AnkerDateFormat.calendarWeek(isoWeek))")
                        .ankerType(AnkerType.numericSmall)
                        .foregroundStyle(AnkerColor.inkSecond)

                    Text(verbatim: isToday ? "Heute, \(AnkerDateFormat.weekdayLong(date))" : AnkerDateFormat.weekdayLong(date))
                        .ankerType(AnkerType.headline)
                        .foregroundStyle(isToday ? AnkerColor.accentInk : AnkerColor.ink)
                        .accessibilityAddTraits(.isHeader)
                }

                Spacer(minLength: AnkerSpacing.s2)

                Text(verbatim: "\(Int(progress * 100))%")
                    .ankerType(AnkerType.statValue)
                    .foregroundStyle(AnkerColor.ink)
                    .accessibilityLabel("\(Int(progress * 100)) Prozent des Tages erledigt")
            }

            AnkerProgressBar(progress: progress, thickness: AnkerBorder.rule * 3)
                .padding(.top, AnkerSpacing.s2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnkerSpacing.s4)
        .padding(.vertical, AnkerSpacing.s3)
        .ankerPanel()
        .overlay {
            if isDropTargeted {
                Rectangle()
                    .stroke(AnkerColor.accentFill, lineWidth: 2)
            }
        }
        .padding(.top, AnkerSpacing.s3)
    }

    private static func progress(_ tasks: [AnkerTask]) -> Double {
        tasks.isEmpty ? 0 : Double(tasks.filter(\.isDone).count) / Double(tasks.count)
    }

    // MARK: - Kennzahlen

    private func statsRow(tasks: [AnkerTask]) -> some View {
        let done = tasks.filter(\.isDone).count
        return HStack(spacing: AnkerSpacing.s2) {
            statTile(value: tasks.count - done, label: "Offen", tint: AnkerColor.accentInk)
            statTile(value: done, label: "Erledigt", tint: AnkerColor.ink)
            statTile(value: day?.timeBlockList.count ?? 0, label: "Zeitblöcke", tint: AnkerColor.inkTertiary)
        }
        .padding(.top, AnkerSpacing.s4)
    }

    private func statTile(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            Text(verbatim: String(value))
                .ankerType(AnkerType.headline)
                .foregroundStyle(tint)
            Text(label)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s3)
        .ankerCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }

    // MARK: - Tagesfokus

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Fokus des Tages")

            TextField("Worauf kommt es heute an?", text: $focusDraft, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...3)
                .ankerType(AnkerType.meta)
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s3)
                .ankerField()
                .onChange(of: focusDraft) { _, _ in scheduleCommit() }
                .accessibilityLabel("Fokus des Tages")
        }
    }

    // MARK: - Anker

    @ViewBuilder
    private func goalSection(sheet: WeekSheet, tasks: [AnkerTask]) -> some View {
        let lanes = sheet.anchorLanes.filter { lane in
            tasks.contains { $0.linkedGoal?.id == lane.goal?.id }
        }
        if !lanes.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(title: "Anker an diesem Tag")

                VStack(spacing: AnkerSpacing.s2) {
                    ForEach(lanes) { lane in
                        if let goal = lane.goal {
                            goalRow(goal, lane: lane, tasks: tasks)
                        }
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: Goal, lane: WeekSheet.Lane, tasks: [AnkerTask]) -> some View {
        let dayTasks = tasks.filter { $0.linkedGoal?.id == goal.id }
        let dayDone = dayTasks.filter(\.isDone).count
        let weekPercent = lane.tasks.isEmpty ? 0 : Int(Double(lane.doneCount) / Double(lane.tasks.count) * 100)

        return Button {
            onSelectGoal(goal)
        } label: {
            HStack(spacing: AnkerSpacing.s3) {
                Text(verbatim: lane.numberLabel)
                    .ankerType(AnkerType.bodyStrong)
                    .monospacedDigit()
                    .foregroundStyle(AnkerColor.ink)
                    .frame(width: 18, alignment: .leading)

                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(verbatim: goal.title)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.ink)
                        .lineLimit(1)
                    Text(verbatim: "\(dayDone) von \(dayTasks.count) an diesem Tag")
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                }

                Spacer(minLength: AnkerSpacing.s2)

                Text(verbatim: "\(weekPercent)%")
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s3)
            .ankerCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Anker öffnen: \(goal.title)")
        .accessibilityLabel("Anker \(lane.numberLabel), \(goal.title), \(weekPercent) Prozent der Woche erledigt, \(dayDone) von \(dayTasks.count) Aufgaben an diesem Tag erledigt")
        .accessibilityHint("Öffnet den Anker")
    }

    // MARK: - Zeitplan

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Zeitplan")

            let blocks = (day?.timeBlockList ?? []).sorted { $0.startTime < $1.startTime }
            if blocks.isEmpty {
                emptyHint("Für diesen Tag sind keine Zeitblöcke eingetragen.")
            } else {
                let blocks = blocks.sorted { $0.startTime < $1.startTime }
                VStack(spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        DayTimeBlockRow(block: block)
                        if index < blocks.count - 1 {
                            AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                        }
                    }
                }
                .ankerCard()
            }
        }
    }

    // MARK: - Aufgaben

    /// Offen zuerst, darunter das Erledigte — das Blatt gliedert nach Zustand und Anker, nicht
    /// nach Priorität. Die Ankernummer steht rechts an jeder Zeile.
    private func taskSection(sheet: WeekSheet, tasks: [AnkerTask]) -> some View {
        let open = tasks.filter { !$0.isDone }
        let done = tasks.filter(\.isDone)
        return VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Aufgaben")

            if tasks.isEmpty {
                emptyHint("Noch keine Aufgaben. Schreib unten, was an diesem Tag ansteht.")
            } else {
                taskGroup(title: "Offen", tasks: open)
                taskGroup(title: "Erledigt", tasks: done)
            }
        }
    }

    @ViewBuilder
    private func taskGroup(title: String, tasks: [AnkerTask]) -> some View {
        if !tasks.isEmpty {
            Text(verbatim: "\(title) · \(tasks.count)")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s3)
                .padding(.bottom, AnkerSpacing.s2)

            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    if index > 0 { AnkerRule(weight: .row) }
                    TaskCard(
                        task: task,
                        showPriority: false,
                        metaLine: .none,
                        showsAnchorNumber: true,
                        onUndoableAction: undo.present
                    )
                    .padding(.horizontal, AnkerSpacing.s3)
                }
            }
            .ankerCard()
        }
    }

    // MARK: - Notizen

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Notizen")

            TextEditor(text: $notesDraft)
                .scrollContentBackground(.hidden)
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.ink)
                .frame(minHeight: 96)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s2)
                .ankerField()
                .onChange(of: notesDraft) { _, _ in scheduleCommit() }
                .accessibilityLabel("Notizen zum Tag")
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .ankerType(AnkerType.caption)
            .foregroundStyle(AnkerColor.inkSecond)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s4)
            .ankerCard(fill: AnkerColor.surface.opacity(0.6), elevated: false)
    }

    // MARK: - Aktionen

    private func dropTask(from providers: [NSItemProvider]) -> Bool {
        let targetDate = date

        return TaskDropHandling.loadTaskID(from: providers) { taskID in
            let snapshot = TaskDropHandling.moveTask(id: taskID, to: targetDate, weeks: weeks, modelContext: modelContext)
            isDropTargeted = false

            if let snapshot {
                undo.present(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: [snapshot]))
            }
        }
    }

    private func loadDraftsIfNeeded() {
        guard !hasLoadedDrafts else { return }
        focusDraft = day?.focusNote ?? ""
        notesDraft = day?.notes ?? ""
        hasLoadedDrafts = true
    }

    /// Tippen soll nicht jeden Anschlag speichern — CloudKit wuerde daraus einen
    /// Export pro Zeichen machen.
    private func scheduleCommit() {
        guard hasLoadedDrafts else { return }

        commitTask?.cancel()
        commitTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            commitDrafts()
        }
    }

    private func commitNow() {
        commitTask?.cancel()
        commitTask = nil
        commitDrafts()
    }

    /// Erst wenn sich wirklich etwas ändert, entstehen Woche und Tag.
    private func commitDrafts() {
        guard hasLoadedDrafts else { return }

        let focus = normalized(focusDraft)
        let notes = normalized(notesDraft)
        guard day?.focusNote != focus || day?.notes != notes else { return }
        // Ohne gespeicherten Tag ist „nichts" schon der Stand — dafür keinen Tag anlegen.
        if day == nil && focus == nil && notes == nil { return }

        let target: Day
        if let day {
            target = day
        } else {
            let week = TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
            target = TaskActions.ensureDay(containing: date, in: week)
        }
        if target.focusNote != focus { target.focusNote = focus }
        if target.notes != notes { target.notes = notes }
        modelContext.saveChanges()
    }

    private func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DayTimeBlockRow: View {
    let block: TimeBlock

    private var isAnchored: Bool {
        block.linkedEventIdentifier != nil
    }

    var body: some View {
        HStack(spacing: AnkerSpacing.s3) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(AnkerDateFormat.timeOfDay(block.startTime))
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.ink)
                Text(AnkerDateFormat.timeOfDay(block.endTime))
                    .ankerType(AnkerType.numericSmall)
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .frame(width: 44, alignment: .leading)

            HStack {
                Text(block.title)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: AnkerSpacing.s2)
                if isAnchored {
                    Image(.week)
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.accentInk)
                        .accessibilityLabel("Aus dem Kalender übernommen")
                }
            }
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s3)
        .accessibilityElement(children: .combine)
    }
}

