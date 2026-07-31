import SwiftData
import SwiftUI

struct TodayView: View {
    @Bindable var day: Day
    let week: Week
    var onAddTask: () -> Void

    private var tasks: [AnkerTask] {
        day.tasks.sorted { $0.order < $1.order }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    weekStrip

                    if let focus = day.focusNote ?? week.goals.first?.title {
                        GoalBanner(label: "Verankert an Wochenziel", title: focus)
                            .padding(.horizontal, AnkerSpacing.screenPadding)
                            .padding(.bottom, 14)
                    }

                    SectionLabel(title: "Zeitplan")
                        .padding(.horizontal, AnkerSpacing.screenPadding)

                    VStack(spacing: 0) {
                        ForEach(day.timeBlocks.sorted { $0.startTime < $1.startTime }, id: \.id) { block in
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
                                    TaskCard(task: task) {
                                        withAnimation(.snappy) {
                                            task.isDone.toggle()
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, AnkerSpacing.screenPadding)
                        }
                    }
                }
                .padding(.bottom, 96)
            }
            .background(AnkerColor.paper)

            Button(action: onAddTask) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(AnkerColor.indigo, in: Circle())
                    .shadow(color: AnkerColor.indigo.opacity(0.55), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 22)
            .padding(.bottom, 26)
            .accessibilityLabel("Neue Aufgabe")
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
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var weekStrip: some View {
        HStack {
            ForEach(week.days.sorted { $0.date < $1.date }, id: \.id) { item in
                WeekDot(
                    date: item.date,
                    isActive: AnkerCalendar.isSameDay(item.date, day.date),
                    hasGoal: item.tasks.contains { $0.linkedGoal != nil }
                )
                if item.id != week.days.sorted(by: { $0.date < $1.date }).last?.id {
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
