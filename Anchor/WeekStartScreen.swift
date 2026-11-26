import SwiftData
import SwiftUI

/// Montag: „Was zählt diese Woche?" — bis zu vier Anker, jeder mit einem Satz, warum.
///
/// Weniger als vier ist erlaubt, mehr nicht. Ein Anker, der letzte Woche nicht gehalten wurde,
/// wird zur Übernahme angeboten — die häufigste Planung ist „dasselbe noch einmal, ehrlicher".
struct WeekStartScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Week.monday) private var weeks: [Week]

    let weekStart: Date
    var onDone: () -> Void = {}

    @State private var drafts: [Draft] = []
    @State private var didLoad = false
    /// Bestehende Anker, die in diesem Blatt entfernt wurden — gelöscht wird erst beim Sichern.
    @State private var removedGoalIDs: Set<UUID> = []

    struct Draft: Identifiable {
        let id = UUID()
        /// Ein bestehender Anker, der bearbeitet wird; `nil` für einen neuen.
        var goalID: UUID?
        var title = ""
        var why = ""
    }

    private var interval: (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        AnkerCalendar.weekInterval(containing: weekStart)
    }

    private var week: Week? { WeekPlanning.week(startingAt: interval.monday, in: weeks) }

    /// Anker der Vorwoche, die nicht gehalten wurden — und noch nicht übernommen sind.
    private var suggestions: [Goal] {
        guard let previousMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: -1, to: interval.monday),
              let previous = WeekPlanning.week(startingAt: previousMonday, in: weeks) else { return [] }
        let taken = Set(drafts.map { $0.title.lowercased() })
        return GoalOrdering.anchors(in: previous).filter { goal in
            let notHeld = goal.verdict == .missed || goal.verdict == .partial
                || (goal.verdict == nil && goal.taskList.contains { !$0.isDone })
            return notHeld && !taken.contains(goal.title.lowercased())
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
#if os(macOS)
                HStack {
                    Spacer()
                    Button("Abbrechen") { dismiss() }
                        .buttonStyle(AnkerButtonStyle.quiet)
                        .keyboardShortcut(.cancelAction)
                }
#endif
                BlattHeading(
                    eyebrow: "\(AnkerDateFormat.calendarWeek(interval.isoWeek)) · \(AnkerDateFormat.weekSpan(monday: interval.monday, sunday: interval.sunday))",
                    title: String(localized: "Was zählt diese Woche?"),
                    titleStyle: AnkerType.title1
                )

                VStack(spacing: 0) {
                    ForEach($drafts) { $draft in
                        let index = drafts.firstIndex { $0.id == draft.id } ?? 0
                        if index > 0 { AnkerRule(weight: .row) }
                        draftRow(number: index + 1, draft: $draft) { remove(draft) }
                    }
                    if drafts.count < 4 {
                        if !drafts.isEmpty { AnkerRule(weight: .row) }
                        Button {
                            drafts.append(Draft())
                        } label: {
                            HStack(spacing: AnkerSpacing.s3) {
                                Text(verbatim: "\(drafts.count + 1)")
                                    .ankerType(AnkerType.anchorNumber)
                                    .foregroundStyle(AnkerColor.inkTertiary)
                                    .frame(width: 28, alignment: .leading)
                                Text(drafts.isEmpty ? String(localized: "Ersten Anker setzen") : String(localized: "Weiteren Anker setzen"))
                                    .ankerType(AnkerType.bodyStrong)
                                    .foregroundStyle(AnkerColor.inkSecond)
                                Spacer()
                            }
                            .padding(AnkerSpacing.s4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .ankerCard()

                if !removedGoalIDs.isEmpty {
                    Text(removedGoalIDs.count == 1
                         ? String(localized: "Ein Anker wird beim Beginnen entfernt. Seine Aufgaben bleiben, ohne Anker.")
                         : String(localized: "\(removedGoalIDs.count) Anker werden beim Beginnen entfernt. Ihre Aufgaben bleiben, ohne Anker."))
                        .ankerType(AnkerType.caption)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if !suggestions.isEmpty && drafts.count < 4 {
                    VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                        BlattSectionLabel(title: String(localized: "Letzte Woche nicht gehalten"))
                        ForEach(suggestions) { goal in
                            HStack(spacing: AnkerSpacing.s3) {
                                VStack(alignment: .leading, spacing: AnkerSpacing.s0) {
                                    Text(verbatim: goal.title).ankerType(AnkerType.bodyStrong)
                                    let open = goal.taskList.filter { !$0.isDone }.count
                                    Text("\(goal.taskList.filter(\.isDone).count) von \(goal.taskList.count) erledigt · \(open) offen")
                                        .ankerType(AnkerType.meta)
                                        .foregroundStyle(AnkerColor.inkSecond)
                                }
                                Spacer()
                                Button("Übernehmen") {
                                    drafts.append(Draft(title: goal.title, why: goal.why ?? ""))
                                }
                                .buttonStyle(AnkerButtonStyle.secondary)
                            }
                            .foregroundStyle(AnkerColor.ink)
                            .padding(AnkerSpacing.s4)
                            .ankerCard()
                        }
                    }
                }

                Text("Weniger als vier ist erlaubt. Mehr nicht.")
                    .ankerType(AnkerType.meta)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .frame(maxWidth: .infinity)

                Button("Woche beginnen", action: save)
                    .buttonStyle(AnkerButtonStyle.primaryBlock)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.4)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s4)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
#if os(iOS)
        .ankerSheetChrome("Anker setzen", cancel: AnkerSheetAction("Abbrechen") { dismiss() })
#endif
        .onAppear(perform: load)
    }

    private var hasAnyTitle: Bool {
        drafts.contains { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// Auch nur Entfernen ist eine Änderung, die gesichert werden will.
    private var canSave: Bool {
        hasAnyTitle || !removedGoalIDs.isEmpty
    }

    /// Ein Anker verschwand vorher nur, wenn man seinen Titel leerte — und auch dann nicht:
    /// der leere Titel wurde still verworfen. Jetzt hat jede Zeile ein Entfernen.
    private func remove(_ draft: Draft) {
        if let id = draft.goalID { removedGoalIDs.insert(id) }
        drafts.removeAll { $0.id == draft.id }
    }

    private func draftRow(number: Int, draft: Binding<Draft>, onRemove: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s3) {
            Text(verbatim: "\(number)")
                .ankerType(AnkerType.anchorNumber)
                .foregroundStyle(AnkerColor.ink)
                .frame(width: 28, alignment: .leading)
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                TextField("Titel des Ankers", text: draft.title)
                    .textFieldStyle(.plain)
                    .ankerType(AnkerType.subheadline)
                    .foregroundStyle(AnkerColor.ink)
                    .accessibilityLabel("Titel des \(number). Ankers")
                TextField("Warum zählt das diese Woche?", text: draft.why, axis: .vertical)
                    .textFieldStyle(.plain)
                    .ankerType(AnkerType.meta)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .lineLimit(1...3)
                    .accessibilityLabel("Warum zählt Anker \(number)?")
            }
            Spacer(minLength: AnkerSpacing.s2)
            Button(action: onRemove) {
                Image(AnkerIcon.clear)
                    .ankerIcon(AnkerIconSize.s)
                    .foregroundStyle(AnkerColor.inkTertiary)
                    .ankerTapTarget(16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Anker \(number) entfernen")
            .help(Text("Anker \(number) entfernen"))
        }
        .padding(AnkerSpacing.s4)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        if let week {
            drafts = GoalOrdering.anchors(in: week).map {
                Draft(goalID: $0.id, title: $0.title, why: $0.why ?? "")
            }
        }
        if drafts.isEmpty { drafts = [Draft()] }
    }

    /// Erst hier entsteht die Woche — beim Schreiben, nicht beim Anzeigen.
    private func save() {
        let week = TaskActions.ensureWeek(containing: interval.monday, weeks: weeks, modelContext: modelContext)
        // Erst löschen, dann anlegen: die Grenze von vier Ankern zählt die entfernten nicht mit.
        for goal in week.goalList where removedGoalIDs.contains(goal.id) {
            GoalActions.delete(goal, in: week, modelContext: modelContext)
        }
        for draft in drafts {
            // Anlegen und Ändern laufen über `GoalActions` — dort liegt die Grenze von vier Ankern.
            if let id = draft.goalID, let goal = week.goalList.first(where: { $0.id == id }) {
                GoalActions.update(goal, title: draft.title, why: draft.why, modelContext: modelContext)
            } else {
                GoalActions.create(title: draft.title, why: draft.why, in: week, modelContext: modelContext)
            }
        }
        onDone()
        dismiss()
    }
}
