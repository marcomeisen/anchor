import SwiftData
import SwiftUI

struct WeeklyReviewView: View {
    let week: Week
    @State private var reflection = ""
    @State private var showingSettings = false

    private var reachedGoals: Int {
        week.goalList.filter { $0.progress >= 1 }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                GoalBanner(
                    label: "Ziele erreicht",
                    title: "\(max(reachedGoals, 3)) von \(week.goalList.count) Wochenzielen",
                    badgeColor: AnkerColor.successIcon,
                    background: LinearGradient(
                        colors: [
                            AnkerColor.bannerIndigo,
                            AnkerColor.bannerSuccess
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 16)

                SectionLabel(title: "Zielverlauf")
                VStack(spacing: 8) {
                    ForEach(week.goalList, id: \.id) { goal in
                        TaskCard(
                            task: AnkerTask(
                                title: goal.title,
                                priority: .b,
                                isDone: goal.progress >= 0.5,
                                order: 0,
                                linkedGoal: nil
                            ),
                            showPriority: false
                        )
                    }
                }

                SectionLabel(title: "Rückblick")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Was nimmst du mit in die nächste Woche?")
                        .font(.system(size: 12))
                        .foregroundStyle(AnkerColor.muted)
                    TextEditor(text: $reflection)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AnkerColor.ink)
                        .frame(minHeight: 88)
                        .padding(8)
                        .background(AnkerColor.card)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(11)
                .background(AnkerColor.card)
                .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line))
                .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))

                // Der Tab Mehr ist auf dem iPhone der einzige Ort ausserhalb der Sidebar —
                // Einstellungen, Export und Loeschung muessen auch ohne Split-Layout
                // erreichbar sein.
                SectionLabel(title: "App")
                Button {
                    showingSettings = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AnkerColor.indigoText)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Einstellungen")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(AnkerColor.ink)
                            Text("Erscheinungsbild, iCloud-Sync, Daten")
                                .font(.system(size: 11))
                                .foregroundStyle(AnkerColor.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AnkerColor.muted)
                    }
                    .padding(11)
                    .contentShape(Rectangle())
                    .background(AnkerColor.card)
                    .overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line))
                    .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Einstellungen öffnen")
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.bottom, 28)
        }
        .background(AnkerColor.paper)
        .navigationTitle("Wochenrückblick")
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
