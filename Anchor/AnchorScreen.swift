import SwiftData
import SwiftUI

/// Ein Anker: große Nummer, Titel, warum er zählt, Fortschritt, seine Woche Tag für Tag.
struct AnchorScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]
    @Query(filter: #Predicate<AnkerTask> { $0.day == nil && $0.linkedGoal == nil }) private var inbox: [AnkerTask]

    @Bindable var goal: Goal
    var now: Date = Date()
    var onDeleted: () -> Void = {}

    @StateObject private var undo = TaskUndoCoordinator()
    @StateObject private var selection = TaskSelectionModel()
    @State private var editing = false
    @State private var goalPendingDeletion: Goal?
    @State private var newTitle = ""

    private var week: Week? { goal.week }

    var body: some View {
        // Einmal pro Durchlauf — als berechnete Eigenschaften baute jeder Zugriff ein neues Blatt.
        let sheet = week.map { WeekSheet(monday: $0.monday, weeks: weeks, inbox: inbox) }
        let lane = sheet?.anchorLanes.first { $0.goal?.id == goal.id }

        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s5) {
                header(lane: lane)
                progress(lane: lane)
                if let sheet, let lane {
                    days(sheet: sheet, lane: lane)
                }
                addField
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.top, AnkerSpacing.s3)
            .padding(.bottom, AnkerSpacing.s6)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: AnkerSpacing.s2) {
                BlattUndoBar(coordinator: undo, weeks: weeks)
                if selection.isActive {
                    BlattBulkActionBar(
                        selection: selection,
                        tasks: lane?.tasks ?? [],
                        anchors: sheet?.anchorLanes.compactMap(\.goal) ?? [],
                        undo: undo
                    )
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.bottom, AnkerSpacing.s2)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .animation(.easeOut(duration: 0.15), value: selection.isActive)
        }
        .sheet(isPresented: $editing) {
            AnchorEditSheet(goal: goal)
        }
        .goalDeleteConfirmation(goal: $goalPendingDeletion, week: week, onDeleted: onDeleted)
    }

    private func header(lane: WeekSheet.Lane?) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            HStack {
                if let week {
                    Text(verbatim: AnkerDateFormat.calendarWeek(week.isoWeek))
                        .ankerType(AnkerType.overline)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                Spacer()
                Menu {
                    Button("Bearbeiten") { editing = true }
                    Button("Anker löschen", role: .destructive) { goalPendingDeletion = goal }
                } label: {
                    Image(.more)
                        .ankerIcon(AnkerIconSize.m)
                        .foregroundStyle(AnkerColor.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .accessibilityLabel("Ankeraktionen")
                .help("Ankeraktionen")
            }

            HStack(alignment: .top, spacing: AnkerSpacing.s3) {
                Text(verbatim: lane?.numberLabel ?? "–")
                    .ankerType(AnkerType.poster)
                    .foregroundStyle(AnkerColor.ink)
                    .accessibilityLabel("Anker \(lane?.numberLabel ?? "")")
                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    Text(verbatim: goal.title)
                        .ankerType(AnkerType.title3)
                        .foregroundStyle(AnkerColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    if let why = goal.why?.nilIfBlank {
                        Text(verbatim: why)
                            .ankerType(AnkerType.body)
                            .foregroundStyle(AnkerColor.inkSecond)
                    } else {
                        Button("Warum zählt das diese Woche?") { editing = true }
                            .ankerType(AnkerType.body)
                            .foregroundStyle(AnkerColor.accentInk)
                            .buttonStyle(.plain)
                    }
                }
                .padding(.top, AnkerSpacing.s2)
            }
        }
    }

    private func progress(lane: WeekSheet.Lane?) -> some View {
        let done = lane?.doneCount ?? 0
        let total = lane?.tasks.count ?? 0
        return VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            AnkerProgressBar(progress: total == 0 ? 0 : Double(done) / Double(total), thickness: 8)
            Text(verbatim: total == 0 ? String(localized: "Noch keine Aufgabe an diesem Anker") : String(localized: "\(done) von \(total) erledigt"))
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.inkSecond)
                .accessibilityIdentifier("anchorProgress")
        }
    }

    private func days(sheet: WeekSheet, lane: WeekSheet.Lane) -> some View {
        let groups: [(label: String, isToday: Bool, tasks: [AnkerTask])] =
            sheet.dates.enumerated().compactMap { index, date in
                let tasks = sheet.tasks(in: lane, on: date)
                guard !tasks.isEmpty else { return nil }
                let isToday = BlattDates.isToday(date, now: now)
                return (isToday ? String(localized: "Heute") : AnkerDateFormat.weekdayLong(date), isToday, tasks)
            } + [(String(localized: "Ohne Tag"), false, sheet.tasks(in: lane, on: nil))].filter { !$0.tasks.isEmpty }

        return VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s3) {
                BlattSectionLabel(title: String(localized: "Diese Woche"))
                if !groups.isEmpty {
                    BlattSelectButton(selection: selection)
                }
            }
            if groups.isEmpty {
                BlattEmptyNote(text: String(localized: "Leg unten die erste Aufgabe für diesen Anker an."))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { index, group in
                        if index > 0 { AnkerRule(weight: .row) }
                        HStack(alignment: .top, spacing: AnkerSpacing.s2) {
                            Text(verbatim: group.label)
                                .ankerType(AnkerType.caption)
                                .foregroundStyle(group.isToday ? AnkerColor.accentInk : AnkerColor.inkSecond)
                                .frame(width: 76, alignment: .leading)
                                .padding(.top, AnkerSpacing.s3 + 2)
                            VStack(spacing: 0) {
                                ForEach(group.tasks) { task in
                                    TaskCard(
                                        task: task,
                                        showPriority: false,
                                        metaLine: .none,
                                        isSelectionMode: selection.isActive,
                                        isSelected: selection.contains(task),
                                        onSelectionToggle: { selection.toggle(task) },
                                        onStartSelection: { withAnimation(.easeOut(duration: 0.15)) { selection.start(with: task) } },
                                        onUndoableAction: undo.present
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, AnkerSpacing.s3)
                    }
                }
                .ankerCard()
            }
        }
    }

    private var addField: some View {
        HStack(spacing: AnkerSpacing.s2) {
            TextField("Aufgabe zu diesem Anker", text: $newTitle)
                .textFieldStyle(.plain)
                .ankerType(AnkerType.body)
                .onSubmit(add)
            Button(action: add) {
                Image(.add)
                    .ankerIcon(AnkerIconSize.m)
                    .foregroundStyle(AnkerColor.onInk)
                    .frame(width: 38, height: 38)
                    .background(AnkerColor.ink, in: RoundedRectangle(cornerRadius: AnkerRadius.inlineButton, style: .continuous))
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityLabel("Aufgabe anlegen")
        }
        .padding(.leading, AnkerSpacing.s4)
        .padding(.trailing, AnkerSpacing.s1)
        .frame(minHeight: 50)
        .ankerField(radius: AnkerRadius.bar)
    }

    /// Neue Aufgaben am Anker haben noch keinen Tag — eingeplant wird in der Woche.
    private func add() {
        guard TaskActions.createUnscheduled(title: newTitle, goal: goal, modelContext: modelContext) != nil else { return }
        newTitle = ""
    }
}

