import SwiftData
import SwiftUI

/// Die Anker als Streifen über dem Inhalt.
///
/// Der Entwurf nimmt sie aus der Navigation heraus und begründet das so: „Anker sind Inhalt, kein
/// Ziel einer Navigation. Sie stehen als Streifen über dem Inhalt — immer sichtbar, immer im
/// Zeitkontext." In der Sidebar waren sie ein Link-Label neben Wochen und Tagen; hier sind sie
/// ein Zustand mit Nummer, Fortschritt und Stand.
///
/// Das weiche Limit ist sichtbar: der fünfte Anker steht blasser und sagt „über Empfehlung".
/// Verstecken würde bedeuten, dass auf zwei Geräten ein anderer verschwindet.
struct AnchorStripView: View {
    let week: Week
    var selectedGoalID: UUID?
    var onSelect: (UUID) -> Void = { _ in }

    private var reports: [AnkerStatistics.AnchorReport] {
        AnkerStatistics.allAnchors(in: week)
    }

    var body: some View {
        let reports = self.reports

        VStack(alignment: .leading, spacing: 0) {
            header(reports)

            if reports.isEmpty {
                Text(verbatim: "Noch kein Anker in dieser Woche.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.inkTertiary)
                    .padding(.bottom, AnkerSpacing.s3)
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(reports.enumerated()), id: \.element.id) { index, report in
                        AnchorChip(
                            report: report,
                            isSelected: report.id == selectedGoalID,
                            isLast: index == reports.count - 1
                        ) {
                            onSelect(report.id)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous).stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule))
                .padding(.bottom, AnkerSpacing.s3)
            }
        }
        .padding(.horizontal, AnkerSpacing.s5)
        .padding(.top, AnkerSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnkerColor.ground)
        .ankerEdge(.bottom, color: AnkerColor.ink)
    }

    private func header(_ reports: [AnkerStatistics.AnchorReport]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s3) {
            Text(verbatim: "Anker dieser Woche")
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(AnkerColor.inkSecond)

            Spacer(minLength: AnkerSpacing.s2)

            // Nur nennen, wenn es etwas zu nennen gibt. „4 empfohlen · 4 gesetzt" wäre Lärm.
            if reports.count > GoalOrdering.maxAnchors {
                Text(verbatim: "\(GoalOrdering.maxAnchors) empfohlen · \(reports.count) gesetzt")
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(AnkerColor.accentInk)
            }
        }
        .padding(.bottom, AnkerSpacing.s2)
    }
}

