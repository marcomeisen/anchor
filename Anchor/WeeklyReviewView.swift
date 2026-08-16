import SwiftData
import SwiftUI

/// Der Wochenrückblick als **Ritual**.
///
/// Lot löst das rote Plakat ab, ohne die Hierarchie anzufassen: eine Zahl, das nicht Gehaltene,
/// eine Frage. Was wechselt, ist die Lautstärke — sie kommt jetzt aus Fläche und Schriftwechsel
/// statt aus Signalfarbe. „Dunkel, Serif, kein Chrome. Der Übertrag wird hier entschieden — pro
/// Aufgabe, nicht stillschweigend."
///
/// Der Bildschirm ist der zweite Modus des Systems und deshalb **immer dunkel**, auch wenn die
/// App hell läuft: er nimmt `AnkerColor.Ritual` statt der kippenden Tokens. Abstände laufen über
/// `AnkerSpacing.ritual(_:)` — Dichte 1,4.
///
/// Die Antwort landet in `Week.reflection` und überlebt damit den Bildschirmwechsel; vorher war
/// sie `@State` und beim Verlassen weg.
struct WeeklyReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Week.monday) private var weeks: [Week]

    let week: Week

    @State private var draft = ""
    @State private var showingSettings = false
    @State private var confirmingDrop = false
    @FocusState private var isEditing: Bool

    /// Die Entscheidung je offener Aufgabe. Was nicht darin steht, wandert mit.
    @State private var decisions: [UUID: WeekActions.CarryDecision] = [:]

    private var report: AnkerStatistics.WeekReport {
        AnkerStatistics.week(week)
    }

    private var streak: AnkerStatistics.Streak {
        AnkerStatistics.streak(in: weeks)
    }

    private var openTasks: [AnkerTask] {
        week.dayList
            .sorted { $0.date < $1.date }
            .flatMap { $0.taskList.filter { !$0.isDone } }
    }

    /// Die Anker der **Folgewoche** — dorthin wandert der Übertrag, und ein Anker gehört genau
    /// einer Woche. Gibt es die Woche noch nicht, ist die Liste leer und „neu verankern" sagt das.
    private var targetAnchors: [Goal] {
        guard let nextMonday = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday),
              let next = weeks.first(where: { AnkerCalendar.isSameDay($0.monday, nextMonday) }) else {
            return []
        }
        return GoalOrdering.anchors(in: next).filter(WeekPlanning.isUserCreated)
    }

    private func decision(for task: AnkerTask) -> WeekActions.CarryDecision {
        decisions[task.id] ?? .keep
    }

    private var tally: (kept: Int, dropped: Int) {
        let open = openTasks
        let dropped = open.filter { decision(for: $0) == .drop }.count
        return (open.count - dropped, dropped)
    }

    var body: some View {
        let report = self.report

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                poster(report)
                question
                carrySection
                actions(report)
                appSection
            }
        }
        .background(AnkerColor.Ritual.surface)
        // Das Ritual bringt seine eigene Helligkeit mit. Ohne das zeichnet das System
        // Auswahlfarben, Menüs und den Textcursor für den hellen Modus in eine dunkle Fläche.
        .environment(\.colorScheme, .dark)
        .navigationTitle("Wochenrückblick")
        .task(id: week.id) {
            draft = week.reflection ?? ""
        }
        // Ein Speichervorgang pro Tippppause statt pro Zeichen: `task(id:)` bricht bei jeder
        // Aenderung ab und faengt neu an. Ueber CloudKit ist das der Unterschied zwischen
        // einem Export und hundert.
        .task(id: draft) {
            guard draft != (week.reflection ?? "") else { return }
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            WeekActions.setReflection(draft, in: week, modelContext: modelContext)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        // Der Dialog kommt nur, wenn etwas **gelöscht** wird. Ein Übertrag ist umkehrbar, eine
        // gestrichene Aufgabe nicht — nur dafür lohnt die Rückfrage.
        .confirmationDialog("Aufgaben streichen?", isPresented: $confirmingDrop, titleVisibility: .visible) {
            Button("Streichen und schließen", role: .destructive) { close() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text(dropMessage)
        }
    }

    // MARK: - Die Zahl

    /// „Im Rückblick wird die Woche zu einer Zahl im Serif. Der einzige Ort, an dem eine
    /// Kennzahl groß sein darf."
    private func poster(_ report: AnkerStatistics.WeekReport) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Rückblick · \(AnkerDateFormat.calendarWeek(week.isoWeek))")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.Ritual.amber)

            ritualCount(report)
                .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s5))

            Text(verbatim: posterHeadline(report))
                .ankerType(AnkerType.ritualTitle)
                .foregroundStyle(AnkerColor.Ritual.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AnkerSpacing.s4)

            missedSection(report)
        }
        .padding(.horizontal, AnkerSpacing.ritual(AnkerSpacing.s5))
        .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s6))
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("reviewPoster")
    }

    /// Der Bruch „3/4" im Serif.
    ///
    /// Instrument Serif hat keine tabellarischen Ziffern (siehe `AnkerType.poster`), und beim
    /// Schliessen der Woche zaehlt der Zaehler hoch. Ohne festen Kasten schoebe „/4" dabei
    /// sichtbar hin und her — „1" ist in dieser Schrift knapp halb so breit wie „0". Der Kasten
    /// ist deshalb auf die **breiteste** Ziffer bemessen: gemessen 0,46 em, aufgerundet auf
    /// 0,5 em. `AnkerThemeTests` prueft die Messung, damit sie bei einem Schriftwechsel auffaellt.
    private static let widestDigitEm: CGFloat = 0.5

    private func ritualCount(_ report: AnkerStatistics.WeekReport) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(verbatim: "\(report.inMotionCount)")
                .ankerType(AnkerType.poster)
                .foregroundStyle(AnkerColor.Ritual.ink)
                .frame(width: AnkerType.poster.size * Self.widestDigitEm, alignment: .trailing)
                .contentTransition(.numericText())
            Text(verbatim: "/\(report.anchorCount)")
                .ankerType(AnkerType.poster)
                .foregroundStyle(AnkerColor.Ritual.faint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(report.inMotionCount) von \(report.anchorCount) Ankern")
    }

    private func posterHeadline(_ report: AnkerStatistics.WeekReport) -> String {
        guard report.anchorCount > 0 else { return "Diese Woche hatte keine Anker." }

        var text = report.inMotionCount == report.anchorCount
            ? "Anker gehalten."
            : "Anker in Bewegung."
        if streak.weeks > 1 {
            text += " \(streak.weeks). Woche in Folge."
        }
        return text
    }

    /// Der nicht gehaltene Anker mit seinem Übertrag — benannt, nicht stillschweigend verschoben.
    ///
    /// Die einzige Stelle des Bildschirms in Rost: „Rost markiert nur den Rückstand."
    @ViewBuilder
    private func missedSection(_ report: AnkerStatistics.WeekReport) -> some View {
        if let missed = report.firstMissedAnchor {
            AnkerRule(color: AnkerColor.Ritual.hairline)
                .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s5))

            Text(verbatim: "Nicht gehalten")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.Ritual.rust)
                .padding(.top, AnkerSpacing.s4)
                .padding(.bottom, AnkerSpacing.s3)

            HStack(alignment: .top, spacing: AnkerSpacing.s3) {
                Text(verbatim: "\(missed.number)")
                    .ankerType(AnkerType.ritualQuestion)
                    .foregroundStyle(AnkerColor.Ritual.faint)

                VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                    Text(verbatim: missed.title)
                        .ankerType(AnkerType.subheadline)
                        .foregroundStyle(AnkerColor.Ritual.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(verbatim: carryText(for: missed))
                        .ankerType(AnkerType.meta)
                        .foregroundStyle(AnkerColor.Ritual.inkMuted)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func carryText(for anchor: AnkerStatistics.AnchorReport) -> String {
        let next = AnkerDateFormat.calendarWeek(
            AnkerCalendar.weekInterval(
                containing: AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday) ?? week.monday
            ).isoWeek
        )
        switch anchor.openCount {
        case 0: return "keine offene Aufgabe"
        case 1: return "1 Aufgabe wandert nach \(next)"
        default: return "\(anchor.openCount) Aufgaben wandern nach \(next)"
        }
    }

    // MARK: - Die eine Frage

    private var question: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: "Eine Frage")
                .ankerType(AnkerType.eyebrow)
                .foregroundStyle(AnkerColor.Ritual.inkMuted)
                .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s6))
                .padding(.bottom, AnkerSpacing.s3)

            Text(verbatim: "Was hat dich diese Woche wirklich aufgehalten?")
                .ankerType(AnkerType.ritualQuestion)
                .foregroundStyle(AnkerColor.Ritual.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, AnkerSpacing.s4)

            TextEditor(text: $draft)
                .ankerType(AnkerType.taskTitle)
                .foregroundStyle(AnkerColor.Ritual.ink)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 88)
                .padding(AnkerSpacing.s3)
                .background(
                    AnkerColor.Ritual.field,
                    in: RoundedRectangle(cornerRadius: AnkerRadius.card, style: .continuous)
                )
                .focused($isEditing)
                .accessibilityLabel("Antwort auf die Wochenfrage")
                .accessibilityIdentifier("reviewAnswer")
        }
        .padding(.horizontal, AnkerSpacing.ritual(AnkerSpacing.s5))
    }

    // MARK: - Übertrag pro Aufgabe

    /// Der Kern der zweiten Runde: **jede** offene Aufgabe bekommt eine Entscheidung.
    ///
    /// Vorher gab es alles-oder-nichts in einem Dialog. Der Entwurf begründet den Wechsel so:
    /// „Nichts wandert stillschweigend — das war der Grund, warum die Übersicht sich fremd
    /// anfühlte." Wer nichts anfasst, überträgt; das steht auf dem Knopf.
    @ViewBuilder
    private var carrySection: some View {
        let open = openTasks

        if !open.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: AnkerSpacing.s3) {
                    Text(verbatim: "Übertrag")
                        .ankerType(AnkerType.eyebrow)
                        .foregroundStyle(AnkerColor.Ritual.inkMuted)

                    Spacer(minLength: AnkerSpacing.s2)

                    Text(verbatim: "\(open.count) offen · Ziel \(nextWeekLabel)")
                        .ankerType(AnkerType.meta)
                        .foregroundStyle(AnkerColor.Ritual.faint)
                }
                .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s6))
                .padding(.bottom, AnkerSpacing.s3)

                AnkerRule(color: AnkerColor.Ritual.hairline)

                ForEach(open, id: \.id) { task in
                    CarryRow(
                        task: task,
                        decision: decision(for: task),
                        targetAnchors: targetAnchors,
                        nextWeekLabel: nextWeekLabel
                    ) { decision in
                        decisions[task.id] = decision
                    }
                    AnkerRule(color: AnkerColor.Ritual.hairline, weight: .row)
                }
            }
            .padding(.horizontal, AnkerSpacing.ritual(AnkerSpacing.s5))
        }
    }

    // MARK: - Abschluss

    @ViewBuilder
    private func actions(_ report: AnkerStatistics.WeekReport) -> some View {
        VStack(alignment: .leading, spacing: AnkerSpacing.s4) {
            if report.isClosed {
                Text(verbatim: closedLabel)
                    .ankerType(AnkerType.eyebrow)
                    .foregroundStyle(AnkerColor.Ritual.inkMuted)

                RitualButton("Wieder öffnen", kind: .quiet) {
                    WeekActions.reopen(week, modelContext: modelContext)
                }
            } else {
                RitualButton(closeLabel, kind: .primary) {
                    if tally.dropped > 0 {
                        confirmingDrop = true
                    } else {
                        close()
                    }
                }
                .accessibilityIdentifier("closeWeek")
            }

            if report.carriedInTaskCount > 0 {
                Text(verbatim: "\(report.carriedInTaskCount) Aufgaben kamen aus einer früheren Woche.")
                    .ankerType(AnkerType.caption)
                    .foregroundStyle(AnkerColor.Ritual.inkMuted)
            }
        }
        .padding(.horizontal, AnkerSpacing.ritual(AnkerSpacing.s5))
        .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s6))
    }

    private var closedLabel: String {
        guard let date = week.reviewedAt else { return "Woche geschlossen" }
        return "Woche geschlossen · \(AnkerDateFormat.dayMonth(date))"
    }

    private var nextWeekLabel: String {
        AnkerDateFormat.calendarWeek(
            AnkerCalendar.weekInterval(
                containing: AnkerCalendar.iso.date(byAdding: .weekOfYear, value: 1, to: week.monday) ?? week.monday
            ).isoWeek
        )
    }

    /// Der Knopf nennt, was passiert. Das ist der Ersatz für den alten Dialog: „Nichts wandert
    /// stillschweigend" heißt nicht zwingend nachfragen, sondern vorher benennen.
    private var closeLabel: String {
        let tally = self.tally
        switch (tally.kept, tally.dropped) {
        case (0, 0): return "Woche schließen"
        case (let kept, 0): return "Schließen · \(kept) nach \(nextWeekLabel)"
        case (0, let dropped): return "Schließen · \(dropped) streichen"
        case (let kept, let dropped): return "Schließen · \(kept) übertragen, \(dropped) streichen"
        }
    }

    private var dropMessage: String {
        let tally = self.tally
        let dropped = tally.dropped == 1
            ? "1 Aufgabe wird gelöscht"
            : "\(tally.dropped) Aufgaben werden gelöscht"
        guard tally.kept > 0 else { return "\(dropped). Das lässt sich nicht zurücknehmen." }
        return "\(dropped), \(tally.kept) wandern nach \(nextWeekLabel). Das Löschen lässt sich nicht zurücknehmen."
    }

    private func close() {
        WeekActions.close(week, decisions: decisions, weeks: weeks, modelContext: modelContext)
        decisions = [:]
    }

    // MARK: - App

    /// Der eine Werkzeugzugang, den das Ritual tragen muss.
    ///
    /// „Kein Chrome, keine Werkzeuge" gilt der Rahmung — Leisten, Tabs, Glas. Diese Zeile bleibt
    /// trotzdem, weil sie auf dem iPhone der **einzige** Weg in die Einstellungen ist (siehe
    /// `AnkerTabBar`). Sie steht deshalb ganz unten, hinter der Entscheidung, und so leise wie
    /// eine Zeile sein kann.
    private var appSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            AnkerRule(color: AnkerColor.Ritual.hairline)
                .padding(.top, AnkerSpacing.ritual(AnkerSpacing.s6))

            Button {
                showingSettings = true
            } label: {
                HStack(spacing: AnkerSpacing.s3) {
                    Image(.settings).ankerIcon(AnkerIconSize.s)
                        .foregroundStyle(AnkerColor.Ritual.inkMuted)
                    VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                        Text(verbatim: "Einstellungen")
                            .ankerType(AnkerType.body)
                            .foregroundStyle(AnkerColor.Ritual.inkSecond)
                        Text(verbatim: "Erscheinungsbild, iCloud-Sync, Daten")
                            .ankerType(AnkerType.caption)
                            .foregroundStyle(AnkerColor.Ritual.inkMuted)
                    }
                    Spacer(minLength: 0)
                    Image(.chevronRight).ankerIcon(AnkerIconSize.xs)
                        .foregroundStyle(AnkerColor.Ritual.faint)
                }
                .padding(.vertical, AnkerSpacing.s4)
                .frame(minHeight: AnkerSpacing.touchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Einstellungen öffnen")
        }
        .padding(.horizontal, AnkerSpacing.ritual(AnkerSpacing.s5))
        .padding(.bottom, AnkerSpacing.section)
    }
}

