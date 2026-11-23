import Foundation

/// Reine Kalenderrechnung ohne Zustand — deshalb `nonisolated`: sie wird auch aus
/// nicht-isolierten Helfern (`TaskActions.isCarryOver`) und Sortierprädikaten gerufen.
nonisolated enum AnkerCalendar {
    /// Ein einziges `Calendar` fuer den ganzen Prozess.
    ///
    /// Vorher eine berechnete `static var`, die bei jedem Zugriff ein neues `Calendar` baute —
    /// in Schleifen und Sortierpraedikaten also hunderte Male pro Durchlauf.
    ///
    /// `TimeZone.current` wird dabei einmal festgeschrieben. Das ist gewollt: dieselbe Woche
    /// soll innerhalb einer Sitzung nicht ihre Grenzen wechseln. Reist der Nutzer ueber eine
    /// Zeitzonengrenze, gilt die neue Zone ab dem naechsten Start; `StoreMaintenance` rechnet
    /// deshalb bewusst mit den ISO-Feldern statt mit `monday`.
    static let iso: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }()

    static func weekInterval(containing date: Date, calendar: Calendar = iso) -> (monday: Date, sunday: Date, isoYear: Int, isoWeek: Int) {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let monday = calendar.date(from: components) ?? date
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday

        return (
            monday: calendar.startOfDay(for: monday),
            sunday: calendar.startOfDay(for: sunday),
            isoYear: components.yearForWeekOfYear ?? calendar.component(.year, from: date),
            isoWeek: components.weekOfYear ?? calendar.component(.weekOfYear, from: date)
        )
    }

    static func daysInWeek(starting monday: Date, calendar: Calendar = iso) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    static func date(year: Int, month: Int, day: Int, hour: Int = 9, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = iso
        components.timeZone = .current
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return components.date ?? Date()
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = iso) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    /// 52 oder 53. Der 28. Dezember liegt nach ISO immer in der letzten Woche des Jahres.
    static func weeksInISOYear(_ isoYear: Int) -> Int {
        weekInterval(containing: date(year: isoYear, month: 12, day: 28)).isoWeek
    }

    /// Stabiler Wochenschluessel.
    ///
    /// Ueber die ISO-Felder statt ueber `monday`: `AnkerCalendar` rechnet mit `TimeZone.current`,
    /// dieselbe Woche hat auf Geraeten in verschiedenen Zeitzonen unterschiedliche `Date`-Werte.
    struct WeekKey: Hashable, Comparable {
        let isoYear: Int
        let isoWeek: Int

        static func < (lhs: WeekKey, rhs: WeekKey) -> Bool {
            (lhs.isoYear, lhs.isoWeek) < (rhs.isoYear, rhs.isoWeek)
        }

        /// Die Woche danach — über den Jahreswechsel hinweg: auf KW 52 bzw. 53 folgt KW 1.
        var next: WeekKey {
            isoWeek < AnkerCalendar.weeksInISOYear(isoYear)
                ? WeekKey(isoYear: isoYear, isoWeek: isoWeek + 1)
                : WeekKey(isoYear: isoYear + 1, isoWeek: 1)
        }
    }

    static func weekKey(containing date: Date) -> WeekKey {
        let interval = weekInterval(containing: date)
        return WeekKey(isoYear: interval.isoYear, isoWeek: interval.isoWeek)
    }

    // MARK: - Gespeicherte Tage über Zeitzonen hinweg

    /// Der Kalendertag, den ein **gespeichertes** Tagesdatum meint.
    ///
    /// `Day.date` ist Mitternacht in der Zeitzone des Geräts, das den Tag angelegt hat. Auf
    /// einem Gerät in einer westlicheren Zone ist derselbe Zeitpunkt noch der Vorabend —
    /// `isSameDay` ordnete den Montag dort dem Sonntag zu, und das Zusammenführen legte
    /// fremde Tage aufeinander. Zwölf Stunden Versatz landen für jede Zonendifferenz unter
    /// zwölf Stunden sicher in der Tagesmitte des gemeinten Tages.
    ///
    /// Nur für gespeicherte Tagesdaten verwenden, nie für „jetzt" — 13 Uhr plus zwölf Stunden
    /// ist morgen.
    static func nominalDay(ofStored date: Date, calendar: Calendar = iso) -> DateComponents {
        let middle = date.addingTimeInterval(12 * 60 * 60)
        return calendar.dateComponents([.year, .month, .day], from: middle)
    }

    /// Der gemeinte Kalendertag eines gespeicherten Tagesdatums als Mitternacht in **dieser**
    /// Zone — der Ausgangspunkt für jede Rechnung („eine Woche später", „zwei Tage früher").
    ///
    /// `date(byAdding:)` direkt auf `Day.date` übernimmt den Zonenversatz des anlegenden
    /// Geräts: ein Montag aus Tokio ist in Berlin Sonntag 16 Uhr, eine Woche später wieder
    /// Sonntag — und die Aufgabe landete einen Tag zu früh.
    static func nominalDate(ofStored date: Date, calendar: Calendar = iso) -> Date {
        calendar.date(from: nominalDay(ofStored: date, calendar: calendar)) ?? calendar.startOfDay(for: date)
    }

    /// Meint das gespeicherte Tagesdatum `stored` den Kalendertag von `date`?
    static func storedDay(_ stored: Date, isOn date: Date, calendar: Calendar = iso) -> Bool {
        let target = calendar.dateComponents([.year, .month, .day], from: date)
        let nominal = nominalDay(ofStored: stored, calendar: calendar)
        return nominal.year == target.year && nominal.month == target.month && nominal.day == target.day
    }

    /// Die Woche, in die ein gespeichertes Tagesdatum gehört — für verwaiste Tage aus dem Sync.
    static func weekKey(ofStored date: Date) -> WeekKey {
        weekKey(containing: date.addingTimeInterval(12 * 60 * 60))
    }
}

