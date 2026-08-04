import SwiftUI

/// Icons des Modernist-Systems: Lucide, mitgeliefert als SVG im Asset-Katalog.
///
/// In Views steht die **Rolle**, nie der Dateiname — sonst wandert eine Glyphenentscheidung in
/// 74 Aufrufstellen. Bewusst ein `struct` und kein `enum` mit Rohwerten: mehrere Rollen teilen
/// sich zu Recht eine Glyphe (`today` und `appearanceLight` sind beide die Sonne), und ein
/// `enum` erlaubt keine doppelten Rohwerte.
///
/// Die Dateinamen behalten die Schreibweise von Lucide, damit ein Versionswechsel ein `diff`
/// bleibt. Die mitgelieferten Kopien sind auf `stroke-linecap="square"` und
/// `stroke-linejoin="miter"` gezogen und ihre `rx`-Rundungen entfernt: das Systemblatt
/// verbietet runde Ecken, und das Entwurfsdokument zeichnet seine eigenen Haken ebenfalls mit
/// eckigen Enden. Die ISC-Lizenz erlaubt die Aenderung; sie liegt als `Lucide-LICENSE.txt` bei.
struct AnkerIcon: Sendable, Hashable {
    let assetName: String

    private init(_ assetName: String) {
        self.assetName = assetName
    }

    var image: Image {
        Image(assetName).renderingMode(.template)
    }

    // MARK: - Navigation

    static let today = AnkerIcon("lucide-sun")
    static let week = AnkerIcon("lucide-calendar")
    static let year = AnkerIcon("lucide-layout-grid")
    static let more = AnkerIcon("lucide-ellipsis")
    static let chevronLeft = AnkerIcon("lucide-chevron-left")
    static let chevronRight = AnkerIcon("lucide-chevron-right")
    static let chevronDown = AnkerIcon("lucide-chevron-down")

    // MARK: - Aufgaben und Ziele

    static let add = AnkerIcon("lucide-plus")
    static let addCircle = AnkerIcon("lucide-circle-plus")
    static let goal = AnkerIcon("lucide-target")
    static let check = AnkerIcon("lucide-check")
    static let checkCircle = AnkerIcon("lucide-circle-check")
    static let checkCircleLarge = AnkerIcon("lucide-circle-check-big")
    static let open = AnkerIcon("lucide-circle")
    static let delete = AnkerIcon("lucide-trash-2")
    static let edit = AnkerIcon("lucide-pencil")
    static let duplicate = AnkerIcon("lucide-copy")
    static let move = AnkerIcon("lucide-move-right")
    static let undo = AnkerIcon("lucide-undo-2")
    static let priority = AnkerIcon("lucide-flag")
    static let clear = AnkerIcon("lucide-x")

    // MARK: - Zeit

    static let nextMonth = AnkerIcon("lucide-calendar-plus")
    static let previousMonth = AnkerIcon("lucide-calendar-minus")
    static let pickDate = AnkerIcon("lucide-calendar-clock")
    static let tomorrow = AnkerIcon("lucide-sunrise")
    static let time = AnkerIcon("lucide-clock")

    // MARK: - App

    static let search = AnkerIcon("lucide-search")
    static let settings = AnkerIcon("lucide-settings")
    static let privacy = AnkerIcon("lucide-shield-check")
    static let note = AnkerIcon("lucide-file-text")
    /// Das Archiv als eigener Ort. Radius aus dem Original entfernt — `rx="1"` waere die
    /// einzige gerundete Ecke der App gewesen.
    static let archive = AnkerIcon("lucide-archive")
    static let share = AnkerIcon("lucide-share-2")
    static let appearanceLight = AnkerIcon("lucide-sun")
    static let appearanceDark = AnkerIcon("lucide-moon")
    static let appearanceSystem = AnkerIcon("lucide-contrast")

    // MARK: - iCloud

    static let cloud = AnkerIcon("lucide-cloud")
    static let cloudSynced = AnkerIcon("lucide-cloud-check")
    static let cloudUploading = AnkerIcon("lucide-cloud-upload")
    static let cloudOff = AnkerIcon("lucide-cloud-off")
    static let refresh = AnkerIcon("lucide-refresh-cw")

