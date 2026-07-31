import SwiftData
import SwiftUI

struct NewTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var day: Day
    let goals: [Goal]

    @State private var title = ""
    @State private var priority: Priority = .a
    @State private var selectedGoalID: UUID?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Was steht an?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AnkerColor.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))

                Text("Priorität".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)

                HStack(spacing: 6) {
                    ForEach(Priority.allCases, id: \.self) { item in
                        CaptureChip(title: item.label, isSelected: priority == item, selectedColor: PriorityTag(priority: item).color) {
                            priority = item
                        }
                    }
                }

                Text("Wochenziel verankern".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)
                    .padding(.top, 4)

                FlowLayout(spacing: 6) {
                    ForEach(goals.prefix(4), id: \.id) { goal in
                        CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.indigoBadge) {
                            selectedGoalID = goal.id
                        }
                    }
                    CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.indigoBadge) {
                        selectedGoalID = nil
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(AnkerColor.card)
            .navigationTitle("Schnell erfassen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let goal = goals.first { $0.id == selectedGoalID }
        let task = AnkerTask(
            title: cleanTitle,
            priority: priority,
            order: day.taskList.count,
            day: day,
            linkedGoal: goal
        )
        modelContext.insert(task)
        day.appendTask(task)
    }
}

#if os(macOS)
struct QuickCapturePopover: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    @State private var title = "Foliensatz für Steering-Meeting"
    @State private var priority: Priority = .a
    @State private var selectedGoalID: UUID?

    private var currentWeek: Week? {
        let today = Date()
        let sortedWeeks = weeks.sorted { $0.monday < $1.monday }
        return sortedWeeks.first(where: { week in
            (week.monday...week.sunday).contains(today)
        })
    }

    private var currentDay: Day? {
        currentWeek?.dayList.first { AnkerCalendar.isSameDay($0.date, Date()) }
            ?? currentWeek?.dayList.sorted { $0.date < $1.date }.first
    }

    private var goals: [Goal] {
        Array((currentWeek?.goalList ?? []).prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Schnell erfassen")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AnkerColor.ink)

            TextField("Was steht an?", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(AnkerColor.surface, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))

            Text("Priorität".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            HStack(spacing: 6) {
                ForEach(Priority.allCases, id: \.self) { item in
                    CaptureChip(title: item.label, isSelected: priority == item, selectedColor: PriorityTag(priority: item).color) {
                        priority = item
                    }
                }
            }

            Text("Wochenziel verankern".uppercased())
                .font(.system(size: 10.5, weight: .bold))
                .foregroundStyle(AnkerColor.muted)

            FlowLayout(spacing: 6) {
                ForEach(goals, id: \.id) { goal in
                    CaptureChip(title: goal.title, isSelected: selectedGoalID == goal.id, selectedColor: AnkerColor.indigoBadge) {
                        selectedGoalID = goal.id
                    }
                }
                CaptureChip(title: "Kein Ziel", isSelected: selectedGoalID == nil, selectedColor: AnkerColor.indigoBadge) {
                    selectedGoalID = nil
                }
            }

            HStack {
                Spacer()
                Button("Abbrechen") {
                    title = ""
                    selectedGoalID = nil
                }
                Button("Sichern") {
                    save()
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentDay == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .font(.system(size: 12, weight: .semibold))
            .padding(.top, 2)
        }
        .onAppear {
            selectedGoalID = selectedGoalID ?? goals.first?.id
        }
        .padding(16)
        .frame(width: 300)
        .background(.regularMaterial)
    }

    private func save() {
        guard let currentDay else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }

        let goal = goals.first { $0.id == selectedGoalID }
        let task = AnkerTask(
            title: cleanTitle,
            priority: priority,
            order: currentDay.taskList.count,
            day: currentDay,
            linkedGoal: goal
        )
        modelContext.insert(task)
        currentDay.appendTask(task)
        title = ""
        selectedGoalID = goals.first?.id
    }
}
#endif

struct NewGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var week: Week

    @State private var title = ""
    @State private var selectedColor = "#5B6EE8"

    private let colorOptions = ["#5B6EE8", "#C9974B", "#7FCDA8", "#8FA8E8", "#F0C955", "#F09EA9"]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 13) {
                TextField("Was ist dein Wochenziel?", text: $title)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AnkerColor.surfaceRaised)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AnkerColor.line))

                Text("Farbe".uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(AnkerColor.muted)

                HStack(spacing: 8) {
                    ForEach(colorOptions, id: \.self) { colorHex in
                        Button {
                            selectedColor = colorHex
                        } label: {
                            Circle()
                                .fill(Color(hex: colorHex))
                                .frame(width: 25, height: 25)
                                .overlay(Circle().stroke(selectedColor == colorHex ? AnkerColor.ink : AnkerColor.line, lineWidth: selectedColor == colorHex ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Zielfarbe")
                    }
                }

                Text("\(week.goalList.count)/4 Wochenziele")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(AnkerColor.muted)

                Spacer()
            }
            .padding(16)
            .background(AnkerColor.card)
            .navigationTitle("Neues Wochenziel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        save()
                        dismiss()
                    }
                    .disabled(cleanTitle.isEmpty || week.goalList.count >= 4)
                }
            }
        }
    }

    private var cleanTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !cleanTitle.isEmpty, week.goalList.count < 4 else { return }
        let goal = Goal(title: cleanTitle, colorHex: selectedColor, week: week)
        modelContext.insert(goal)
        week.appendGoal(goal)
        try? modelContext.save()
    }
}

