import SwiftData
import SwiftUI

/// Die Erfassungszeile: tippen, Enter, fertig.
///
/// `Angebot prüfen #2 mi` — Anker und Wochentag als Kürzel, der Wochentag am Ende der Zeile.
/// Darunter steht der **aufgelöste** Stand, also wo die Aufgabe ohne weitere Angabe landet.
///
/// Die Woche darf fehlen: sie entsteht erst beim Sichern. Vorher legte schon das Anzeigen eine
/// Woche an — auf einem neuen Gerät vor dem iCloud-Import, also als Duplikat.
struct CaptureBar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let week: Week?
    let weekStart: Date
    let fallbackDate: Date
    var placeholder = String(localized: "Was steht an?  ·  #1–#4 Anker, mo–so Tag")
    var onCommitted: (AnkerTask) -> Void = { _ in }

    @State private var raw = ""
    @FocusState private var isFocused: Bool

    private var input: CaptureInput {
        CaptureSyntax.parse(raw)
    }

    private var target: CaptureTarget? {
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return CaptureSyntax.resolve(input, weekStart: weekStart, fallbackDate: fallbackDate)
    }

    private var hint: String? {
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let count = week.map { GoalOrdering.anchors(in: $0).count } ?? 0
        return CaptureSyntax.hint(raw: raw, target: target, anchorCount: count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            HStack(spacing: AnkerSpacing.s2) {
                TextField(placeholder, text: $raw)
                    .textFieldStyle(.plain)
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.ink)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .submitLabel(.done)
                    .accessibilityLabel("Aufgabe erfassen")
                    .accessibilityIdentifier("captureBar.field")

                Button(action: commit) {
                    Image(.add)
                        .ankerIcon(AnkerIconSize.m)
                        .foregroundStyle(AnkerColor.onInk)
                        .frame(width: 38, height: 38)
                        .background(AnkerColor.ink, in: RoundedRectangle(cornerRadius: AnkerRadius.inlineButton, style: .continuous))
                        .ankerTapTarget(38)
                }
                .buttonStyle(.plain)
                .disabled(input.isEmpty)
                .opacity(input.isEmpty ? 0.4 : 1)
                .accessibilityLabel("Aufgabe anlegen")
                .accessibilityIdentifier("captureBar.commit")
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.leading, AnkerSpacing.s4)
            .padding(.trailing, AnkerSpacing.s1)
            .frame(minHeight: 50)
            .ankerField(radius: AnkerRadius.bar)

            if let hint {
                Text(verbatim: hint)
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkSecond)
                    .lineLimit(1)
                    .padding(.horizontal, AnkerSpacing.s2)
                    .accessibilityIdentifier("captureBar.hint")
            }
        }
#if os(macOS)
        .onExitCommand { raw = ""; isFocused = false }
#endif
    }

    /// Der Fokus bleibt nach dem Anlegen stehen: wer eine Aufgabe erfasst, erfasst meist
    /// mehrere hintereinander.
    private func commit() {
        guard let task = TaskActions.create(
            input,
            weekStart: weekStart,
            fallbackDate: fallbackDate,
            weeks: weeks,
            modelContext: modelContext
        ) else { return }

        raw = ""
        onCommitted(task)
    }
}
