# Coding-Prompt: Anker — Migration auf Designsystem v2 (Liquid Glass)

Kopiere diesen Prompt in Claude Code. Er setzt voraus, dass das Projekt aus dem ersten Coding-Prompt bereits existiert (Datenmodell, Architektur, 9 Screens im alten flachen Design). Hier geht es **nur um die Migration der UI-Schicht**, nicht um einen Neubau — Datenmodell, SwiftData/CloudKit-Setup, EventKit-Anbindung, Navigationsstruktur und App-Intents bleiben unverändert.

---

## 1. Rolle & Auftrag

Du bist derselbe Apple-Platform-Engineer wie zuvor. Die App „Anker" ist bereits mit dem alten, flachen Designsystem (v1) implementiert. Das visuelle Design wurde seither überarbeitet: **Designsystem v2** bringt Liquid Glass (iOS 26 / iPadOS 26 / macOS Tahoe 26) auf die Navigationsebene und korrigiert mehrere WCAG-Kontrastfehler aus v1.

**Wichtigste Leitregel der Migration, die während der gesamten Arbeit gilt:**
Liquid Glass gehört ausschließlich auf die **Navigationsebene** — Leisten, Sidebar, Popover, Tab-Leiste, schwebende Buttons. Die **Inhaltsebene** (Aufgabenkarten, Zielkarten, Wochenraster, Monatskacheln) bleibt matt/opak. Verglase niemals Inhalt, nur Chrome — das war schon in v1 für den Content-Bereich zufällig richtig, ändere daran nichts.

---

## 2. Referenz-Datei öffnen

Die verbindliche visuelle Referenz ist die Datei **`Anker_Design_System_v2.html`** (liegt im Projekt-Root bzw. wurde dieser Konversation als Anhang beigefügt — falls nicht vorhanden, bitte nachfragen statt zu raten). Öffne sie im Browser oder lies den Quelltext direkt:

- Sie enthält **alle 9 Screens** im neuen Design, mit einem Light/Dark-Umschalter oben rechts (rein CSS-Variablen-getrieben — beide Modi im selben Dokument, keine doppelten Screens).
- Alle Werte (Farben, Radien, Blur-Stärken, Abstände) darin sind final. Nutze das Dokument als Ground Truth für alles, was in Abschnitt 3–4 nicht explizit als Zahl genannt ist.
- Falls dir Bildschirm-Rendering zur Verfügung steht: rendere die Datei einmal in Light und einmal in Dark (Klick auf den Umschalter oben rechts) und vergleiche dein SwiftUI-Ergebnis Screen für Screen dagegen.

---

## 3. Was sich konkret ändert (Delta zu v1)

