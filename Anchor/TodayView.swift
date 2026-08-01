import SwiftData
import SwiftUI

struct TodayView: View {
    @Bindable var day: Day
    let week: Week
    var onAddTask: () -> Void

    private var tasks: [AnkerTask] {
        day.taskList.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    weekStrip

                    if let focus = day.focusNote ?? week.goalList.first?.title {
                        GoalBanner(label: "Verankert an Wochenziel", title: focus)
                            .padding(.horizontal, AnkerSpacing.screenPadding)
                            .padding(.bottom, 14)
                    }

                    SectionLabel(title: "Zeitplan")
                        .padding(.horizontal, AnkerSpacing.screenPadding)

                    VStack(spacing: 0) {
                        ForEach(day.timeBlockList.sorted { $0.startTime < $1.startTime }, id: \.id) { block in
                            TimeBlockRow(block: block, isAnchored: block.linkedEventIdentifier != nil)
                        }
                    }
                    .padding(.horizontal, AnkerSpacing.screenPadding)

                    ForEach(Priority.allCases, id: \.self) { priority in
                        let priorityTasks = tasks.filter { $0.priority == priority }
                        if !priorityTasks.isEmpty {
                            SectionLabel(title: "Prio \(priority.label)")
                                .padding(.horizontal, AnkerSpacing.screenPadding)

                            VStack(spacing: 8) {
                                ForEach(priorityTasks, id: \.id) { task in
                                    TaskCard(task: task)
                                }
                            }
                            .padding(.horizontal, AnkerSpacing.screenPadding)
                        }
                    }
                }
                .padding(.bottom, 96)
            }
            .background(AnkerColor.paper)

            GlassFAB(action: onAddTask)
            .padding(.trailing, 22)
            .padding(.bottom, 86)
        }
        .navigationTitle("Heute")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(headerDate)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AnkerColor.muted)
                .tracking(0.35)
            Text("Heute")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 13)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var weekStrip: some View {
        HStack {
            ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { item in
                WeekDot(
                    date: item.date,
                    isActive: AnkerCalendar.isSameDay(item.date, day.date),
                    hasGoal: item.taskList.contains { $0.linkedGoal != nil }
                )
                if item.id != week.dayList.sorted(by: { $0.date < $1.date }).last?.id {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.vertical, 6)
        .padding(.bottom, 8)
    }

    private var headerDate: String {
        let weekday = day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide)).uppercased()
        let date = day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day(.twoDigits).month(.twoDigits).year())
        return "\(weekday) · \(date) · KW \(String(format: "%02d", week.isoWeek))"
    }
}

private struct TimeBlockRow: View {
    let block: TimeBlock
    let isAnchored: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(block.startTime.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(AnkerColor.muted)
                .frame(width: 38, alignment: .leading)

            HStack {
                Text(block.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AnkerColor.ink)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if isAnchored {
                    Circle()
                        .fill(AnkerColor.indigo)
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AnkerColor.card)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(AnkerColor.line, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(AnkerColor.lineSoft)
                .frame(height: 1)
        }
    }
}
