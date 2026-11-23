import SwiftData
import SwiftUI

#if os(macOS)
/// Schnellerfassung im Menüleisten-Popover: ein Titel, wahlweise ein Anker, fertig.
///
/// Das Popover beginnt **leer** und ohne Anker — eine stille Vorauswahl verankerte jede schnell
/// erfasste Aufgabe am ersten Anker, auch wenn sie dort nicht hingehört. Die Aufgabe landet auf
/// heute — oder auf dem Tag, den die Zeile am Ende nennt (`morgen`, `Fr`, `24.11.`, wie in der
/// Erfassungszeile). Liegt der in einer anderen Woche, bleibt sie ohne Anker. Woche und Tag
/// entstehen erst beim Sichern; das Öffnen ist noch kein Schreiben.
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
        WeekPlanning.week(startingAt: currentMonday, in: weeks)
    }

    private var currentMonday: Date {
        AnkerCalendar.weekInterval(containing: Date()).monday
    }

    private var anchors: [Goal] {
        currentWeek.map(GoalOrdering.anchors(in:)) ?? []
    }

    /// Die Zeile mit den Kürzeln der Erfassung. Ein getipptes `#n` geht vor dem gewählten Chip.
    private var input: CaptureInput {
        var input = CaptureSyntax.parse(title)
        if input.anchorNumber == nil, let index = anchors.firstIndex(where: { $0.id == selectedGoalID }) {
            input.anchorNumber = index + 1
        }
        return input
    }

    private var hint: String? {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let target = CaptureSyntax.resolve(input, weekStart: currentMonday, fallbackDate: Date())
        return CaptureSyntax.hint(raw: title, target: target, anchorCount: anchors.count)
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

            if let hint {
                Text(verbatim: hint)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .lineLimit(1)
                    .accessibilityIdentifier("quickCapture.hint")
            }

            Text("Anker")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)

            FlowLayout(spacing: AnkerSpacing.s2) {
                ForEach(Array(anchors.enumerated()), id: \.element.id) { index, goal in
                    CaptureChip(title: "\(index + 1) · \(goal.title)", isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.accentFill) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: String(localized: "Ohne Anker"), isSelected: selectedGoalID == nil, selectedColor: AnkerColor.accentFill) {
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
                    .disabled(input.isEmpty)
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
        guard !input.isEmpty else { return }
        guard TaskActions.create(
            input,
            weekStart: currentMonday,
            fallbackDate: Date(),
            weeks: weeks,
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
