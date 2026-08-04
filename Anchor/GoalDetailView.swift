import SwiftData
import SwiftUI

/// Ein Anker im Detail.
///
/// Der Fortschrittsring ist weg. Statt „70 % erreicht" steht hier ein Satz, der eine
/// Entscheidung verlangt — das ist der Unterschied zwischen einem Statusbildschirm und einem
/// Werkzeug. Der Prozentwert bleibt als Balken und als Vorlesetext erhalten.
struct GoalDetailView: View {
    @Environment(\.modelContext) private var modelContext

    /// `@Bindable`, nicht `let`: als einfache Konstante beobachtet die Ansicht die Aenderungen
    /// an der Woche nicht. Der Kennzahlenblock sprang dann erst beim Neuaufbau um — ein Haken
    /// in der Zielliste blieb ohne sichtbare Wirkung.
    @Bindable var goal: Goal
    @Bindable var week: Week
    var onDeleted: () -> Void = {}

    @State private var goalPendingDeletion: Goal?
    @StateObject private var undo = TaskUndoCoordinator()
    @Query(sort: \Week.monday) private var weeks: [Week]

    private var report: AnkerStatistics.AnchorReport? {
        AnkerStatistics.week(week).anchors.first { $0.id == goal.id }
    }

    private var linkedTasks: [AnkerTask] {
        week.dayList
            .sorted { $0.date < $1.date }
            .flatMap { $0.taskList.filter { $0.linkedGoal?.id == goal.id } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                statsRow
                paceNotice
                history
                taskList
            }
        }
        .background(AnkerColor.ground)
        .navigationTitle("Ziel")
        .safeAreaInset(edge: .bottom) {
            if let notice = undo.notice {
                TaskUndoToast(notice: notice) {
                    undo.undo(weeks: weeks, modelContext: modelContext)
                }
                .padding(AnkerSpacing.s3)
            }
        }
        .goalDeleteConfirmation(goal: $goalPendingDeletion, week: week, onDeleted: onDeleted)
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            HStack(alignment: .top) {
                Text(verbatim: kicker)
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.inkSecond)

                Spacer(minLength: AnkerSpacing.s4)

                Button(role: .destructive) {
                    goalPendingDeletion = goal
                } label: {
                    Image(.delete)
                        .ankerIcon(AnkerIconSize.s)
                        .foregroundStyle(AnkerColor.accentInk)
                        .padding(AnkerSpacing.s2)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Wochenziel löschen")
                .accessibilityLabel("Wochenziel löschen")
            }
            .padding(.top, AnkerSpacing.s4)

