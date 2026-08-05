import SwiftData
import SwiftUI

/// Das Jahr als Band: ein Balken pro ISO-Woche, Höhe = Anker in Bewegung.
///
/// Ersetzt die zwölf Monatskacheln. Der Entwurf begründet das damit, dass 52 Balken mehr sagen
/// als zwölf Farbkacheln — und die **Lücken** sind dabei die eigentliche Aussage: eine Woche
/// ohne Datensatz ist eine Woche ohne Plan, nicht eine Woche ohne Daten.
struct YearOverviewView: View {
    let week: Week
    let weeks: [Week]
    var onSelectWeek: (Int) -> Void = { _ in }

    private var report: AnkerStatistics.YearReport {
        AnkerStatistics.year(isoYear: week.isoYear, in: weeks)
    }

    var body: some View {
        let report = self.report

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header(report)
                band(report)
                stats(report)
            }
            .padding(.horizontal, AnkerSpacing.screenPadding)
#if os(iOS)
            .padding(.bottom, AnkerSpacing.s5)
#else
            .padding(.bottom, AnkerSpacing.s5)
#endif
        }
        .background(AnkerColor.ground)
        .navigationTitle("Jahresübersicht")
    }

    // MARK: - Kopf

    private func header(_ report: AnkerStatistics.YearReport) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s2) {
            Text(verbatim: "\(report.isoYear) · \(report.bars.count) Wochen")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s4)

            Text(verbatim: headline(report))
                .ankerType(AnkerType.title3)
                .foregroundStyle(AnkerColor.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s4)

            AnkerRule(color: AnkerColor.ink)
        }
    }

    private func headline(_ report: AnkerStatistics.YearReport) -> String {
        guard report.plannedWeekCount > 0 else { return "Noch keine Woche geplant" }
        return "\(report.heldWeekCount) Wochen gehalten"
    }

    // MARK: - Band

    private func band(_ report: AnkerStatistics.YearReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Anker pro Woche")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
                .padding(.top, AnkerSpacing.s4)
                .padding(.bottom, AnkerSpacing.s3)

            HStack(alignment: .bottom, spacing: AnkerSpacing.s1) {
                ForEach(report.bars) { bar in
                    Button {
                        onSelectWeek(bar.isoWeek)
                    } label: {
                        YearBandBar(bar: bar, isCurrent: bar.isoWeek == week.isoWeek)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label(for: bar))
                }
            }
            .frame(height: 110)

            AnkerRule(color: AnkerColor.ink)

            HStack {
                Text(verbatim: AnkerDateFormat.calendarWeek(1))
                Spacer()
                Text(verbatim: AnkerDateFormat.calendarWeek(report.bars.count / 2))
                Spacer()
                Text(verbatim: AnkerDateFormat.calendarWeek(report.bars.count))
            }
            .ankerType(AnkerType.numericSmall)
            .foregroundStyle(AnkerColor.inkSecond)
            .padding(.top, AnkerSpacing.s2)
        }
    }

    private func label(for bar: AnkerStatistics.YearBar) -> String {
        guard bar.anchorCount > 0 else {
            return "\(AnkerDateFormat.calendarWeek(bar.isoWeek)), nicht geplant"
        }
        return "\(AnkerDateFormat.calendarWeek(bar.isoWeek)), \(bar.inMotionCount) von \(bar.anchorCount) Ankern in Bewegung"
    }

    // MARK: - Kennzahlen

    private func stats(_ report: AnkerStatistics.YearReport) -> some View {
        VStack(spacing: 0) {
            AnkerRule(color: AnkerColor.ink)
                .padding(.top, AnkerSpacing.s5)

            HStack(spacing: 0) {
                YearStat(
                    value: "\(report.streak.weeks)",
                    label: "Wochen Serie",
                    hint: report.streak.isRunning ? "laufend" : nil
                )
                AnkerRule(axis: .vertical)
                YearStat(value: "\(report.heldAnchorPercentage)%", label: "Anker gehalten")
            }
            AnkerRule()

            HStack(spacing: 0) {
                YearStat(
                    value: report.strongestWeekday.map { AnkerDateFormat.weekdayShort(dateOfWeekday($0.index)) } ?? "—",
                    label: "Stärkster Tag"
                )
                AnkerRule(axis: .vertical)
                YearStat(
                    value: "\(report.carriedInTaskCount)",
                    label: "Übertragungen",
                    isEmphasized: report.carriedInTaskCount > 0
                )
            }
        }
    }

    /// Für die Kurzform des stärksten Wochentags — `AnkerDateFormat` rechnet mit Datumswerten.
    private func dateOfWeekday(_ index: Int) -> Date {
        let monday = AnkerCalendar.weekInterval(containing: week.monday).monday
        return AnkerCalendar.iso.date(byAdding: .day, value: index - 1, to: monday) ?? monday
    }
}

/// Ein Balken des Jahresbands.
///
/// Die Höhe ist der Anteil bewegter Anker, die Farbe der Zustand. Eine ungeplante Woche ist
/// eine dünne Linie am Boden — sichtbar, aber ohne Höhe: nichts geplant ist nicht dasselbe wie
/// nichts geschafft.
private struct YearBandBar: View {
    let bar: AnkerStatistics.YearBar
    let isCurrent: Bool

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Rectangle()
                    .fill(fill)
                    .frame(height: max(AnkerBorder.rule, proxy.size.height * heightFactor))
            }
        }
        .frame(minWidth: 2)
        .overlay(alignment: .bottom) {
            if isCurrent {
                Rectangle()
                    .fill(AnkerColor.accentMark)
                    .frame(height: AnkerBorder.heavy)
            }
        }
        .contentShape(Rectangle())
    }

    private var heightFactor: Double {
        bar.anchorCount == 0 ? 0 : max(0.06, bar.fill)
    }

    private var fill: Color {
        switch bar.standing {
        case .held: AnkerColor.ink
        case .missed: AnkerColor.neutral[600]
        case .running: AnkerColor.accentMark
        case .unplanned: AnkerColor.neutral[300]
        case .upcoming: AnkerColor.neutral[200]
        }
    }
}

private struct YearStat: View {
    let value: String
    let label: String
    var hint: String?
    var isEmphasized = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
            Text(verbatim: value)
                .ankerType(AnkerType.statValue)
                .foregroundStyle(isEmphasized ? AnkerColor.accentInk : AnkerColor.ink)

            Text(verbatim: hint.map { "\(label) · \($0)" } ?? label)
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.inkSecond)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, AnkerSpacing.s4)
        .padding(.trailing, AnkerSpacing.s4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) \(label)")
    }
}
