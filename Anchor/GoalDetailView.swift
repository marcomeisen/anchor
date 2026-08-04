import SwiftData
import SwiftUI

struct GoalDetailView: View {
    let goal: Goal
    let week: Week
    var onDeleted: () -> Void = {}

    @State private var goalPendingDeletion: Goal?

    private var linkedTasks: [AnkerTask] {
        week.dayList.flatMap(\.taskList).filter { $0.linkedGoal?.id == goal.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ProgressRing(progress: goal.progress, color: Color(hex: goal.colorHex), lineWidth: 3.5)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("\(goal.title), \(Int(goal.progress * 100)) Prozent erreicht")
                    .accessibilityIdentifier("goalProgress")

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text("Wochenziel · \(AnkerDateFormat.calendarWeek(week.isoWeek)) · geplant seit \(AnkerDateFormat.weekdayShortWithDayMonth(week.monday))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AnkerColor.muted)
                }
                Spacer()

                Button(role: .destructive) {
                    goalPendingDeletion = goal
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AnkerColor.destructive)
                        .frame(width: 30, height: 30)
                        .background(AnkerColor.destructive.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("Wochenziel löschen")
                .accessibilityLabel("Wochenziel löschen")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .background(.regularMaterial)
            .overlay(alignment: .bottom) { Rectangle().fill(.white.opacity(0.22)).frame(height: 1) }

            HStack(spacing: 22) {
                DetailStat(value: linkedTasks.count, label: "Aufgaben")
                DetailStat(value: linkedTasks.filter(\.isDone).count, label: "Erledigt")
                DetailStat(value: activeDays, label: "Tage aktiv")
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AnkerColor.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(AnkerColor.lineSoft).frame(height: 1) }

            HStack(spacing: 6) {
                ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                    TimelineDayBar(day: day, goal: goal)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                        let dayTasks = day.taskList.filter { $0.linkedGoal?.id == goal.id }
                        if !dayTasks.isEmpty {
                            Text(AnkerDateFormat.weekdayLongWithDayMonthNumeric(day.date))
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(AnkerColor.muted)
                                .textCase(.uppercase)
                                .padding(.top, 12)
                                .padding(.bottom, 6)

                            ForEach(dayTasks.sorted { $0.order < $1.order }, id: \.id) { task in
                                TaskCard(task: task)
                                    .padding(.bottom, 7)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .background(AnkerColor.paper)
        .navigationTitle("Ziel")
        .goalDeleteConfirmation(goal: $goalPendingDeletion, week: week, onDeleted: onDeleted)
    }

    private var activeDays: Int {
        week.dayList.filter { day in
            day.taskList.contains { $0.linkedGoal?.id == goal.id }
        }.count
    }

}

private struct DetailStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AnkerColor.muted)
                .tracking(0.4)
        }
        // Zusammengefasst statt als zwei Einzeltexte: VoiceOver las bisher "1" und
        // "AUFGABEN" getrennt vor.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
        .accessibilityIdentifier("goalStat.\(label)")
    }
}

private struct TimelineDayBar: View {
    let day: Day
    let goal: Goal

    private var progress: Double {
        let tasks = day.taskList.filter { $0.linkedGoal?.id == goal.id }
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter(\.isDone).count) / Double(tasks.count)
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(AnkerDateFormat.weekdayShort(day.date))
                .font(.system(size: 9.5))
                .foregroundStyle(AnkerColor.muted)
            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color(hex: goal.colorHex))
                        .frame(height: proxy.size.height * progress)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AnkerColor.lineSoft)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 44)
        }
    }
}