            Text(verbatim: goal.title)
                .ankerType(AnkerType.title2)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)

            AnkerProgressBar(
                progress: goal.progress,
                tint: AnkerColor.goalTint(goal.colorHex),
                thickness: AnkerBorder.rule * 4
            )
            .padding(.top, AnkerSpacing.s2)
            .padding(.bottom, AnkerSpacing.s4)
            // Der UI-Test haengt an dieser Kennung und am Wort „Prozent". Der Wert ist weiter
            // da, nur nicht mehr als Ring.
            .accessibilityIdentifier("goalProgress")
            .accessibilityLabel("\(goal.title), \(Int(goal.progress * 100)) Prozent erreicht")
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
    }

    private var kicker: String {
        let number = GoalOrdering.anchorNumber(of: goal, in: week)
        let anchor = number.map { "Anker \($0)" } ?? "Überzähliger Anker"
        return "\(anchor) · \(AnkerDateFormat.calendarWeek(week.isoWeek)) · gesetzt \(AnkerDateFormat.weekdayShortWithDayMonth(week.monday))"
    }

    // MARK: - Kennzahlen

    private var statsRow: some View {
        VStack(spacing: 0) {
            AnkerRule(color: AnkerColor.ink)

            HStack(spacing: 0) {
                DetailStat(
                    value: "\(report?.doneCount ?? 0)",
                    total: "\(report?.totalCount ?? 0)",
                    label: "Aufgaben"
                )
                AnkerRule(axis: .vertical)
                DetailStat(value: "\(report?.activeDays ?? 0)", label: "Tage aktiv")
                AnkerRule(axis: .vertical)
                DetailStat(
                    value: "\(report?.remainingDays ?? 0)",
                    label: "Tage Rest",
                    isEmphasized: (report?.remainingDays ?? 0) <= 2
                )
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
        }
    }

    // MARK: - Tempo

    /// Die Stelle, an der der Entwurf am deutlichsten wird: eine Prognose statt einer Zahl.
    @ViewBuilder
    private var paceNotice: some View {
        let forecast = AnkerStatistics.forecast(for: week)

        if forecast.kind != .empty {
            HStack(alignment: .top, spacing: AnkerSpacing.s4) {
                Text(verbatim: "Tempo")
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.accentInk)
                    .fixedSize()

                Text(verbatim: forecast.sentence)
                    .ankerType(AnkerType.subheadline)
                    .foregroundStyle(AnkerColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AnkerSpacing.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AnkerColor.accent[100],
                in: RoundedRectangle(cornerRadius: AnkerRadius.card, style: .continuous)
            )
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(AnkerColor.accentMark)
                    .frame(width: AnkerSpacing.s1)
            }
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card, style: .continuous))
            .padding(.top, AnkerSpacing.s4)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("goalPace")
        }
    }

    // MARK: - Verlauf

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Verlauf")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s5)
                .padding(.bottom, AnkerSpacing.s3)

            HStack(alignment: .bottom, spacing: AnkerSpacing.s2) {
                ForEach(week.dayList.sorted { $0.date < $1.date }, id: \.id) { day in
                    DayHistoryBar(day: day, goal: goal)
                }
            }
            .padding(.bottom, AnkerSpacing.s5)

            AnkerRule(color: AnkerColor.ink)
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
    }

    // MARK: - Aufgaben

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Aufgaben")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s4)
                .padding(.bottom, AnkerSpacing.s2)

            if linkedTasks.isEmpty {
                Text(verbatim: "Noch keine Aufgabe an diesem Anker.")
                    .ankerType(AnkerType.body)
                    .foregroundStyle(AnkerColor.inkTertiary)
                    .padding(.vertical, AnkerSpacing.s4)
            } else {
                // Dieselbe Zeile wie in der Tagesliste, nur mit dem **Tag** in der Metazeile: hier
                // haben alle Aufgaben denselben Anker. Vorher stand hier eine eigene Zeile mit
                // nichts als einem Kästchen — kein Kontextmenü, keine Prioritätsänderung, kein Weg
                // zum Titel.
                // Runde 3: die Liste sitzt in einer Karte, innen Hairlines. Eine 2px-Kante an
                // jeder Zeile liest sich wie ein Tabellengitter — die Kennzahlenreihe darueber
                // behaelt ihre 2px, sie ist Struktur.
                VStack(spacing: 0) {
                    ForEach(Array(linkedTasks.enumerated()), id: \.element.id) { index, task in
                        TaskCard(task: task, metaLine: .day, onUndoableAction: undo.present)
                        if index < linkedTasks.count - 1 {
                            AnkerRule(color: AnkerColor.cardDivider, weight: .row)
                        }
                    }
                }
                .padding(.horizontal, AnkerSpacing.s3)
                .ankerCard()
            }
        }
        .padding(.horizontal, AnkerSpacing.screenPadding)
        .padding(.bottom, AnkerSpacing.s6)
    }
}

/// Eine Kennzahl im Kopf. `total` macht daraus einen Bruch.
private struct DetailStat: View {
    let value: String
    var total: String?
    let label: String
    var isEmphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(verbatim: value)
                    .ankerType(AnkerType.statValue)
                    .foregroundStyle(isEmphasized ? AnkerColor.accentInk : AnkerColor.ink)
                if let total {
                    Text(verbatim: "/\(total)")
                        .ankerType(AnkerType.statValue)
                        .foregroundStyle(AnkerColor.inkTertiary)
                }
            }

            Text(verbatim: label)
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AnkerSpacing.s4)
        .padding(.trailing, AnkerSpacing.s3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(total.map { "\(value) von \($0) \(label)" } ?? "\(value) \(label)")
        .accessibilityIdentifier("goalStat.\(label)")
    }
}

/// Ein Tag im Verlauf: Höhe = Anteil erledigter Aufgaben dieses Ankers an diesem Tag.
private struct DayHistoryBar: View {
    let day: Day
    let goal: Goal

    private var own: [AnkerTask] {
        day.taskList.filter { $0.linkedGoal?.id == goal.id }
    }

    private var isToday: Bool {
        AnkerCalendar.isSameDay(day.date, Date())
    }

    var body: some View {
        VStack(spacing: AnkerSpacing.s2) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(AnkerColor.neutral[300])
                GeometryReader { proxy in
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Rectangle()
                            .fill(isToday ? AnkerColor.accentMark : AnkerColor.ink)
                            .frame(height: proxy.size.height * fill)
                    }
                }
            }
            .frame(height: 72)

            Text(verbatim: AnkerDateFormat.weekdayShort(day.date))
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(isToday ? AnkerColor.accentInk : AnkerColor.inkSecond)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AnkerDateFormat.weekdayLong(day.date)), \(own.filter(\.isDone).count) von \(own.count) erledigt")
    }

    private var fill: Double {
        own.isEmpty ? 0 : Double(own.filter(\.isDone).count) / Double(own.count)
    }
}
