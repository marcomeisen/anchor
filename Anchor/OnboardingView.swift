import SwiftData
import SwiftUI

struct OnboardingView: View {
    let weekIntervalTitle: String
    var onCreateGoal: (String) -> Void

    /// Zwei Schritte: erst die Sync-Entscheidung, dann das erste Wochenziel.
    ///
    /// Die Reihenfolge ist Absicht. Die Sync-Einstellung wirkt sich darauf aus, wohin die
    /// Daten gehen, und soll deshalb beantwortet sein, bevor die ersten entstehen. Wird der
    /// Sync hier abgeschaltet, greift das erst beim naechsten Start — dieser Prozess hat den
    /// Store bereits geoeffnet. Der Schritt sagt das ausdruecklich, statt es zu verschweigen.
    private enum Step {
        case cloudSync
        case goal
    }

    @State private var step: Step = CloudSyncPreference.hasBeenChosen() ? .goal : .cloudSync
    @State private var goalTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            RoundedRectangle(cornerRadius: 22)
                .fill(AnkerColor.surfaceRaised)
                .frame(width: 78, height: 78)
                .overlay(DaiventoLogo().padding(8))
                .shadow(color: AnkerColor.indigo.opacity(0.45), radius: 15, x: 0, y: 8)
                .padding(.bottom, 26)

            switch step {
            case .cloudSync:
                cloudSyncStep
            case .goal:
                goalStep
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(AnkerColor.paper)
    }

    // MARK: - Schritt 1: iCloud

    private var cloudSyncStep: some View {
        VStack(spacing: 0) {
            Text("Auf allen Geräten?")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
                .padding(.bottom, 10)

            Text("Daivento kann deine Wochen, Ziele, Aufgaben und Notizen über deinen iCloud-Account zwischen iPhone, iPad und Mac gleich halten. Die Daten liegen in deiner privaten iCloud-Datenbank; niemand sonst hat Zugriff darauf.")
                .font(.system(size: 13))
                .foregroundStyle(AnkerColor.textBody)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)

            stepIndicator(activeIndex: 0)
                .padding(.bottom, 22)

            primaryButton("Mit iCloud synchronisieren") {
                CloudSyncPreference.set(true)
                step = .goal
            }
            .padding(.bottom, 10)

            Button {
                CloudSyncPreference.set(false)
                step = .goal
            } label: {
                Text("Nur auf diesem Gerät")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnkerColor.indigoText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AnkerColor.surfaceRaised, in: RoundedRectangle(cornerRadius: AnkerRadius.sheet))
                    .overlay(RoundedRectangle(cornerRadius: AnkerRadius.sheet).stroke(AnkerColor.line))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ohne iCloud, nur auf diesem Gerät speichern")

            Text("Später jederzeit in den Einstellungen änderbar. Ein Wechsel greift beim nächsten Start.")
                .font(.system(size: 11))
                .foregroundStyle(AnkerColor.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)
        }
    }

    // MARK: - Schritt 2: erstes Wochenziel

    private var goalStep: some View {
        VStack(spacing: 0) {
            Text("Plane deine Woche")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
                .padding(.bottom, 10)

            Text(weekIntervalTitle)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AnkerColor.indigoText)
                .padding(.bottom, 8)

            Text("Setze dein erstes Wochenziel. Jede Tagesaufgabe, die du erledigst, bleibt sichtbar mit ihrem Ziel verbunden.")
                .font(.system(size: 13))
                .foregroundStyle(AnkerColor.textBody)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(.bottom, 18)

            TextField("Mein Wochenziel", text: $goalTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(AnkerColor.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(AnkerColor.surfaceRaised)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AnkerColor.line))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.bottom, 22)

            stepIndicator(activeIndex: 1)
                .padding(.bottom, 22)

            primaryButton("Erstes Wochenziel setzen") {
                onCreateGoal(cleanGoalTitle)
            }
            .disabled(cleanGoalTitle.isEmpty)
            .opacity(cleanGoalTitle.isEmpty ? 0.58 : 1)
        }
    }

    // MARK: - Bausteine

    private func stepIndicator(activeIndex: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { index in
                if index == activeIndex {
                    Capsule().fill(AnkerColor.indigo).frame(width: 16, height: 6)
                } else {
                    Circle().fill(AnkerColor.line).frame(width: 6, height: 6)
                }
            }
        }
        .accessibilityLabel("Schritt \(activeIndex + 1) von 2")
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AnkerRadius.sheet))
                .background(
                    LinearGradient(colors: [AnkerColor.indigoGradientSoft.opacity(0.95), AnkerColor.indigoText.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: AnkerRadius.sheet)
                )
                .overlay(RoundedRectangle(cornerRadius: AnkerRadius.sheet).stroke(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: AnkerColor.indigoText.opacity(0.35), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var cleanGoalTitle: String {
        goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