private struct CaptureChip: View {
    let title: String
    let isSelected: Bool
    let selectedColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color(hex: "#4A4D5A", darkHex: "#D8D9E0"))
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? selectedColor : Color.clear)
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(isSelected ? selectedColor : AnkerColor.line))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
    }
}

struct WeeklyReviewView: View {
    let week: Week
    @State private var reflection = ""

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
                            Color(light: "#EEF0FF", dark: "#1C1D24"),
                            Color(light: "#EAF7EE", dark: "#23242D")
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
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.bottom, 28)
        }
        .background(AnkerColor.paper)
        .navigationTitle("Wochenrückblick")
    }
}

struct GoalDetailView: View {
    let goal: Goal
    let week: Week

    private var linkedTasks: [AnkerTask] {
        week.dayList.flatMap(\.taskList).filter { $0.linkedGoal?.id == goal.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ProgressRing(progress: goal.progress, color: Color(hex: goal.colorHex), lineWidth: 3.5)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("\(goal.title), \(Int(goal.progress * 100)) Prozent erreicht")

                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(AnkerColor.ink)
                    Text("Wochenziel · KW \(String(format: "%02d", week.isoWeek)) · verankert seit \(shortDate(week.monday))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(AnkerColor.muted)
                }
                Spacer()
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
                            Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide).day(.twoDigits).month(.twoDigits)))
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(AnkerColor.muted)
                                .textCase(.uppercase)
                                .padding(.top, 12)
                                .padding(.bottom, 6)

                            ForEach(dayTasks.sorted { $0.order < $1.order }, id: \.id) { task in
                                HStack(spacing: 9) {
                                    TaskCheckmark(isDone: task.isDone)
                                        .frame(width: 15, height: 15)
                                    Text(task.title)
                                        .font(.system(size: 12.5))
                                        .foregroundStyle(task.isDone ? AnkerColor.muted : AnkerColor.ink)
                                        .strikethrough(task.isDone, color: AnkerColor.muted)
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(AnkerColor.lineSoft).frame(height: 1)
                                }
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
    }

    private var activeDays: Int {
        week.dayList.filter { day in
            day.taskList.contains { $0.linkedGoal?.id == goal.id }
        }.count
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated).day(.twoDigits).month(.twoDigits))
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
            Text(day.date.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated)))
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

struct OnboardingView: View {
    let weekIntervalTitle: String
    var onCreateGoal: (String) -> Void

    @State private var goalTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            RoundedRectangle(cornerRadius: 22)
                .fill(LinearGradient(colors: [AnkerColor.indigo, AnkerColor.indigoDark], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 78, height: 78)
                .overlay(AnchorGlyph(stroke: .white).font(.system(size: 34)))
                .shadow(color: AnkerColor.indigo.opacity(0.45), radius: 15, x: 0, y: 8)
                .padding(.bottom, 26)

            Text("Verankere deine Woche")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AnkerColor.ink)
                .padding(.bottom, 10)

            Text(weekIntervalTitle)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(AnkerColor.indigoText)
                .padding(.bottom, 8)

            Text("Setze dein erstes Wochenziel. Jede Tagesaufgabe, die du erledigst, bleibt sichtbar mit ihrem Ziel verbunden.")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "#5A5D6A", darkHex: "#C4C6D0"))
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

            HStack(spacing: 6) {
                Capsule().fill(AnkerColor.indigo).frame(width: 16, height: 6)
                Circle().fill(AnkerColor.line).frame(width: 6, height: 6)
                Circle().fill(AnkerColor.line).frame(width: 6, height: 6)
            }
            .padding(.bottom, 22)

            Button {
                onCreateGoal(cleanGoalTitle)
            } label: {
                Text("Erstes Wochenziel setzen")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AnkerRadius.sheet))
                    .background(
                        LinearGradient(colors: [Color(hex: "#8C9BF5").opacity(0.95), AnkerColor.indigoText.opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: AnkerRadius.sheet)
                    )
                    .overlay(RoundedRectangle(cornerRadius: AnkerRadius.sheet).stroke(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: AnkerColor.indigoText.opacity(0.35), radius: 18, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(cleanGoalTitle.isEmpty)
            .opacity(cleanGoalTitle.isEmpty ? 0.58 : 1)

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(AnkerColor.paper)
    }

    private var cleanGoalTitle: String {
        goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
