import Foundation

/// Die Sidebar als Zeitschiene: pro Woche eine Zeile, in der Zeile sieben Quadrate.
///
/// Der Entwurf begründet das so: die Sidebar beantwortete vier Fragen gleichzeitig
/// (Ansichtswechsel, Zeitnavigation, Zielliste, App-Utility), und drei davon dieselbe — „wo bin
/// ich in der Zeit?". Hier beantwortet sie nur noch **wann**. Die sieben Quadrate ersetzen die
/// aufgeklappte Tagesliste für vergangene Wochen: sie bleiben lesbar, ohne Platz zu kosten.
///
/// Reiner Typ, keine View — deshalb prüfbar.
@MainActor
enum SidebarTimeline {

    /// Der Zustand eines Tages als ein Quadrat.
    ///
    /// Die Reihenfolge der Prüfung ist die Aussage: **heute** sticht alles, weil das Quadrat den
    /// Blick zuerst verankern soll. Danach entscheidet, ob überhaupt geplant war — „nichts
    /// geplant" ist nicht dasselbe wie „nichts geschafft", und der Entwurf zeichnet dafür zwei
    /// verschiedene Rahmen.
    enum DayMark: Equatable {
        /// Heute. Gefüllt im Akzent.
        case today
        /// Alles erledigt. Gefüllt in Tinte.
        case done
        /// Mindestens eine Aufgabe offen. Rahmen in Tinte.
        case open
        /// Kein Datensatz oder keine Aufgabe. Rahmen in der Trennlinienfarbe.
        case empty

        static func of(_ day: Day, now: Date) -> DayMark {
            if AnkerCalendar.isSameDay(day.date, now) { return .today }
            let tasks = day.taskList
            if tasks.isEmpty { return .empty }
            return tasks.allSatisfy(\.isDone) ? .done : .open
        }
    }

    /// Eine Woche in der Schiene. `week` ist nil, solange es den Datensatz nicht gibt — eine
    /// Zeile ohne Woche ist ein gültiges Ziel für einen Drop, sie wird dann angelegt.
    struct WeekRow: Identifiable, Equatable {
        let id: Date
        let monday: Date
        let isoWeek: Int
        let isoYear: Int
        let marks: [DayMark]
        /// Offene Aufgaben. Der Entwurf zeigt die Zahl nur, wenn sie nicht null ist.
        let openCount: Int
        let isCurrent: Bool
        let isPast: Bool
        let exists: Bool

        var label: String { "Woche \(String(format: "%02d", isoWeek))" }

        var accessibilityLabel: String {
            var text = "\(label), \(marks.filter { $0 == .done }.count) von 7 Tagen erledigt"
            if openCount > 0 { text += ", \(openCount) offen" }
            if isCurrent { text += ", laufende Woche" }
            return text
        }
    }

    /// Die Zeilen um eine Woche herum. Bewusst ein Fenster statt aller Wochen: die Schiene ist
    /// zum Springen da, nicht zum Blättern durch Jahre — dafür gibt es Archiv und Jahresband.
    static func rows(
        around anchorMonday: Date,
        in weeks: [Week],
        now: Date = Date(),
        span: ClosedRange<Int> = -2...2
    ) -> [WeekRow] {
        span.compactMap { offset in
            guard let date = AnkerCalendar.iso.date(byAdding: .weekOfYear, value: offset, to: anchorMonday) else {
                return nil
            }
            return row(forWeekContaining: date, in: weeks, now: now)
        }
    }

    static func row(forWeekContaining date: Date, in weeks: [Week], now: Date = Date()) -> WeekRow {
        let interval = AnkerCalendar.weekInterval(containing: date)
        let week = weeks.first { AnkerCalendar.isSameDay($0.monday, interval.monday) }
        let days = week.map { $0.dayList.sorted { $0.date < $1.date } } ?? []

        // Immer sieben Quadrate, auch wenn Tage fehlen: die Zeile ist ein Raster, keine Liste.
        // Eine Woche mit fünf Datensätzen darf nicht kürzer aussehen als eine mit sieben.
        let marks: [DayMark] = (0..<7).map { index in
            guard let date = AnkerCalendar.iso.date(byAdding: .day, value: index, to: interval.monday) else {
                return .empty
            }
            guard let day = days.first(where: { AnkerCalendar.isSameDay($0.date, date) }) else {
                return AnkerCalendar.isSameDay(date, now) ? .today : .empty
            }
            return DayMark.of(day, now: now)
        }

        let currentInterval = AnkerCalendar.weekInterval(containing: now)
        return WeekRow(
            id: interval.monday,
            monday: interval.monday,
            isoWeek: interval.isoWeek,
            isoYear: interval.isoYear,
            marks: marks,
            openCount: days.flatMap(\.taskList).filter { !$0.isDone }.count,
            isCurrent: AnkerCalendar.isSameDay(interval.monday, currentInterval.monday),
            isPast: interval.monday < currentInterval.monday,
            exists: week != nil
        )
    }
}
