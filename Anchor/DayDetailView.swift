import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Detailansicht eines einzelnen Tages.
///
/// Bis hierher fuehrte ein Klick auf einen Tag nur dazu, dass er in der Wochenuebersicht
/// hervorgehoben wurde. Diese Ansicht zeigt den Tag stattdessen vollstaendig: Kennzahlen,
/// Tagesfokus, betroffene Wochenziele, Zeitplan, Aufgaben nach Prioritaet und freie Notizen.
/// `focusNote` und `notes` am `Day`-Modell waren bisher nirgends bearbeitbar.
struct DayDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Week.monday) private var weeks: [Week]

    @Bindable var day: Day
    let week: Week
    var onAddTask: () -> Void = {}
    var onSelectGoal: (Goal) -> Void = { _ in }
    var onClose: (() -> Void)?

    @StateObject private var undo = TaskUndoCoordinator()

    @State private var focusDraft = ""
    @State private var notesDraft = ""
    @State private var hasLoadedDrafts = false
    @State private var commitTask: Task<Void, Never>?
    @State private var isDropTargeted = false

    private var tasks: [AnkerTask] {
        day.taskList.sorted { $0.order < $1.order }
    }

    private var doneCount: Int {
        day.taskList.filter(\.isDone).count
    }

    private var openCount: Int {
        day.taskList.count - doneCount
    }

    private var progress: Double {
        day.taskList.isEmpty ? 0 : Double(doneCount) / Double(day.taskList.count)
    }

    private var linkedGoals: [Goal] {
        var seen = Set<UUID>()
        return day.taskList
            .compactMap(\.linkedGoal)
            .filter { seen.insert($0.id).inserted }
    }

    private var isToday: Bool {
        AnkerCalendar.isSameDay(day.date, Date())
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    statsRow
                    focusSection
                    goalSection
                    scheduleSection
                    taskSection
                    notesSection
                }
                .padding(.horizontal, AnkerSpacing.screenPadding)
                .padding(.bottom, 96)
            }
            .background(AnkerColor.paper)

            VStack(spacing: 10) {
                if let notice = undo.notice {
                    TaskUndoToast(notice: notice) {
                        undo.undo(weeks: weeks, modelContext: modelContext)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
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
        let weekday = day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide))
        return isToday ? "\(weekday) — Heute" : weekday
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(headerMeta)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(AnkerColor.muted)
                        .tracking(0.35)

                    Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                }

                Spacer(minLength: 8)

                ProgressRing(progress: progress, color: AnkerColor.indigo, lineWidth: 5)
                    .frame(width: 38, height: 38)
                    .accessibilityLabel("\(Int(progress * 100)) Prozent des Tages erledigt")
            }

            if let onClose {
                Button(action: onClose) {
                    Label("Zur Wochenübersicht", systemImage: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AnkerColor.indigoText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück zur Wochenübersicht")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AnkerColor.indigo, lineWidth: 2)
            }
        }
        .padding(.top, 12)
    }

    private var headerMeta: String {
        let date = day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
        return "\(date) · KW \(String(format: "%02d", week.isoWeek))"
    }

    // MARK: - Kennzahlen

    private var statsRow: some View {
        HStack(spacing: 8) {
            statTile(value: openCount, label: "Offen", tint: AnkerColor.indigoText)
            statTile(value: doneCount, label: "Erledigt", tint: AnkerColor.successIcon)
            statTile(value: day.timeBlockList.count, label: "Zeitblöcke", tint: AnkerColor.brass)
        }
        .padding(.top, 14)
    }

    private func statTile(value: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: String(value))
                .font(.system(size: 19, weight: .bold, design: .monospaced))
                .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AnkerColor.card)
        .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AnkerColor.card)
                .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
                .onChange(of: focusDraft) { _, _ in scheduleCommit() }
                .accessibilityLabel("Fokus des Tages")
        }
    }

    // MARK: - Wochenziele

    @ViewBuilder
    private var goalSection: some View {
        if !linkedGoals.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionLabel(title: "Verankerte Wochenziele")

                VStack(spacing: 8) {
                    ForEach(linkedGoals, id: \.id) { goal in
                        goalRow(goal)
                    }
                }
            }
        }
    }

    private func goalRow(_ goal: Goal) -> some View {
        let dayTasks = day.taskList.filter { $0.linkedGoal?.id == goal.id }
        let dayDone = dayTasks.filter(\.isDone).count

        return Button {
            onSelectGoal(goal)
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(hex: goal.colorHex))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AnkerColor.ink)
                        .lineLimit(1)
                    Text("\(dayDone) von \(dayTasks.count) an diesem Tag")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(AnkerColor.muted)
                }

                Spacer(minLength: 8)

                ProgressRing(progress: goal.progress, color: Color(hex: goal.colorHex), lineWidth: 4)
                    .frame(width: 22, height: 22)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AnkerColor.card)
            .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
        }
        .buttonStyle(.plain)
        .help("Ziel öffnen: \(goal.title)")
        .accessibilityLabel("Ziel \(goal.title), \(Int(goal.progress * 100)) Prozent erreicht, \(dayDone) von \(dayTasks.count) Aufgaben an diesem Tag erledigt")
    }

    // MARK: - Zeitplan

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Zeitplan")

            if day.timeBlockList.isEmpty {
                emptyHint("Für diesen Tag sind keine Zeitblöcke eingetragen.")
            } else {
                VStack(spacing: 0) {
                    ForEach(day.timeBlockList.sorted { $0.startTime < $1.startTime }, id: \.id) { block in
                        DayTimeBlockRow(block: block)
                    }
                }
            }
        }
    }

    // MARK: - Aufgaben

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                SectionLabel(title: "Aufgaben")
                Spacer(minLength: 8)
                Button(action: onAddTask) {
                    Label("Neu", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AnkerColor.indigoText)
                }
                .buttonStyle(.plain)
                .help("Neue Aufgabe für diesen Tag")
                .accessibilityLabel("Neue Aufgabe für diesen Tag erstellen")
                .padding(.bottom, 8)
            }

            if tasks.isEmpty {
                emptyHint("Noch keine Aufgaben. Über den Neu-Button anlegen oder eine Aufgabe hierher ziehen.")
            } else {
                ForEach(Priority.allCases, id: \.self) { priority in
                    let priorityTasks = tasks.filter { $0.priority == priority }
                    if !priorityTasks.isEmpty {
                        Text("Prio \(priority.label)")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(AnkerColor.muted)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                        VStack(spacing: 8) {
                            ForEach(priorityTasks, id: \.id) { task in
                                TaskCard(task: task, onUndoableAction: undo.present)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Notizen

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionLabel(title: "Notizen")

            TextEditor(text: $notesDraft)
                .scrollContentBackground(.hidden)
                .font(.system(size: 12.5))
                .foregroundStyle(AnkerColor.ink)
                .frame(minHeight: 96)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
                .background(AnkerColor.card)
                .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
                .onChange(of: notesDraft) { _, _ in scheduleCommit() }
                .accessibilityLabel("Notizen zum Tag")
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(AnkerColor.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(AnkerColor.card.opacity(0.6))
            .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.lineSoft, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
    }

    // MARK: - Aktionen

    private func dropTask(from providers: [NSItemProvider]) -> Bool {
        let targetDate = day.date

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
        focusDraft = day.focusNote ?? ""
        notesDraft = day.notes ?? ""
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

    private func commitDrafts() {
        guard hasLoadedDrafts else { return }

        let focus = normalized(focusDraft)
        let notes = normalized(notesDraft)
        var didChange = false

        if day.focusNote != focus {
            day.focusNote = focus
            didChange = true
        }

        if day.notes != notes {
            day.notes = notes
            didChange = true
        }

        if didChange {
            try? modelContext.save()
        }
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
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(block.startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AnkerColor.ink)
                Text(block.endTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(AnkerColor.muted)
            }
            .frame(width: 44, alignment: .leading)

            HStack {
                Text(block.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isAnchored {
                    Image(systemName: "calendar")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AnkerColor.indigoText)
                        .accessibilityLabel("Aus dem Kalender übernommen")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(AnkerColor.card)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(AnkerColor.line, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}
