import SwiftData
import SwiftUI

/// Die feste Erfassungszeile des Entwurfs: tippen, Enter, fertig.
///
/// Ersetzt den Weg „Knopf drücken, Blatt öffnet, vier Felder ausfüllen, sichern" für den
/// Alltagsfall. Das Blatt bleibt für den Fall, dass jemand Woche und Tag wirklich aussuchen
/// will — die Zeile ist der schnelle Weg, nicht der einzige.
///
/// Die Hinweiszeile darunter zeigt den **aufgelösten** Stand vor dem Anlegen. Das ist der Grund,
/// warum die Mehrdeutigkeit von „so" (Wochentag oder Wort) tragbar ist: man sieht es vorher.
struct CaptureBar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    /// Die angezeigte Woche — ein Wochentagskürzel bezieht sich auf sie.
    let week: Week
    /// Der gewählte Tag, wenn kein Wochentagskürzel getippt wurde.
    let fallbackDate: Date
    var onCommitted: (AnkerTask) -> Void = { _ in }

    @State private var raw = ""
    @FocusState private var isFocused: Bool

    private var input: CaptureInput {
        CaptureSyntax.parse(raw)
    }

    private var target: CaptureTarget? {
        guard !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return CaptureSyntax.resolve(input, weekStart: week.monday, fallbackDate: fallbackDate)
    }

    private var hint: String {
        CaptureSyntax.hint(raw: raw, target: target, anchorCount: GoalOrdering.anchors(in: week).count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Der Kopf des Fussblocks: 2px in **Tinte**, nicht in der Trennlinienfarbe. Die
            // Vorlage setzt hier dieselbe Kante wie unter der Datumszeile oben.
            AnkerRule(color: AnkerColor.ink)

            HStack(spacing: AnkerSpacing.s3) {
                // Feld und Knopf sind Objekte: gerundet. Die 2px-Kante der Leiste darueber ist
                // Struktur und bleibt scharf.
                HStack(spacing: AnkerSpacing.s2) {
                    Text(verbatim: "+")
                        .ankerType(AnkerType.headline)
                        .foregroundStyle(AnkerColor.ink)
                        .accessibilityHidden(true)

                    TextField("Was steht an?  !a  #2", text: $raw)
                        .textFieldStyle(.plain)
                        .ankerType(AnkerType.body)
                        .foregroundStyle(AnkerColor.ink)
                        .focused($isFocused)
                        .onSubmit(commit)
                        .accessibilityLabel("Aufgabe erfassen")
                        .accessibilityIdentifier("captureBar.field")
                }
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s3)
                .ankerField()

                Button("Sichern", action: commit)
                    .buttonStyle(AnkerButtonStyle.primary)
                    .disabled(input.isEmpty)
                    .opacity(input.isEmpty ? 0.45 : 1)
                    .accessibilityIdentifier("captureBar.commit")
            }
            .padding(.horizontal, AnkerSpacing.s4)
            .padding(.top, AnkerSpacing.s3)

            Text(verbatim: hint)
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .lineLimit(1)
                .padding(.horizontal, AnkerSpacing.s4)
                .padding(.top, AnkerSpacing.s1)
                .padding(.bottom, AnkerSpacing.s3)
                .accessibilityIdentifier("captureBar.hint")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Die Vorlage setzt den ganzen Fussblock auf den Grund und trennt ihn allein mit der
        // 2px-Kante daruber — nicht zusaetzlich mit einer eigenen Flaeche.
        .background(AnkerColor.ground)
#if os(macOS)
        // Auf dem Mac ist die Zeile der Fuss der Matrix und per Tastatur erreichbar.
        .onExitCommand { raw = ""; isFocused = false }
#endif
    }

    /// Der Fokus bleibt nach dem Anlegen stehen: wer eine Aufgabe erfasst, erfasst meist
    /// mehrere hintereinander.
    private func commit() {
        guard let task = TaskActions.create(
            input,
            weekStart: week.monday,
            fallbackDate: fallbackDate,
            weeks: weeks,
            modelContext: modelContext
        ) else { return }

        raw = ""
        onCommitted(task)
    }
}