    // MARK: - Hinweise

    static let warning = AnkerIcon("lucide-triangle-alert")
    static let info = AnkerIcon("lucide-circle-alert")

    /// Fuer die Designsystem-Galerie und den Test, der prueft, dass jedes Asset existiert.
    static let all: [AnkerIcon] = [
        today, week, year, more, chevronLeft, chevronRight, chevronDown,
        add, addCircle, goal, check, checkCircle, checkCircleLarge, open,
        delete, edit, duplicate, move, undo, priority, clear,
        nextMonth, previousMonth, pickDate, tomorrow, time,
        search, settings, privacy, note, archive, share,
        appearanceLight, appearanceDark, appearanceSystem,
        cloud, cloudSynced, cloudUploading, cloudOff, refresh,
        warning, info,
    ]
}

/// Icongroessen. Eigene Skala, weil ein SVG aus dem Asset-Katalog in seiner Eigengroesse von
/// 24pt rendert und `.font(.system(size:))` **nicht** beachtet — anders als ein SF Symbol.
/// Deshalb braucht jede Aufrufstelle eine ausdrueckliche Groesse.
enum AnkerIconSize {
    /// Kleinste sinnvolle Groesse. Nicht kleiner: die 2px-Striche von Lucide werden darunter
    /// duenner als ein Pixel und wirken auf nicht-Retina-Bildschirmen matschig.
    static let xs: CGFloat = 14
    static let s: CGFloat = 16
    static let m: CGFloat = 20
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

extension Image {
    init(_ icon: AnkerIcon) {
        self = icon.image
    }

    /// Icon in der gewuenschten Groesse, seitenverhaeltnistreu.
    func ankerIcon(_ size: CGFloat = AnkerIconSize.s) -> some View {
        resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

extension Label where Title == Text, Icon == AnkerIconImage {
    /// Der Ersatz fuer `Label(_, systemImage:)`.
    ///
    /// Bewusst weiter ein `Label` und keine eigene `HStack`: in Menues, Wischaktionen und
    /// Werkzeugleisten richtet SwiftUI Icon und Titel selbst aus und beachtet `labelStyle`.
    /// Das Icon kommt in fester Groesse, weil ein SVG aus dem Katalog sonst in seinen
    /// natuerlichen 24pt rendert und Menuezeilen aufblaeht.
    init(_ titleKey: LocalizedStringKey, ankerIcon: AnkerIcon, size: CGFloat = AnkerIconSize.s) {
        self.init {
            Text(titleKey)
        } icon: {
            AnkerIconImage(icon: ankerIcon, size: size)
        }
    }

    /// Fuer Titel, die zur Laufzeit entstehen (etwa ein formatiertes Datum).
    init(verbatim title: String, ankerIcon: AnkerIcon, size: CGFloat = AnkerIconSize.s) {
        self.init {
            Text(verbatim: title)
        } icon: {
            AnkerIconImage(icon: ankerIcon, size: size)
        }
    }
}

/// Das Icon als eigener Typ, damit die `Label`-Erweiterung oben einen benennbaren
/// `Icon`-Typ hat.
struct AnkerIconImage: View {
    let icon: AnkerIcon
    var size: CGFloat = AnkerIconSize.s

    var body: some View {
        Image(icon).ankerIcon(size)
    }
}

/// Beschriftung mit Icon — der Ersatz fuer `Label(_, systemImage:)`.
///
/// Icon davor, Beschriftung dahinter, beides buendig links: das Systemblatt verlangt
/// flush-left auch innerhalb breiter Schaltflaechen.
struct AnkerLabel: View {
    let title: LocalizedStringKey
    let icon: AnkerIcon
    var size: CGFloat = AnkerIconSize.s
    var style: AnkerTextStyle = AnkerType.label

    init(
        _ title: LocalizedStringKey,
        icon: AnkerIcon,
        size: CGFloat = AnkerIconSize.s,
        style: AnkerTextStyle = AnkerType.label
    ) {
        self.title = title
        self.icon = icon
        self.size = size
        self.style = style
    }

    var body: some View {
        HStack(spacing: AnkerSpacing.s2) {
            AnkerIconImage(icon: icon, size: size)
            Text(title).ankerType(style)
        }
    }
}