/// Alle Datums- und Zeitformate der Oberflaeche an einer Stelle.
///
/// Vorher lagen `shortDate`, `dayLabel` und Varianten mehrfach in `TaskEditing`,
/// `OverviewViews`, `DayDetailView`, `TodayView` und `DetailAndCaptureViews` — jeweils mit
/// eigener, leicht abweichender Implementierung. Gleiche Angabe, unterschiedliche Schreibweise
/// je Bildschirm.
///
/// Bewusst keine `Locale`-Angabe: die Formate folgen der Regionseinstellung des Nutzers.
enum AnkerDateFormat {

    // MARK: - Tag

    /// `Mo`, `Di` — ohne Punkt, fuer die schmalen Tagesauswahl-Buttons.
    static func weekdayShort(_ date: Date) -> String {
        // Die deutsche Abkuerzung kommt als "Mo."; in den 34 Punkt breiten Buttons stoert
        // der Punkt, und in anderen Regionen faellt der `replacing`-Aufruf einfach aus.
        date.formatted(.dateTime.weekday(.abbreviated)).replacing(".", with: "")
    }

    /// `Montag`
    static func weekdayLong(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide))
    }

    /// `01`
    static func dayNumber(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits))
    }

    /// `03.08.` — Tag und Monat ohne Jahr, fuer Wochenspannen und Verschiebe-Dialoge.
    static func dayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits))
    }

    /// `03.08.2026`
    static func dayMonthYear(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
    }

    /// `Mo 03.08.` — Kopfzeilen von Tageskarten und Suchtreffern.
    static func weekdayShortWithDayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day(.twoDigits).month(.twoDigits))
    }

    /// `Do, 26.11.` — knapp und mit Datum, für die Hinweiszeile der Erfassung. Ein Datum dort
    /// kann in eine andere Woche zeigen; der Wochentag allein sagte dann zu wenig.
    static func weekdayShortCommaDayMonth(_ date: Date) -> String {
        "\(weekdayShort(date)), \(dayMonth(date))"
    }

    /// `Montag, 3. August` — die ausgeschriebene Form fuer Titel und Accessibility-Labels.
    static func weekdayLongWithDayMonth(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month())
    }

    /// `Montag, 03.08.` — wie oben, aber mit numerischem Datum. Steht in Listen neben
    /// monospaced Zahlen, wo der ausgeschriebene Monat die Spaltenbreite sprengen wuerde.
    static func weekdayLongWithDayMonthNumeric(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day(.twoDigits).month(.twoDigits))
    }

    /// `August`
    static func monthLong(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide))
    }

    // MARK: - Uhrzeit

    /// `09:30` — im Zeitplan, deshalb immer zweistellig und ohne AM/PM.
    static func timeOfDay(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// `9:30` in der Regionsschreibweise — fuer Statustexte, wo die Uhrzeit im Satz steht.
    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    // MARK: - Woche

    /// `KW 32` — zweistellig, damit die Breite in Listen nicht springt.
    static func calendarWeek(_ isoWeek: Int) -> String {
        let number = String(format: "%02d", isoWeek)
        // Englisch: „Week 48". Die ISO-Woche ist dort weniger geläufig als „KW" im Deutschen,
        // aber als Wort verständlich.
        return String(localized: "KW \(number)", comment: "Kalenderwoche, z. B. „KW 48“")
    }

    /// `03.08.–09.08.2026`, auf Englisch `Aug 3 – 9, 2026`.
    ///
    /// Deutsch bleibt bei der numerischen Schreibweise, die das Blatt von Anfang an trägt.
    /// Im Englischen ist „08/03–08/09/2026" je nach Region doppeldeutig (Monat oder Tag zuerst),
    /// deshalb dort die ausgeschriebene Spanne des Systems.
    static func weekSpan(monday: Date, sunday: Date) -> String {
        if AppLanguage.isGermanActive {
            return "\(dayMonth(monday))–\(dayMonthYear(sunday))"
        }
        return (monday..<sunday).formatted(.interval.day().month(.abbreviated).year())
    }
}

extension String {
    /// Leerer Text ist keine Angabe. Spart an einem Dutzend Stellen ein
    /// `trimmingCharacters(...).isEmpty ? nil : text`.
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