| Bereich | v1 (bereits im Code) | v2 (Zielzustand) |
|---|---|---|
| Sidebar (iPad/Mac) | Solide Fläche `#EFEFF4`, harte rechte Trennlinie | Vibrantes, transluzentes Material (`.ultraThinMaterial`/`.regularMaterial`), Trennung über weichen Schattenverlauf statt 1px-Linie |
| Kontextleiste („Index · KW ◀ ▶") | Karten mit hartem Rand | Schwebende Glas-Pillen (`Capsule().fill(.thinMaterial)`) |
| Titelleiste + Sidebar (Mac) | Getrennte Flächen | Zu einer **vereinten Werkzeugleiste** verschmolzen (`.toolbarBackground(.visible)` mit Material) |
| FAB (iPhone) | Flacher Indigo-Kreis | Lichtbrechendes Glas-Element mit Specular-Highlight (Gradient + `.ultraThinMaterial` überlagert) |
| Tab-Leiste (iPhone) | **Fehlte komplett** — Navigation nur implizit per Wisch-Geste | Neu: schwebende Glas-Tab-Leiste (Heute / Woche / Jahr / Mehr), soll sich beim Scrollen analog zum System-Verhalten verkleinern |
| Menüleisten-Popover (macOS) | Flaches Weiß | Bekommt Glas-Material automatisch, wenn `MenuBarExtra(.window)`/`NSPopover` mit Standard-Material genutzt wird — im Code ggf. explizites `.background(.regularMaterial)` ergänzen |
| Home-Screen-Widget | Reine Anzeige | Checkbox im Widget wird **antippbar** (Button mit App Intent, `AppIntent`-Target in der Widget-Extension), Aufgabe lässt sich ohne App-Öffnung abhaken |
| Dark Mode | Nicht spezifiziert | Vollständiges Pendant, siehe Abschnitt 4 |
| Monatskachel-Text | Sekundärzeile in hellerem Grau geplant | **Korrektur:** Sekundärzeile nutzt dieselbe Ink-Farbe wie die Hauptzeile, Hierarchie über 72 % Deckkraft + kleinere Schrift — ein hellerer Grauton bestand den Kontrast-Check bei mehreren Monatsfarben nicht (siehe Abschnitt 5) |
| Widgets/Watch | — | Bleiben unverändert — Widgets liegen immer auf dem Wallpaper des Nutzers, Watch ist aus Energiegründen immer OLED-Schwarz; für beide ergibt eine App-eigene Dark/Light-Umschaltung keinen Sinn |

Screens, die **nicht** in der Tabelle stehen (Ziel-Detail, Wochenrückblick, Onboarding), bekommen dieselbe Chrome-Behandlung wie Sidebar/Kontextleiste/Tab-Leiste oben — schau dir dafür die entsprechenden Abschnitte in der Referenz-Datei an.

---

## 4. Dark Mode — verbindliche Farbtokens

Ergänze in `Theme.swift` ein Dark-Mode-Pendant pro Token (per `Color(light:dark:)`-Hilfsfunktion oder Asset-Catalog-Farbsets mit Appearance-Varianten — nicht per `#if` verzweigen, das System soll automatisch umschalten):

```swift
extension Color {
    /// Hilfsinitializer für Light/Dark-Value-Pairs
    init(light: String, dark: String) {
        self = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum AnkerColor {
    static let appBackground = Color(light: "#F7F7FA", dark: "#111219")
    static let surface       = Color(light: "#FFFFFF", dark: "#1C1D24")
    static let surfaceRaised = Color(light: "#FFFFFF", dark: "#23242D")
    static let line          = Color(light: "#E4E5EA", dark: "#FFFFFF1F") // ~12% weiß
    static let lineSoft      = Color(light: "#EDEEF2", dark: "#FFFFFF12") // ~7% weiß
    static let textStrong    = Color(light: "#1C1E27", dark: "#F2F2F7")
    static let textSoft      = Color(light: "#8A8D98", dark: "#A6A9B5")

    // Kontrastkorrigierte Tokens (siehe Abschnitt 5) — in beiden Modi identisch,
    // AUSSER indigoText, das in Dark Mode aufgehellt werden muss:
    static let indigo        = Color(hex: "#5B6EE8")            // dekorativ (Ringe, Punkte), NICHT für Text
    static let indigoBadge   = Color(hex: "#4D61E6")            // Hintergrund für weißen Text (Prio-B, aktive Zustände)
    static let indigoText    = Color(light: "#3F4FBF", dark: "#90A0F5") // Text/Links auf Oberfläche
    static let brass         = Color(light: "#C9974B", dark: "#E0BC85")
    static let successIcon   = Color(hex: "#2A9F47")            // Hintergrund für weißes Häkchen-Icon
    static let prioA         = Color(hex: "#D93327")             // Hintergrund für weißen "A"-Badge-Text
    static let prioC         = Color(hex: "#6E7180")
}
```

Glas-Chrome-Elemente (Sidebar, Leisten, Popover, Tab-Leiste, FAB) verwenden **native SwiftUI-Materialien** (`.ultraThinMaterial`, `.regularMaterial`, `.thinMaterial`) statt eigener Farb-Tokens — diese passen sich automatisch an Light/Dark und an den Hintergrundinhalt an, das ist der ganze Sinn von Liquid Glass. Baue keine eigene Blur-Implementierung.

---

## 5. Kontrast-Korrekturen — verbindlich übernehmen

Drei Farbwerte aus v1 bestanden die WCAG-AA-Prüfung nicht und wurden korrigiert. Übernimm die korrigierten Werte unverändert, nicht die ursprünglichen:

| Verwendung | Alt (v1, fehlerhaft) | Kontrast alt | Neu (v2, korrigiert) | Kontrast neu |
|---|---|---|---|---|
| Weißer Text auf Prio-B-Badge | `#5B6EE8` | 4,34 (Soll 4,5) | `#4D61E6` (`indigoBadge`) | 5,04 |
| Weißes Häkchen-Icon auf Erfolgs-Grün | `#34C759` | 2,22 (Soll 3,0 für Icons) | `#2A9F47` (`successIcon`) | 3,42 |
| Weißer Text auf Prio-A-Badge | `#E0574D` | 3,72 (Soll 4,5) | `#D93327` (`prioA`) | 4,72 |
| `indigoText` in Dark Mode | `#3F4FBF` unverändert | 2,46 (Soll 4,5) | `#90A0F5` | 6,82 |

Zusätzlich: Der ursprünglich für Monatskachel-Sekundärtext vorgesehene hellere Grauton bestand bei mehreren Monatsfarben (u. a. Januar, August) den Kontrast nicht. **Fix bereits in Abschnitt 3 beschrieben** (Ink-Farbe + Deckkraft statt hellerer Grauton).

Prüfe bei jeder weiteren Farbkombination, die du im Verlauf der Migration neu einführst, selbst gegen 4,5:1 (Text) bzw. 3:1 (Icons/große Schrift) — nutze dafür z. B. ein Contrast-Checker-Tool oder rechne die WCAG-Formel direkt in einem Test.

---

## 6. Migrationsreihenfolge

Gehe screenweise vor, in dieser Reihenfolge, und baue nach jedem Screen kurz — nicht das ganze Design auf einmal umstellen:

1. `Theme.swift` um Dark-Mode-Pendants und korrigierte Tokens ergänzen (Abschnitt 4–5) — Kompilieren prüfen, noch keine visuelle Änderung nötig
2. `TodayView` (iPhone): Glas-Navbar, Glas-Tab-Leiste (neu!), Glas-FAB
3. `WeekOverviewView` + `SidebarView` (iPad/Mac): vibrante Sidebar, vereinte Werkzeugleiste, Glas-Kontextchips
4. `QuickCapturePopover` (macOS): Material-Hintergrund für Popover sicherstellen
5. `YearOverviewView` (Mac): Toolbar/Sidebar-Glas, Monatskachel-Textfix
6. `WeeklyReviewView`, `GoalDetailView`, `OnboardingView`: gleiche Chrome-Behandlung wie Punkt 2–3
7. `TodayFocusWidget`: Checkbox interaktiv machen (App Intent statt reiner Anzeige)
8. Watch-Target: unverändert lassen, nur gegenprüfen, dass nichts versehentlich mitgeändert wurde

Bestätige nach jedem Punkt kurz, was fertig ist, bevor du weitermachst. Wenn eine Plattform-Priorität nicht klar ist, frage nach, statt anzunehmen.

---

## 7. Abnahmekriterien (ergänzend zu v1)

- [ ] Alle 9 Screens entsprechen visuell `Anker_Design_System_v2.html` (Light **und** Dark, per Umschalter in der Referenz-Datei vergleichbar)
- [ ] Kein Content-Element (Aufgabenkarte, Zielkarte, Kachel) ist verglast — nur Chrome
- [ ] Home-Screen-Widget: Aufgabe lässt sich direkt antippen und abhaken, ohne die App zu öffnen
- [ ] Alle drei korrigierten Kontrast-Tokens aus Abschnitt 5 sind übernommen, nicht die ursprünglichen v1-Werte
- [ ] Dark Mode nutzt native Materialien für Chrome und die in Abschnitt 4 definierten Farb-Tokens für Inhalt — keine hartkodierten Farben, die im Dunkelmodus falsch aussehen
- [ ] `indigoText` ist in Dark Mode sichtbar heller als in Light Mode (Verwechslungsgefahr mit v1-Wert sonst hoch)