/// Ein Knopf im Ritual: eine **Pille**, feste Farben, mittige Beschriftung.
///
/// Nicht `AnkerButtonStyle`: der zieht seine Farben aus den kippenden Tokens, und das Ritual ist
/// immer dunkel. Die Form folgt dem Entwurf — im Ritual ist ein Knopf das einzige Objekt auf der
/// Seite, und eine Pille sagt das deutlicher als ein 12pt-Radius.
private struct RitualButton: View {
    enum Kind { case primary, quiet }

    let title: String
    let kind: Kind
    let action: () -> Void

    init(_ title: String, kind: Kind, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(verbatim: title)
                .ankerType(AnkerType.label)
                .foregroundStyle(kind == .primary ? AnkerColor.Ritual.surface : AnkerColor.Ritual.inkSecond)
                .frame(maxWidth: .infinity, minHeight: AnkerSpacing.touchTarget)
                .padding(.horizontal, AnkerSpacing.s4)
                .ankerPill(
                    fill: kind == .primary ? AnkerColor.Ritual.amber : .clear,
                    stroke: kind == .primary ? nil : AnkerColor.Ritual.hairline
                )
        }
        .buttonStyle(.plain)
    }
}

/// Eine offene Aufgabe mit ihrer Entscheidung.
///
/// Drei Zustände, einer davon mit Nutzlast — deshalb keine Segmentleiste aus drei gleichen
/// Knöpfen, sondern zwei Knöpfe und ein Menü. „Neu verankern" braucht das Ziel.
private struct CarryRow: View {
    let task: AnkerTask
    let decision: WeekActions.CarryDecision
    let targetAnchors: [Goal]
    let nextWeekLabel: String
    let onChange: (WeekActions.CarryDecision) -> Void

