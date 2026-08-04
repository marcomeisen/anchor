import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct YearOverviewView: View {
    let week: Week
    let weeks: [Week]

    private var yearWeeks: [Week] {
        weeks
            .filter { $0.isoYear == week.isoYear }
            .sorted { $0.monday < $1.monday }
    }

    private var goals: [Goal] {
        yearWeeks.flatMap(\.goalList)
    }

    private var tasks: [AnkerTask] {
        yearWeeks.flatMap(\.dayList).flatMap(\.taskList)
    }

    private var activeGoalCount: Int {
        goals.filter { $0.progress < 1 }.count
    }

    private var completedTaskCount: Int {
        tasks.filter(\.isDone).count
    }

    private var totalWeeksInYear: Int {
        AnkerCalendar.weekInterval(containing: AnkerCalendar.date(year: week.isoYear, month: 12, day: 28)).isoWeek
    }

    private var headerSummary: String {
        guard !goals.isEmpty else {
            return "\(totalWeeksInYear) Wochen · keine Wochenziele"
        }

        return "\(totalWeeksInYear) Wochen · \(activeGoalCount) von \(goals.count) Wochenzielen aktiv"
    }

    private var monthColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 148, maximum: 220), spacing: 10, alignment: .top)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Jahresübersicht")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AnkerColor.muted)
                        .textCase(.uppercase)
                    Text("\(week.isoYear)")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text(headerSummary)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AnkerColor.muted)
                }

                HStack(spacing: 18) {
                    YearStat(value: "\(yearWeeks.count)", label: "geplante KW")
                    YearStat(value: "\(goals.count)", label: "Wochenziele")
                    YearStat(value: "\(completedTaskCount)/\(tasks.count)", label: "Tasks erledigt")
                }
                .padding(.vertical, 4)

                LazyVGrid(columns: monthColumns, alignment: .leading, spacing: 10) {
                    ForEach(monthSummaries) { summary in
                        YearMonthCard(
                            title: monthName(for: summary.month),
                            summary: summary,
                            accent: AnkerColor.month[(summary.month - 1) % AnkerColor.month.count],
                            isSelected: summary.month == AnkerCalendar.iso.component(.month, from: week.monday)
                        )
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
#if os(iOS)
            .padding(.bottom, 88)
#else
            .padding(.bottom, 24)
#endif
        }
        .background(AnkerColor.paper)
        .navigationTitle("Jahresübersicht")
    }

    private var monthSummaries: [YearMonthSummary] {
        (1...12).map { month in
            let monthWeeks = yearWeeks.filter { AnkerCalendar.iso.component(.month, from: $0.monday) == month }
            let monthGoals = monthWeeks.flatMap(\.goalList)
            let monthTasks = monthWeeks.flatMap(\.dayList).flatMap(\.taskList)
            return YearMonthSummary(
                month: month,
                weekCount: monthWeeks.count,
                goalCount: monthGoals.count,
                activeGoalCount: monthGoals.filter { $0.progress < 1 }.count,
                doneTaskCount: monthTasks.filter(\.isDone).count,
                taskCount: monthTasks.count
            )
        }
    }

    private func monthName(for month: Int) -> String {
        AnkerDateFormat.monthLong(AnkerCalendar.date(year: week.isoYear, month: month, day: 1))
    }
}

private struct YearMonthSummary: Identifiable {
    let month: Int
    let weekCount: Int
    let goalCount: Int
    let activeGoalCount: Int
    let doneTaskCount: Int
    let taskCount: Int

    var id: Int { month }

    var taskProgress: Double {
        guard taskCount > 0 else { return 0 }
        return Double(doneTaskCount) / Double(taskCount)
    }

    var hasContent: Bool {
        weekCount > 0 || goalCount > 0 || taskCount > 0
    }
}

private struct YearStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(AnkerColor.ink)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct YearMonthCard: View {
    let title: String
    let summary: YearMonthSummary
    let accent: Color
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                Text(title.capitalized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AnkerColor.ink)
                Spacer()
                Text(summary.weekCount > 0 ? "\(summary.weekCount) KW" : "—")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(AnkerColor.muted)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AnkerColor.lineSoft)
                    Capsule()
                        .fill(accent)
                        .frame(width: max(0, proxy.size.width * summary.taskProgress))
                }
            }
            .frame(height: 4)

            HStack(spacing: 12) {
                miniMetric(value: summary.goalCount == 0 ? "—" : "\(summary.activeGoalCount)/\(summary.goalCount)", label: "aktive Ziele")
                miniMetric(value: summary.taskCount == 0 ? "—" : "\(summary.doneTaskCount)/\(summary.taskCount)", label: "Tasks")
            }

            if !summary.hasContent {
                Text("Keine Planung")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AnkerColor.muted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(12)
        .background(AnkerColor.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AnkerColor.indigo.opacity(0.48) : AnkerColor.line, lineWidth: isSelected ? 1.5 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(summary.weekCount) Wochen, \(summary.goalCount) Wochenziele, \(summary.doneTaskCount) von \(summary.taskCount) Tasks erledigt")
    }

    private func miniMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AnkerColor.ink)
                .monospacedDigit()
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(AnkerColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
