import SwiftData
import SwiftUI

/// Die Seitenleiste auf Mac und iPad: **nur Zeit.**
///
/// Eine Liste von Wochen um die laufende herum, jede mit ihren sieben Tagesquadraten. Ein Klick
/// öffnet die Woche, und eine gezogene Aufgabe lässt sich auf eine Woche ablegen — sie landet am
/// selben Wochentag dort. Kein Ansichtswechsel, keine Ankerliste: das steht im Inhalt.
struct BlattSidebar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]
    @ObservedObject var cloudSyncStatus: CloudSyncStatusCenter = .shared
    @StateObject private var undo = TaskUndoCoordinator()

    let selectedWeekStart: Date
    var now: Date = Date()
    var onSelectWeek: (Date) -> Void
    var onToday: () -> Void
    var onArchive: () -> Void

    @State private var targetedWeek: Date?

    private var rows: [SidebarTimeline.WeekRow] {
        let current = AnkerCalendar.weekInterval(containing: now).monday
        var rows = SidebarTimeline.rows(around: current, in: weeks, now: now, span: -6...10)
        // Eine weiter entfernte, gerade gewählte Woche gehört trotzdem in die Liste.
        let selected = AnkerCalendar.weekKey(containing: selectedWeekStart)
        if !rows.contains(where: { $0.isoYear == selected.isoYear && $0.isoWeek == selected.isoWeek }) {
            rows.append(SidebarTimeline.row(forWeekContaining: selectedWeekStart, in: weeks, now: now))
            rows.sort { $0.monday < $1.monday }
        }
        return rows
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            AnkerRule(weight: .row)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: AnkerSpacing.s0) {
                        ForEach(rows) { row in
                            weekRow(row).id(row.monday)
                        }
                    }
                    .padding(.horizontal, AnkerSpacing.s2)
                    .padding(.vertical, AnkerSpacing.s2)
                }
                .onAppear { proxy.scrollTo(AnkerCalendar.weekInterval(containing: selectedWeekStart).monday, anchor: .center) }
            }
            AnkerRule(weight: .row)
            footer
        }
        .background(AnkerColor.surface)
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
#endif
    }

    // MARK: - Teile

    private var header: some View {
        HStack {
            Text("Wochen")
                .ankerType(AnkerType.overline)
                .foregroundStyle(AnkerColor.inkSecond)
            Spacer()
            Button(action: onToday) {
                Text("Heute")
                    .ankerType(AnkerType.label)
                    .foregroundStyle(AnkerColor.accentInk)
#if os(iOS)
                    .frame(minWidth: 44, minHeight: 44)
#endif
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zur laufenden Woche")
        }
        .padding(.horizontal, AnkerSpacing.s4)
#if os(macOS)
        // Platz für die Ampelknöpfe über der Leiste.
        .padding(.top, AnkerSpacing.s6 + AnkerSpacing.s1)
#else
        .padding(.top, AnkerSpacing.s3)
#endif
        .padding(.bottom, AnkerSpacing.s3)
    }

    private func weekRow(_ row: SidebarTimeline.WeekRow) -> some View {
        let isSelected = AnkerCalendar.isSameDay(row.monday, AnkerCalendar.weekInterval(containing: selectedWeekStart).monday)
        let isTargeted = targetedWeek.map { AnkerCalendar.isSameDay($0, row.monday) } ?? false
        let sunday = AnkerCalendar.iso.date(byAdding: .day, value: 6, to: row.monday) ?? row.monday

        return Button { onSelectWeek(row.monday) } label: {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s2) {
                    Text(verbatim: AnkerDateFormat.calendarWeek(row.isoWeek))
                        .ankerType(AnkerType.bodyStrong)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(row.isCurrent ? AnkerColor.accentInk : (row.isPast ? AnkerColor.inkSecond : AnkerColor.ink))
                    Text(verbatim: AnkerDateFormat.weekSpan(monday: row.monday, sunday: sunday))
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(AnkerColor.inkSecond)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if row.openCount > 0 {
                        Text("\(row.openCount) offen")
                            .ankerType(AnkerType.microLabel)
                            .foregroundStyle(AnkerColor.inkSecond)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                HStack(spacing: AnkerSpacing.s1) {
                    ForEach(Array(row.marks.enumerated()), id: \.offset) { _, mark in
                        markView(mark)
                    }
                }
            }
            .padding(.vertical, AnkerSpacing.s2)
            .padding(.horizontal, AnkerSpacing.s2)
            .frame(minHeight: 44)
            .background(
                isTargeted ? AnkerColor.accentTint : (isSelected ? AnkerColor.card : Color.clear),
                in: RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous)
            )
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous)
                        .strokeBorder(AnkerColor.accentMark, lineWidth: AnkerBorder.focus)
                } else if isSelected {
                    RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous)
                        .strokeBorder(AnkerColor.divider, lineWidth: AnkerBorder.hairline)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(row.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Öffnet die Woche. Aufgaben lassen sich hierher ziehen.")
        .onDrop(of: TaskDropHandling.draggedTypes, isTargeted: Binding(
            get: { isTargeted },
            set: { targetedWeek = $0 ? row.monday : (isTargeted ? nil : targetedWeek) }
        )) { providers in
            TaskDropHandling.loadTaskID(from: providers) { id in
                move(taskID: id, toWeekStarting: row.monday)
            }
        }
    }

    private func markView(_ mark: SidebarTimeline.DayMark) -> some View {
        let shape = RoundedRectangle(cornerRadius: AnkerRadius.mark, style: .continuous)
        return ZStack {
            switch mark {
            case .today:
                shape.fill(AnkerColor.accentFill)
            case .done:
                shape.fill(AnkerColor.ink)
            case .open:
                shape.strokeBorder(AnkerColor.ink, lineWidth: 1.5)
            case .empty:
                shape.strokeBorder(AnkerColor.dividerStrong.opacity(0.6), lineWidth: 1)
            }
        }
        .frame(width: 12, height: 12)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            BlattUndoBar(coordinator: undo, weeks: weeks)
            Button(action: onArchive) {
                HStack(spacing: AnkerSpacing.s2) {
                    Image(.archive).ankerIcon(AnkerIconSize.s)
                    Text("Archiv")
                    Spacer()
                }
                .ankerType(AnkerType.label)
                .foregroundStyle(AnkerColor.ink)
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            CloudSyncStatusRow(status: cloudSyncStatus)
        }
        .padding(AnkerSpacing.s3)
        .animation(.easeOut(duration: 0.2), value: undo.notice?.id)
    }

    // MARK: - Ablegen

    /// Siehe `TaskActions.move(_:toWeekStarting:…)`: derselbe Wochentag in der Zielwoche.
    private func move(taskID: UUID, toWeekStarting monday: Date) {
        targetedWeek = nil
        let descriptor = FetchDescriptor<AnkerTask>(predicate: #Predicate { $0.id == taskID })
        guard let task = try? modelContext.fetch(descriptor).first else {
            TaskDragEvents.end(taskID: taskID)
            return
        }

        let snapshot = TaskActions.snapshot(task)
        let target = TaskActions.move(task, toWeekStarting: monday, weeks: weeks, modelContext: modelContext)
        TaskDragEvents.end(taskID: taskID)
        undo.present(TaskUndoNotice(
            message: String(localized: "Nach \(AnkerDateFormat.calendarWeek(AnkerCalendar.weekKey(containing: target).isoWeek)) verschoben"),
            snapshots: [snapshot]
        ))
    }
}
