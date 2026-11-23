import SwiftData
import SwiftUI

/// Heute: die vier Anker oben, darunter die Aufgaben dieses Tages, unten die Erfassungszeile.
///
/// Jeder Haken füllt sofort den Punkt bei seinem Anker — das ist der Zusammenhang, den die
/// App sichtbar machen soll: was ich heute tue, zahlt auf etwas ein, das diese Woche zählt.
struct TodayScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]
    @Query(filter: #Predicate<AnkerTask> { $0.day == nil && $0.linkedGoal == nil }, sort: \AnkerTask.order)
    private var inbox: [AnkerTask]

    @StateObject private var undo = TaskUndoCoordinator()
    @StateObject private var selection = TaskSelectionModel()

    var now: Date = Date()
    var onOpenAnchor: (Goal) -> Void
    var onStartWeek: () -> Void
    var onOpenWeek: () -> Void
    /// Öffnet den Rückblick der Woche, die mit diesem Montag beginnt.
    var onReview: (Date) -> Void

    private var sheet: WeekSheet {
        WeekSheet(monday: AnkerCalendar.weekInterval(containing: now).monday, weeks: weeks, inbox: inbox)
    }

    var body: some View {
        let sheet = sheet
        let today = sheet.tasks(on: now).sorted { !$0.isDone && $1.isDone }

        ScrollView {
            VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
                BlattHeading(
                    eyebrow: eyebrow(for: sheet),
                    title: "\(AnkerDateFormat.weekdayLong(now)), \(AnkerDateFormat.dayNumber(now))."
                )

                if sheet.anchorLanes.isEmpty {
                    startWeekCard
                } else {
                    BlattAnchorStrip(sheet: sheet, onSelect: onOpenAnchor, onAddAnchor: onStartWeek)
                }

                if let previous = unreviewedPreviousWeek {
                    reviewCard(
                        title: "Letzte Woche ist noch offen.",
                        detail: "\(AnkerDateFormat.calendarWeek(previous.isoWeek)) · pro Anker eine ehrliche Antwort.",
                        monday: previous.monday
                    )
                }

                if showsReviewPrompt(sheet) {
                    reviewCard(title: "Wie lief die Woche?", detail: "Pro Anker eine ehrliche Antwort.", monday: sheet.monday)
                }

                VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
                    HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s3) {
                        BlattSectionLabel(
                            title: "Heute",
                            trailing: today.isEmpty ? nil : "\(today.filter(\.isDone).count) von \(today.count)"
                        )
                        if !today.isEmpty {
                            BlattSelectButton(selection: selection)
                        }
                    }
                    if today.isEmpty {
                        BlattEmptyNote(text: "Für heute ist nichts geplant. Schreib unten, was ansteht — oder hol dir etwas aus der Woche.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(today.enumerated()), id: \.element.id) { index, task in
                                if index > 0 { AnkerRule(weight: .row) }
                                TaskCard(
                                    task: task,
                                    showPriority: false,
                                    metaLine: .none,
                                    showsAnchorNumber: true,
                                    isSelectionMode: selection.isActive,
                                    isSelected: selection.contains(task),
                                    onSelectionToggle: { selection.toggle(task) },
                                    onStartSelection: { withAnimation(.easeOut(duration: 0.15)) { selection.start(with: task) } },
                                    onUndoableAction: undo.present
                                )
                                .padding(.horizontal, AnkerSpacing.s3)
                            }
                        }
                        .ankerCard()
                    }
                }

                let unplanned = sheet.unplanned.count
                if unplanned > 0 {
                    Button(action: onOpenWeek) {
                        HStack {
                            Text("Noch ohne Tag")
                            Spacer()
                            Text(verbatim: "\(unplanned)").monospacedDigit()
                            Image(.chevronRight).ankerIcon(AnkerIconSize.xs)
                        }
                        .ankerType(AnkerType.label)
                        .foregroundStyle(AnkerColor.ink)
                        .padding(.horizontal, AnkerSpacing.s4)
                        .frame(minHeight: 48)
                        .ankerLooseArea()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.top, AnkerSpacing.s3)
            .padding(.bottom, AnkerSpacing.s6)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(AnkerColor.ground)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: AnkerSpacing.s2) {
                BlattUndoBar(coordinator: undo, weeks: weeks)
                if selection.isActive {
                    BlattBulkActionBar(
                        selection: selection,
                        tasks: today,
                        anchors: sheet.anchorLanes.compactMap(\.goal),
                        undo: undo
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    CaptureBar(week: sheet.week, weekStart: sheet.monday, fallbackDate: now)
                }
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(AnkerColor.ground)
            .animation(.easeOut(duration: 0.2), value: undo.notice?.id)
        }
    }

    private func eyebrow(for sheet: WeekSheet) -> String {
        let week = AnkerDateFormat.calendarWeek(sheet.isoWeek)
        guard let remaining = BlattDates.remainingDays(in: sheet, now: now) else { return week }
        switch remaining {
        case 0: return "\(week) · letzter Tag"
        case 1: return "\(week) · noch 1 Tag"
        default: return "\(week) · noch \(remaining) Tage"
        }
    }

    private func showsReviewPrompt(_ sheet: WeekSheet) -> Bool {
        guard let week = sheet.week, !week.isReviewed, !sheet.anchorLanes.isEmpty else { return false }
        return WeekActions.readiness(of: week, now: now).isArmed
    }

    private var startWeekCard: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s3) {
            Text("Was zählt diese Woche?")
                .ankerType(AnkerType.headline)
                .foregroundStyle(AnkerColor.ink)
            Text("Bis zu vier Anker, jeder mit einem Satz, warum. Aufgaben hängst du daran — oder lässt sie ohne.")
                .ankerType(AnkerType.body)
                .foregroundStyle(AnkerColor.inkSecond)
            Button("Woche setzen", action: onStartWeek)
                .buttonStyle(AnkerButtonStyle.primary)
        }
        .padding(AnkerSpacing.s4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .ankerCard()
    }

    /// Die Vorwoche, solange sie Anker hat und noch nicht geprüft ist. Wer am Sonntag nicht
    /// dazu kam, findet den Rückblick am Montag hier — nicht nur am Sonntag selbst.
    private var unreviewedPreviousWeek: WeekSheet? {
        let monday = AnkerCalendar.weekInterval(containing: now).monday
        guard let previousMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: -1, to: monday) else { return nil }
        let previous = WeekSheet(monday: previousMonday, weeks: weeks, inbox: [])
        guard let week = previous.week, !week.isReviewed, !previous.anchorLanes.isEmpty else { return nil }
        return previous
    }

    private func reviewCard(title: String, detail: String, monday: Date) -> some View {
        Button { onReview(monday) } label: {
            HStack {
                VStack(alignment: .leading, spacing: AnkerSpacing.s0) {
                    Text(verbatim: title)
                        .ankerType(AnkerType.bodyStrong)
                    Text(verbatim: detail)
                        .ankerType(AnkerType.meta)
                        .foregroundStyle(AnkerColor.inkSecond)
                }
                Spacer()
                Text("Rückblick")
                    .ankerType(AnkerType.label)
                    .foregroundStyle(AnkerColor.accentInk)
            }
            .foregroundStyle(AnkerColor.ink)
            .padding(AnkerSpacing.s4)
            .ankerCard(fill: AnkerColor.accentTint, elevated: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