    private var isDropped: Bool { decision == .drop }

    private var reanchorTarget: Goal? {
        guard case .reanchor(let goalID) = decision, let goalID else { return nil }
        return targetAnchors.first { $0.id == goalID }
    }

    private var isReanchored: Bool {
        if case .reanchor = decision { return true }
        return false
    }

    var body: some View {
        HStack(alignment: .top, spacing: AnkerSpacing.s3) {
            VStack(alignment: .leading, spacing: AnkerSpacing.s1) {
                Text(verbatim: task.title)
                    .ankerType(AnkerType.taskTitle)
                    .foregroundStyle(isDropped ? AnkerColor.Ritual.faint : AnkerColor.Ritual.ink)
                    .strikethrough(isDropped, color: AnkerColor.Ritual.faint)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(verbatim: metaLine)
                    .ankerType(AnkerType.meta)
                    .foregroundStyle(isReanchored ? AnkerColor.Ritual.amber : AnkerColor.Ritual.inkMuted)
            }

            Spacer(minLength: AnkerSpacing.s2)

            // Eine Segmentleiste wird als **ein** gerundetes Objekt geklippt; die Trenner darin
            // bleiben Haarlinien.
            HStack(spacing: 0) {
                choiceButton("Behalten", isActive: decision == .keep) { onChange(.keep) }
                AnkerRule(axis: .vertical, color: AnkerColor.Ritual.hairline)
                choiceButton("Streichen", isActive: isDropped) { onChange(.drop) }
                AnkerRule(axis: .vertical, color: AnkerColor.Ritual.hairline)
                reanchorMenu
            }
            .fixedSize()
            .background(AnkerColor.Ritual.field)
            .clipShape(RoundedRectangle(cornerRadius: AnkerRadius.control, style: .continuous))
        }
        .padding(.vertical, AnkerSpacing.s3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(task.title), \(metaLine)")
        .accessibilityIdentifier("carryRow.\(task.title)")
    }

    private var metaLine: String {
        if isDropped { return "wird gestrichen" }
        if case .reanchor(let goalID) = decision {
            guard let goalID else { return "nach \(nextWeekLabel), ohne Anker" }
            let title = targetAnchors.first { $0.id == goalID }?.title ?? "unbekannter Anker"
            return "nach \(nextWeekLabel) an \(title)"
        }
        let anchor = task.linkedGoal?.title
        let day = task.day.map { AnkerDateFormat.weekdayShort($0.date) } ?? "—"
        return anchor.map { "\($0) · \(day) · nach \(nextWeekLabel)" } ?? "Ohne Anker · \(day) · nach \(nextWeekLabel)"
    }

    private func choiceButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(verbatim: title)
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(isActive ? AnkerColor.Ritual.surface : AnkerColor.Ritual.inkSecond)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s3)
                .background(isActive ? AnkerColor.Ritual.amber : Color.clear, in: Rectangle())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
    }

    private var reanchorMenu: some View {
        Menu {
            if targetAnchors.isEmpty {
                // Ehrlich statt leer: die Folgewoche existiert noch nicht oder hat keine Anker.
                // Die Aufgabe wandert dann ohne Anker — ein Anker gehört genau einer Woche.
                Text("\(nextWeekLabel) hat noch keine Anker")
            } else {
                ForEach(targetAnchors, id: \.id) { goal in
                    Button(goal.title) { onChange(.reanchor(goalID: goal.id)) }
                }
            }
            Divider()
            Button("Ohne Anker") { onChange(.reanchor(goalID: nil)) }
        } label: {
            Text(verbatim: reanchorTarget == nil ? "Verankern" : "Anker ✓")
                .ankerType(AnkerType.microLabel)
                .foregroundStyle(isReanchored ? AnkerColor.Ritual.surface : AnkerColor.Ritual.inkSecond)
                .padding(.horizontal, AnkerSpacing.s3)
                .padding(.vertical, AnkerSpacing.s3)
                .background(isReanchored ? AnkerColor.Ritual.amber : Color.clear, in: Rectangle())
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Neu verankern")
    }
}