/// Ein Anker im Streifen: Nummer, Titel, Balken, Stand.
private struct AnchorChip: View {
    let report: AnkerStatistics.AnchorReport
    let isSelected: Bool
    let isLast: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s2) {
                    Text(verbatim: "\(report.number)")
                        .ankerType(AnkerType.numericSmall)
                        .foregroundStyle(report.isOverRecommendation ? AnkerColor.inkTertiary : AnkerColor.ink)

                    Text(verbatim: report.title)
                        .ankerType(isSelected ? AnkerType.bodyStrong : AnkerType.caption)
                        .foregroundStyle(AnkerColor.ink)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                AnkerProgressBar(
                    progress: report.progress,
                    tint: report.isStalled ? AnkerColor.accentMark : AnkerColor.ink,
                    thickness: AnkerBorder.rule * 2
                )
                .padding(.top, AnkerSpacing.s2)

                Text(verbatim: report.statusLine)
                    .ankerType(AnkerType.microLabel)
                    .foregroundStyle(report.isStalled ? AnkerColor.accentInk : AnkerColor.inkSecond)
                    .lineLimit(1)
                    .padding(.top, AnkerSpacing.s2)
            }
            .padding(.horizontal, AnkerSpacing.s3)
            .padding(.vertical, AnkerSpacing.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AnkerColor.surface : Color.clear, in: Rectangle())
            // Der Marker sitzt unten, nicht links: der Streifen ist waagerecht, und der Entwurf
            // setzt die Kante immer quer zur Laufrichtung.
            .overlay(alignment: .bottom) {
                if isSelected {
                    Rectangle()
                        .fill(AnkerColor.accentMark)
                        .frame(height: AnkerBorder.heavy)
                }
            }
            .overlay(alignment: .trailing) {
                if !isLast {
                    Rectangle()
                        .fill(AnkerColor.divider)
                        .frame(width: AnkerBorder.rule)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("anchorChip.\(report.title)")
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var accessibilityLabel: String {
        var text = "Anker \(report.number), \(report.title), \(report.doneCount) von \(report.totalCount) erledigt, \(report.statusLine)"
        if report.isOverRecommendation {
            text += ", über der Empfehlung von \(GoalOrdering.maxAnchors)"
        }
        return text
    }
}

/// Heute / Woche / Jahr als Segmentwechsel in der Kopfzeile des Inhalts.
///
/// Der Entwurf verschiebt ihn bewusst aus der Sidebar: „es ist ein Modus des Inhalts, kein Ort."
/// Die Sidebar beantwortet danach nur noch **wann**.
struct AnkerViewSwitcher: View {
    @Binding var selection: AppDestination
    var onSelectToday: () -> Void = {}

    private struct Segment {
        let title: String
        let destination: AppDestination
        let help: String
    }

    private static let segments = [
        Segment(title: "Heute", destination: .today, help: "Heute anzeigen"),
        Segment(title: "Woche", destination: .week, help: "Wochenübersicht anzeigen"),
        Segment(title: "Jahr", destination: .year, help: "Jahresübersicht anzeigen"),
    ]

    /// Ein Zieldetail gehört zur Woche — sonst spränge die Auswahl beim Öffnen eines Ankers auf
    /// nichts, obwohl der Streifen darüber weiter zur Woche gehört.
    private func isActive(_ destination: AppDestination) -> Bool {
        if case .goal = selection, destination == .week { return true }
        return selection == destination
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.segments.enumerated()), id: \.offset) { index, segment in
                let active = isActive(segment.destination)

                Button {
                    if segment.destination == .today { onSelectToday() }
                    selection = segment.destination
                } label: {
                    Text(verbatim: segment.title)
                        .ankerType(AnkerType.microLabel)
                        .foregroundStyle(active ? AnkerColor.onAccent : AnkerColor.ink)
                        .padding(.horizontal, AnkerSpacing.s3)
                        .padding(.vertical, AnkerSpacing.s2)
                        .background(active ? AnkerColor.accentFill : Color.clear, in: Rectangle())
                        .overlay(alignment: .trailing) {
                            if index < Self.segments.count - 1 {
                                Rectangle()
                                    .fill(active ? AnkerColor.onAccent : AnkerColor.ink)
                                    .frame(width: AnkerBorder.rule)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(segment.help)
                .accessibilityLabel(segment.help)
                .accessibilityAddTraits(active ? [.isSelected] : [])
            }
        }
        .fixedSize()
        .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous).stroke(AnkerColor.ink, lineWidth: AnkerBorder.rule))
    }
}

/// Die Kopfzeile des Inhalts: Ansichtswechsel, Woche, gewählter Tag.
///
/// Der Entwurf zeichnet den Wechsel als Zeile **im Inhalt**, nicht in der Fensterleiste — und das
/// ist auch technisch der richtige Ort: ein `ToolbarItem` mit eigener Segmentleiste erscheint auf
/// macOS in der Fensterleiste eines `NavigationSplitView` nicht verlässlich. Dieselbe Zeile
/// funktioniert zudem auf dem iPad ohne Sonderfall.
struct AnkerContentHeader: View {
    let week: Week
    let selectedDay: Day
    @Binding var selection: AppDestination
    var onSelectToday: () -> Void = {}

    var body: some View {
        HStack(spacing: AnkerSpacing.s4) {
            AnkerViewSwitcher(selection: $selection, onSelectToday: onSelectToday)

            Text(verbatim: "\(AnkerDateFormat.calendarWeek(week.isoWeek)) · \(AnkerDateFormat.weekSpan(monday: week.monday, sunday: week.sunday))")
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize()

            Spacer(minLength: AnkerSpacing.s2)

            Text(verbatim: AnkerDateFormat.weekdayShortWithDayMonth(selectedDay.date))
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(AnkerColor.inkSecond)
                .fixedSize()
        }
        .padding(.horizontal, AnkerSpacing.s5)
        .padding(.vertical, AnkerSpacing.s3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnkerColor.ground)
        .ankerEdge(.bottom, color: AnkerColor.ink)
    }
}