/// Titel und Warum-Satz eines Ankers.
struct AnchorEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var goal: Goal

    @State private var title = ""
    @State private var why = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
            Text("Anker bearbeiten")
                .ankerType(AnkerType.headline)
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text("Titel").ankerType(AnkerType.caption).foregroundStyle(AnkerColor.inkSecond)
                TextField("Titel", text: $title)
                    .textFieldStyle(.plain)
                    .ankerType(AnkerType.body)
                    .padding(AnkerSpacing.s3)
                    .ankerField()
            }
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text("Warum zählt das diese Woche?").ankerType(AnkerType.caption).foregroundStyle(AnkerColor.inkSecond)
                TextField("Ein Satz genügt", text: $why, axis: .vertical)
                    .textFieldStyle(.plain)
                    .ankerType(AnkerType.body)
                    .lineLimit(1...3)
                    .padding(AnkerSpacing.s3)
                    .ankerField()
            }
            HStack {
                Button("Abbrechen") { dismiss() }
                    .buttonStyle(AnkerButtonStyle.secondary)
                Spacer()
                Button("Sichern") {
                    let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty { goal.title = clean }
                    goal.why = why.nilIfBlank?.trimmingCharacters(in: .whitespacesAndNewlines)
                    modelContext.saveChanges()
                    dismiss()
                }
                .buttonStyle(AnkerButtonStyle.primary)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(AnkerSpacing.s5)
        .frame(minWidth: 360)
        .background(AnkerColor.ground)
        .presentationDetents([.medium])
        .onAppear {
            title = goal.title
            why = goal.why ?? ""
        }
    }
}
