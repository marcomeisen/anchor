import SwiftData
import SwiftUI

/// Onboarding: setzen statt lesen.
///
/// Der Bestand erklärte das Konzept in vier Zeilen Prosa, bevor der Nutzer etwas gesehen hatte.
/// Hier setzt er seine echten Anker — **das Konzept erklärt sich dadurch, dass die Liste bei
/// vier aufhört**. Genau so begründet es der Entwurf.
///
/// Zwei Schritte, und die Reihenfolge ist Absicht: die Sync-Einstellung wirkt sich darauf aus,
/// wohin die Daten gehen, und soll beantwortet sein, bevor die ersten entstehen. Wird der Sync
/// hier abgeschaltet, greift das erst beim nächsten Start — dieser Prozess hat den Store schon
/// geöffnet. Der Schritt sagt das ausdrücklich, statt es zu verschweigen.
struct OnboardingView: View {
    let weekIntervalTitle: String
    /// Läuft der iCloud-Erstimport noch, könnte also Bestand nachliefern?
    ///
    /// Solange das gilt, wird **nicht** nach Ankern gefragt. Sonst legt ein neu installiertes
    /// Gerät vier frische Anker an, während der eigene Bestand noch unterwegs ist — und danach
    /// stehen acht in der Woche. Genau das war der gemeldete Fehler.
    var isAwaitingFirstSync = false
    /// Bis zu vier Titel in der Reihenfolge, in der sie eingegeben wurden.
    var onCreateAnchors: ([String]) -> Void
    /// Ohne Anker weiter. Muss es geben: ein Einrichtungsschritt, aus dem man nicht heraus
    /// kommt, ist eine Falle — und wer schon Daten hat, will hier gar nichts eingeben.
    var onSkip: () -> Void = {}

    private enum Step {
        case cloudSync
        case anchors
    }

    private static let anchorSlots = 4
    /// Wie lange auf den iCloud-Erstimport gewartet wird, bevor der Ankerschritt trotzdem kommt.
    private static let syncWaitLimit = 8.0

    @State private var step: Step = CloudSyncPreference.hasBeenChosen() ? .anchors : .cloudSync
    @State private var titles = Array(repeating: "", count: Self.anchorSlots)
    @State private var isAwaitingFirstSyncOverridden = false
    @FocusState private var focusedSlot: Int?

    private var cleanTitles: [String] {
        titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .cloudSync:
                cloudSyncStep
            case .anchors:
                if isAwaitingFirstSync && !isAwaitingFirstSyncOverridden {
                    syncWaitStep
                } else {
                    anchorStep
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, AnkerSpacing.s5)
        .background(AnkerColor.ground)
    }

    // MARK: - Schritt 1: iCloud

    private var cloudSyncStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepIndicator(activeIndex: 0)

