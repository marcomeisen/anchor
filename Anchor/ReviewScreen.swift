import SwiftData
import SwiftUI

/// Sonntag: Wie lief die Woche?
///
/// Pro Anker eine ehrliche Antwort — gehalten, teilweise, nicht. Die Zahl daneben ist ein
/// Hinweis, die Antwort gibt der Mensch: „1 von 2" kann trotzdem gehalten sein. Danach pro
/// offener Aufgabe: mitnehmen oder loslassen. Nichts wandert stillschweigend.
struct ReviewScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Week.monday) private var weeks: [Week]
    @Query(filter: #Predicate<AnkerTask> { $0.day == nil && $0.linkedGoal == nil }) private var inbox: [AnkerTask]

    let weekStart: Date
    var onClosed: () -> Void = {}

    @State private var dropped: Set<UUID> = []
    @State private var reflection = ""
    @State private var didLoad = false

    private var sheet: WeekSheet { WeekSheet(monday: weekStart, weeks: weeks, inbox: inbox) }

    var body: some View {
        let sheet = sheet
        let lanes = sheet.anchorLanes
        let open = lanes.flatMap(\.tasks).filter { !$0.isDone }
            + (sheet.week?.dayList.flatMap(\.taskList).filter { !$0.isDone && $0.linkedGoal == nil } ?? [])
        let answered = lanes.filter { $0.goal?.verdict != nil }.count
        let held = lanes.filter { $0.goal?.verdict == .held }.count
        let allAnswered = !lanes.isEmpty && answered == lanes.count

        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                BlattHeading(
                    eyebrow: "Rückblick · \(AnkerDateFormat.calendarWeek(sheet.isoWeek))",
                    title: allAnswered ? "\(held) von \(lanes.count) gehalten." : "Wie lief die Woche?",
                    titleStyle: AnkerType.title1
                )
                Text("Die Zahlen sind ein Hinweis. Die Antwort gibst du.")
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.inkSecond)

                VStack(spacing: 0) {
                    ForEach(Array(lanes.enumerated()), id: \.element.id) { index, lane in
                        if index > 0 { AnkerRule(weight: .row) }
                        if let goal = lane.goal {
                            verdictRow(lane: lane, goal: goal)
                        }
                    }
                }
                .ankerCard()

                if !open.isEmpty {
                    VStack(spacing: 0) {
                        BlattSectionLabel(title: "Offen geblieben")
                            .padding(.horizontal, AnkerSpacing.s3)
                            .padding(.top, AnkerSpacing.s3)
                            .padding(.bottom, AnkerSpacing.s2)
                        ForEach(open) { task in
                            AnkerRule(weight: .row)
                            carryRow(task, number: sheet.anchorNumber(of: task))
                        }
                    }
                    .ankerCard()
                }

                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    Text("Was hat diese Woche getragen?")
                        .ankerType(AnkerType.bodyStrong)
                        .foregroundStyle(AnkerColor.ink)
                    TextField("Ein Satz genügt", text: $reflection, axis: .vertical)
                        .textFieldStyle(.plain)
                        .ankerType(AnkerType.body)
                        .lineLimit(1...4)
                        .padding(AnkerSpacing.s3)
                        .ankerField()
                }

                Button("Woche abschließen") { close(open: open) }
                    .buttonStyle(AnkerButtonStyle.primaryBlock)
                    .disabled(!allAnswered)
                    .opacity(allAnswered ? 1 : 0.4)

                if let week = sheet.week, week.isReviewed {
                    Button("Woche wieder öffnen") {
                        WeekActions.reopen(week, modelContext: modelContext)
                    }
                    .buttonStyle(AnkerButtonStyle.quiet)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s4)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            reflection = sheet.week?.reflection ?? ""
        }
    }

    private func verdictRow(lane: WeekSheet.Lane, goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s2) {
                Text(verbatim: lane.numberLabel)
                    .ankerType(AnkerType.subheadline)
                    .monospacedDigit()
                    .frame(width: 22, alignment: .leading)
                Text(verbatim: lane.title)
                    .ankerType(AnkerType.bodyStrong)
                Spacer()
                Text(verbatim: "\(lane.doneCount) von \(lane.tasks.count)")
                    .ankerType(AnkerType.caption)
                    .monospacedDigit()
                    .foregroundStyle(AnkerColor.inkSecond)
            }
            .foregroundStyle(AnkerColor.ink)

            HStack(spacing: AnkerSpacing.s1 + 2) {
                ForEach(GoalVerdict.allCases) { verdict in
                    let isOn = goal.verdict == verdict
                    Button {
                        goal.verdict = isOn ? nil : verdict
                        modelContext.saveChanges()
                    } label: {
                        Text(verdict.label)
                            .ankerType(AnkerType.label)
                            .foregroundStyle(isOn ? AnkerColor.onAccent : AnkerColor.ink)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .ankerControl(fill: isOn ? AnkerColor.accentFill : AnkerColor.card, stroke: isOn ? nil : AnkerColor.divider)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                    .accessibilityLabel("\(lane.title): \(verdict.label)")
                }
            }
            .padding(.leading, AnkerSpacing.s5 + AnkerSpacing.s1h)
        }
        .padding(AnkerSpacing.s3)
    }

    private func carryRow(_ task: AnkerTask, number: Int?) -> some View {
        let keep = !dropped.contains(task.id)
        return HStack(spacing: AnkerSpacing.s2) {
            Text(verbatim: number.map(String.init) ?? "–")
                .ankerType(AnkerType.bodyStrong)
                .monospacedDigit()
                .foregroundStyle(number == nil ? AnkerColor.inkTertiary : AnkerColor.ink)
                .frame(width: 18)
            Text(verbatim: task.title)
                .ankerType(AnkerType.body)
                .foregroundStyle(keep ? AnkerColor.ink : AnkerColor.inkTertiary)
                .strikethrough(!keep)
            Spacer()
            Button(keep ? "Mitnehmen" : "Loslassen") {
                if keep { dropped.insert(task.id) } else { dropped.remove(task.id) }
            }
            .buttonStyle(keep ? AnkerButtonStyle.primary : AnkerButtonStyle.secondary)
            .accessibilityHint(keep ? "Antippen, um die Aufgabe loszulassen" : "Antippen, um sie mitzunehmen")
        }
        .padding(.horizontal, AnkerSpacing.s3)
        .padding(.vertical, AnkerSpacing.s2)
    }

    private func close(open: [AnkerTask]) {
        guard let week = sheet.week else { return }
        WeekActions.setReflection(reflection, in: week, modelContext: modelContext)

        // Aufgaben ohne Tag hängen nur über ihren Anker an dieser Woche. Mitgenommen gehen sie
        // in den Eingang — der Anker gehört zu dieser Woche und wandert nicht mit.
        for task in open where task.day == nil {
            if dropped.contains(task.id) {
                TaskActions.delete(task, modelContext: modelContext)
            } else {
                TaskActions.link(task, to: nil, modelContext: modelContext)
            }
        }

        var decisions: [UUID: WeekActions.CarryDecision] = [:]
        for task in open where task.day != nil {
            decisions[task.id] = dropped.contains(task.id) ? .drop : .keep
        }
        WeekActions.close(week, decisions: decisions, fallback: nil, weeks: weeks, modelContext: modelContext)
        onClosed()
        dismiss()
    }
}
