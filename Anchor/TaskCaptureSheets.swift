import SwiftData
import SwiftUI

#if os(macOS)
/// Schnellerfassung im Menüleisten-Popover: ein Titel, wahlweise ein Anker, fertig.
///
/// Das Popover beginnt **leer** und ohne Anker — eine stille Vorauswahl verankerte jede schnell
/// erfasste Aufgabe am ersten Anker, auch wenn sie dort nicht hingehört. Die Aufgabe landet auf
/// heute. Woche und Tag entstehen erst beim Sichern; das Öffnen ist noch kein Schreiben.
///
/// `onClose` schließt das Popover. `@Environment(\.dismiss)` greift in einem `NSPopover`
/// nicht, deshalb reicht der Besitzer des Popovers den Weg herein.
struct QuickCapturePopover: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    var onClose: () -> Void = {}

    @State private var title = ""
    @State private var selectedGoalID: UUID?
    @FocusState private var isTitleFocused: Bool

    /// Nur nachsehen, nicht anlegen — über ISO-Jahr und -Woche, nie über `monday`.
    private var currentWeek: Week? {
        WeekPlanning.week(startingAt: AnkerCalendar.weekInterval(containing: Date()).monday, in: weeks)
    }

    private var anchors: [Goal] {
        currentWeek.map(GoalOrdering.anchors(in:)) ?? []
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Schnell erfassen")
                .ankerType(AnkerType.metaStrong)
                .foregroundStyle(AnkerColor.ink)

            TextField("Was steht an?", text: $title)
                .textFieldStyle(.plain)
                .ankerType(AnkerType.body)
                .focused($isTitleFocused)
                .onSubmit(save)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s2)
                .ankerField()
                .accessibilityIdentifier("quickCapture.title")

            Text("Anker")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            FlowLayout(spacing: AnkerSpacing.s2) {
                ForEach(Array(anchors.enumerated()), id: \.element.id) { index, goal in
                    CaptureChip(title: "\(index + 1) · \(goal.title)", isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.accentFill) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: "Ohne Anker", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.accentFill) {
                    selectedGoalID = nil
                }
            }

            HStack(spacing: AnkerSpacing.s2) {
                Spacer()
                Button("Abbrechen", action: close)
                    .buttonStyle(AnkerButtonStyle.secondary)
                    .keyboardShortcut(.cancelAction)
                Button("Sichern", action: save)
                    .buttonStyle(AnkerButtonStyle.primary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(cleanTitle.isEmpty)
            }
            .padding(.top, AnkerSpacing.s1)
        }
        .padding(AnkerSpacing.s4)
        .frame(width: 300)
        .background(AnkerColor.surface)
        .tint(AnkerColor.accentMark)
        .onExitCommand(perform: close)
        .task {
            // Wie in `TaskTitleField`: der Fokus greift erst nach einem Durchlauf.
            await Task.yield()
            isTitleFocused = true
        }
    }

    private func close() {
        title = ""
        selectedGoalID = nil
        onClose()
    }

    private func save() {
        guard !cleanTitle.isEmpty else { return }
        let week = TaskActions.ensureWeek(containing: Date(), weeks: weeks, modelContext: modelContext)
        let today = TaskActions.ensureDay(containing: Date(), in: week)
        let goal = GoalOrdering.anchors(in: week).first { $0.id == selectedGoalID }
        guard TaskActions.create(
            title: cleanTitle,
            priority: CaptureSyntax.defaultPriority,
            on: today,
            linkedGoal: goal,
            modelContext: modelContext
        ) != nil else { return }

        close()
    }
}
#endif

struct CaptureChip: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .ankerType(AnkerType.caption)
                .foregroundStyle(isSelected ? AnkerColor.onAccent : AnkerColor.inkSecond)
                .lineLimit(1)
                .padding(.horizontal, AnkerSpacing.s2)
                .padding(.vertical, AnkerSpacing.s1)
                .ankerControl(
                    fill: isSelected ? selectedColor : Color.clear,
                    stroke: isSelected ? nil : AnkerColor.divider,
                    radius: AnkerRadius.tile
                )
        }
        .buttonStyle(.plain)
    }
}