            Text(verbatim: "Schritt 1 von 2")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s5)
                .padding(.bottom, AnkerSpacing.s3)

            Text(verbatim: "Auf allen Geräten?")
                .ankerType(AnkerType.title2)
                .foregroundStyle(AnkerColor.ink)

            Text(verbatim: "Daivento kann deine Wochen, Ziele, Aufgaben und Notizen über deinen iCloud-Account zwischen iPhone, iPad und Mac gleich halten. Die Daten liegen in deiner privaten iCloud-Datenbank; niemand sonst hat Zugriff darauf.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AnkerSpacing.s3)

            Spacer(minLength: AnkerSpacing.s5)

            Button("Mit iCloud synchronisieren") {
                CloudSyncPreference.set(true)
                step = .anchors
            }
            .buttonStyle(AnkerButtonStyle.primaryBlock)

            Button("Nur auf diesem Gerät") {
                CloudSyncPreference.set(false)
                step = .anchors
            }
            .buttonStyle(AnkerButtonStyle.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AnkerSpacing.s2)
            .accessibilityLabel("Ohne iCloud, nur auf diesem Gerät speichern")

            Text(verbatim: "Später jederzeit in den Einstellungen änderbar. Ein Wechsel greift beim nächsten Start.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AnkerSpacing.s3)
                .padding(.bottom, AnkerSpacing.s5)
        }
    }

    // MARK: - Warten auf den Erstimport

    /// Statt der Ankerfrage: ein ehrlicher Zwischenschritt.
    ///
    /// Der Ausweg daneben ist Absicht. Ein Konto ohne Netz oder mit abgeschaltetem iCloud würde
    /// hier sonst dauerhaft hängen.
    private var syncWaitStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepIndicator(activeIndex: 1)

            Text(verbatim: "Schritt 2 von 2")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s5)
                .padding(.bottom, AnkerSpacing.s3)

            Text(verbatim: "iCloud holt deine Wochen")
                .ankerType(AnkerType.title2)
                .foregroundStyle(AnkerColor.ink)

            Text(verbatim: "Auf diesem Gerät ist noch nichts gespeichert. Wenn du Daivento schon benutzt, kommen deine Anker und Aufgaben gleich von selbst — dann brauchst du hier nichts einzugeben.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AnkerSpacing.s3)

            ProgressView()
                .padding(.top, AnkerSpacing.s5)
                // Frist statt Dauerspinner: bleibt die Sync-Phase hängen — kein Netz, ein Konto
                // ohne iCloud-Freigabe — führt der Schritt von selbst weiter. Ohne das starrt
                // ein wirklich neuer Nutzer auf einen Fortschrittsbalken, der nie endet.
                .task {
                    try? await Task.sleep(for: .seconds(Self.syncWaitLimit))
                    isAwaitingFirstSyncOverridden = true
                }

            Spacer(minLength: AnkerSpacing.s5)

            Button("Trotzdem jetzt einrichten") {
                // Ausdrücklich: wer das drückt, hat auf diesem Gerät noch nie Daten gehabt oder
                // will nicht warten. Der Bestand wird beim Anlegen erneut geprüft.
                isAwaitingFirstSyncOverridden = true
            }
            .buttonStyle(AnkerButtonStyle.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("onboardingSkipWait")

            Button("Später einrichten", action: onSkip)
                .buttonStyle(AnkerButtonStyle.quiet)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AnkerSpacing.s2)
                .padding(.bottom, AnkerSpacing.s5)
                .accessibilityIdentifier("onboardingSkip")
        }
    }

    // MARK: - Schritt 2: die Anker

    private var anchorStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepIndicator(activeIndex: 1)

            Text(verbatim: "Schritt 2 von 2 · \(weekIntervalTitle)")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s5)
                .padding(.bottom, AnkerSpacing.s3)

            Text(verbatim: "Was zählt diese Woche?")
                .ankerType(AnkerType.title2)
                .foregroundStyle(AnkerColor.ink)

            Text(verbatim: "Bis zu vier. Mehr geht nicht — das ist der Punkt.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s3)
                .padding(.bottom, AnkerSpacing.s5)

            AnkerRule(color: AnkerColor.ink)

            ForEach(0..<Self.anchorSlots, id: \.self) { slot in
                anchorField(slot)
                AnkerRule(weight: .row)
            }

            Spacer(minLength: AnkerSpacing.s5)

            Text(verbatim: "Zwei reichen für den Start. Der Rest kommt, wenn du ihn brauchst.")
                .ankerType(AnkerType.caption)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s3)

            Button(action: commit) {
                Text(verbatim: "Weiter · Woche aufteilen")
            }
            .buttonStyle(AnkerButtonStyle.primaryBlock)
            .disabled(cleanTitles.isEmpty)
            .opacity(cleanTitles.isEmpty ? 0.45 : 1)
            .accessibilityIdentifier("onboardingCommit")

            Button("Später einrichten", action: onSkip)
                .buttonStyle(AnkerButtonStyle.quiet)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, AnkerSpacing.s2)
                .padding(.bottom, AnkerSpacing.s5)
                .accessibilityIdentifier("onboardingSkip")
        }
    }

    private func anchorField(_ slot: Int) -> some View {
        HStack(spacing: AnkerSpacing.s3) {
            Text(verbatim: String(slot + 1))
                .ankerType(AnkerType.numeric)
                .foregroundStyle(isFilled(slot) ? AnkerColor.ink : AnkerColor.inkTertiary)
                .frame(width: 20, alignment: .leading)

            TextField(placeholder(slot), text: $titles[slot])
                .textFieldStyle(.plain)
                .ankerType(AnkerType.subheadline)
                .foregroundStyle(AnkerColor.ink)
                .focused($focusedSlot, equals: slot)
                .onSubmit {
                    // Enter springt in das naechste Feld — vier Anker in einem Fluss eingeben.
                    focusedSlot = slot + 1 < Self.anchorSlots ? slot + 1 : nil
                }
                .accessibilityIdentifier("anchorField.\(slot + 1)")
        }
        .padding(.vertical, AnkerSpacing.s4)
        .frame(minHeight: 52)
    }

    private func isFilled(_ slot: Int) -> Bool {
        !titles[slot].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Die Platzhalter erzählen dasselbe wie die Prosa, die hier stand — nur beim Tun.
    private func placeholder(_ slot: Int) -> String {
        switch slot {
        case 0: "Dein erster Anker"
        case 1: "Zweiter Anker"
        case 2: "Dritter Anker …"
        default: "Optional"
        }
    }

    // MARK: - Bausteine

    private func stepIndicator(activeIndex: Int) -> some View {
        HStack(spacing: AnkerSpacing.s1) {
            ForEach(0..<2, id: \.self) { index in
                Rectangle()
                    .fill(index == activeIndex ? AnkerColor.accentMark : AnkerColor.neutral[300])
                    .frame(width: index == activeIndex ? 64 : 32, height: AnkerBorder.heavy)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, AnkerSpacing.s6)
        .accessibilityLabel("Schritt \(activeIndex + 1) von 2")
    }

    private func commit() {
        let anchors = cleanTitles
        guard !anchors.isEmpty else { return }
        onCreateAnchors(anchors)
    }
}
