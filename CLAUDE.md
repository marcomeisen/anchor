# Daivento (Repo-Name: `anchor`)

Multiplattform-SwiftUI-App (iPhone / iPad / Mac) für Wochenplanung: max. 4 Wochenziele („Anker")
pro Woche, an die Aufgaben verankert werden. Persistenz über SwiftData mit CloudKit-Sync.

Seit dem Neuentwurf *Modernist* (2026-08-04) ist **das Datenmodell die Oberfläche**: 4 Anker × 7 Tage
als ein sichtbares Raster, nicht als Kalenderabbild. Diese Struktur gilt unverändert.

Das **Material** dagegen ist seit dem Reskin *Lot* (2026-08-16) ein anderes: warme Neutralen statt
Blaugrau, Bernstein statt Rot, **Rost nur für Rückstand**, weiche Radien und Höhe statt 2px-Linien,
Glas für Chrome, San Francisco statt Archivo. Der Rückblick wechselt in den **Ritual-Modus** —
dunkel, Instrument Serif, kein Chrome. „Nähe entsteht durch Material und Höhe, nicht durch Rahmen."
[Scripts/design-guard.swift](Scripts/design-guard.swift) hält diese Regeln als Schranke fest.

Die zweite Entwurfsrunde (2026-08-04, *Mac Sidebar*, Variante **2a „Zeitschiene"**) hat die Rollen
getrennt: **die Sidebar beantwortet nur noch „wann"**. Der Ansichtswechsel Heute/Woche/Jahr ist ein
Modus des Inhalts und sitzt in `AnkerContentHeader`; die Anker sind Inhalt und stehen als Streifen
darüber. Es gibt genau **einen** Zeitnavigator — Stepper plus „Heute" — und vergangene Wochen leben
im Archiv statt in einem permanenten Baum.

**Sprache:** Alle sichtbaren UI-Texte, Commits, Changelog-Einträge und Doku sind auf Deutsch.
Code-Identifier sind Englisch.

## Struktur

| Datei | Inhalt |
|---|---|
| **Rahmen** | |
| [Anchor/AnchorApp.swift](Anchor/AnchorApp.swift) | `@main`, `AnkerStore`, `CloudSyncConfiguration`, macOS-Statusbar-Popover und Einstellungen-Szene, `UITestMode` |
| [Anchor/ContentView.swift](Anchor/ContentView.swift) | Wurzel-View: Farbmodus, Fehlerdialog, `PreviewContainer` |
| **Modell und Logik** (keine Views) | |
| [Anchor/Models.swift](Anchor/Models.swift) | `@Model`: `Goal`, `Week`, `Day`, `AnkerTask`, `TimeBlock`; `Priority`; `AnkerSchema.models` |
| [Anchor/TaskActions.swift](Anchor/TaskActions.swift) | `TaskActions` (**die** Mutations-Schicht für Aufgaben), `TaskSnapshot`/Undo, `TaskUndoCoordinator` |
| [Anchor/GoalEditing.swift](Anchor/GoalEditing.swift) | `GoalActions` — Wochenziele löschen, Aufgaben bleiben erhalten; `goalDeleteConfirmation` |
| [Anchor/WeekPlanning.swift](Anchor/WeekPlanning.swift) | Wochen und Tage auflösen, `needsOnboarding`/`hasContent`, erste Anker — ohne View, deshalb testbar |
| [Anchor/AppNavigation.swift](Anchor/AppNavigation.swift) | `AppDestination`, `AnkerNavigationState`: Sprünge, `@SceneStorage`-Wiederherstellung, `daivento://`-Deep-Links |
| [Anchor/Persistence.swift](Anchor/Persistence.swift) | `ModelContext.saveChanges()` — **statt** `try? save()`; `PersistenceFailureCenter`, Fehlerdialog |
| [Anchor/StoreMaintenance.swift](Anchor/StoreMaintenance.swift) | Zusammenführen von Wochen/Tagen aus dem Sync, mit `MergeReport` und Protokoll |
| [Anchor/Search.swift](Anchor/Search.swift) | `AnkerSearch` über Aufgaben, Ziele, Notizen, Tagesfokus, Zeitblöcke; `SearchResultsList`, `SearchSheet` |
| [Anchor/DataPortability.swift](Anchor/DataPortability.swift) | JSON-Export und vollständige Löschung (DSGVO Art. 15, 17, 20) |
| [Anchor/AppSettings.swift](Anchor/AppSettings.swift) | `AppearanceMode` (Farbmodus), `CloudSyncPreference` (Sync ein/aus, greift erst beim Neustart) |
| [Anchor/CalendarLogic.swift](Anchor/CalendarLogic.swift) | `AnkerCalendar` — **immer** ISO-8601, nie `Calendar.current`; `AnkerDateFormat` — **alle** Datumsformate |
| [Anchor/CaptureSyntax.swift](Anchor/CaptureSyntax.swift) | Erfassungssyntax `!a` / `#2` / `mo…so` — reiner Parser, `CaptureInput`, `CaptureTarget`, Hinweistext |
| [Anchor/GoalOrdering.swift](Anchor/GoalOrdering.swift) | Ankernummer 1–4 aus `Goal.order`, Überschuss, Normalisierung — **nie** über `week.goalList` sortieren |
| [Anchor/WeekActions.swift](Anchor/WeekActions.swift) | Woche schließen/öffnen, Rückblickantwort, `ReviewReadiness` (grau bis Sonntag), `CarryDecision` pro Aufgabe |
| [Anchor/AnkerStatistics.swift](Anchor/AnkerStatistics.swift) | Alle Kennzahlen und Aussagen: Serie, gehaltene Anker, stärkster Tag, Tempo-Prognose, Jahresband |
| [Anchor/AnkerMatrix.swift](Anchor/AnkerMatrix.swift) | Zeilen und Maße der Anker-Matrix, Kopfzeilentexte — ohne View |
| [Anchor/SidebarTimeline.swift](Anchor/SidebarTimeline.swift) | Zeitschiene: Wochenzeile mit sieben Tagesquadraten (`DayMark`) — „nichts geplant" ≠ „nichts geschafft" |
| [Anchor/AnkerArchive.swift](Anchor/AnkerArchive.swift) | Archivierte Wochen: geschlossen **oder** vergangen, mit Kennzahlen pro Woche |
| **Designtokens** (dürfen die Grundbausteine benutzen, alles andere nicht) | |
| [Anchor/Theme.swift](Anchor/Theme.swift) | `AnkerColor` (15 Lot-Tokens, Bernstein, Rost, `Ritual`, Glas), `AnkerElevation`, `AnkerSpacing`, `AnkerBorder`, `AnkerRadius` — **keine** Hex-Werte in Views |
| [Anchor/ThemeType.swift](Anchor/ThemeType.swift) | `AnkerType` — 22 Typo-Tokens mit Familie, Größe, Gewicht, Laufweite, Großschreibung; `.ankerType(_:)` |
| [Anchor/ThemeFont.swift](Anchor/ThemeFont.swift) | Die zwei Familien: San Francisco für die Arbeitsfläche, Instrument Serif fürs Ritual |
| [Anchor/ThemeIcon.swift](Anchor/ThemeIcon.swift) | `AnkerIcon` (Lucide), `AnkerIconSize`, `AnkerLabel` |
| [Anchor/ThemeSurfaces.swift](Anchor/ThemeSurfaces.swift) | `AnkerRule` (`.section`/`.row`), die sechs Flächen-Idiome `ankerCard()` / `ankerGlass()` / `ankerField()` / `ankerControl()` / `ankerPill()` / `ankerPanel()`, `ankerElevation(_:)`, `AnkerProgressBar`, `AnkerButtonStyle`, `AnkerToggleStyle` |
| [Anchor/SampleData.swift](Anchor/SampleData.swift) | Beispieldaten, nur für Previews und Tests |
| **Views** | |
| [Anchor/AnkerRootView.swift](Anchor/AnkerRootView.swift) | Verteilt auf Onboarding, Split-Layout und iPhone-Layout; hält den Navigationszustand |
| [Anchor/SidebarView.swift](Anchor/SidebarView.swift) | Sidebar (Mac, iPad) — **nur Zeit**: Suche, ein Stepper, Wochenzeilen, Fuß mit Rückblick/Archiv/Einstellungen |
| [Anchor/AnchorStripView.swift](Anchor/AnchorStripView.swift) | `AnkerContentHeader` (Ansichtswechsel, Woche, Tag), `AnkerViewSwitcher`, `AnchorStripView` — die Anker als Streifen |
| [Anchor/AnkerMatrixView.swift](Anchor/AnkerMatrixView.swift) | Anker-Matrix (Mac, iPad): Zeile = Anker, Spalte = Tag; Ziehen setzt Ziel **und** Tag |
| [Anchor/ArchiveView.swift](Anchor/ArchiveView.swift) | Archiv: abgeschlossene Wochen, neueste zuerst |
| [Anchor/WeekOverviewView.swift](Anchor/WeekOverviewView.swift) | Wochenübersicht des iPhones: sieben Tageszeilen mit Aufgaben-Chips |
| [Anchor/YearOverviewView.swift](Anchor/YearOverviewView.swift) | Jahresband: ein Balken pro ISO-Woche plus vier Kennzahlen |
| [Anchor/CaptureBarView.swift](Anchor/CaptureBarView.swift) | Erfassungszeile: tippen, Enter, fertig — mit aufgelöster Hinweiszeile |
| [Anchor/TodayView.swift](Anchor/TodayView.swift) | iPhone-Heute-Screen, Undo-Toast, Mehrfachauswahl |
| [Anchor/DayDetailView.swift](Anchor/DayDetailView.swift) | Tagesdetailansicht: Kennzahlen, Tagesfokus, Ziele, Zeitplan, Aufgaben, Notizen |
| [Anchor/GoalDetailView.swift](Anchor/GoalDetailView.swift) | Ankerdetail: Balken statt Ring, Kennzahlen, Tempo-Satz, Tagesverlauf |
| [Anchor/OnboardingView.swift](Anchor/OnboardingView.swift) | Zwei Schritte: iCloud-Entscheidung, dann bis zu vier Anker setzen |
| [Anchor/WeeklyReviewView.swift](Anchor/WeeklyReviewView.swift) | Wochenrückblick als **Ritual**: immer dunkel, Serif, Dichte 1,4 — plus Übertrag **pro Aufgabe** |
| [Anchor/SettingsView.swift](Anchor/SettingsView.swift) | Einstellungen: Erscheinungsbild, iCloud-Sync, Zugang zu Daten und Datenschutz |
| [Anchor/DataPrivacyView.swift](Anchor/DataPrivacyView.swift) | Bildschirm „Daten und Datenschutz": Bestand, Export, Löschung |
| [Anchor/TaskCaptureSheets.swift](Anchor/TaskCaptureSheets.swift) | `NewTaskSheet`, `NewGoalSheet`, `QuickCapturePopover`, `CaptureChip` |
| [Anchor/TaskEditorSheets.swift](Anchor/TaskEditorSheets.swift) | `TaskEditorSheet`, `TaskMoveSheet` |
| [Anchor/AnkerComponents.swift](Anchor/AnkerComponents.swift) | `TaskCard` (**die** Aufgabenzeile, überall dieselbe), `TaskTitleField` (Titel inline), `TaskCheckmark`, `SectionLabel`, `AnchorRow`, `PriorityTag`, `AnkerTabBar` (iPhone-Tableiste), `TaskDragEvents`/`TaskDropHandling` |
| [Anchor/AnkerPhoneChrome.swift](Anchor/AnkerPhoneChrome.swift) | Die Fensterrahmung des iPhones **statt** der Systemleiste: `AnkerPhoneHeader`, `AnkerHeaderButton`, `AnkerSheetHeader`, `ankerSheetChrome(_:cancel:confirm:)` |
| [Anchor/CloudSyncStatus.swift](Anchor/CloudSyncStatus.swift) | `CloudSyncStatusCenter` und die Sync-Anzeigen |
| **Ressourcen und Tests** | |
| [Anchor/PrivacyInfo.xcprivacy](Anchor/PrivacyInfo.xcprivacy) | Privacy Manifest — Pflicht für die App-Store-Einreichung |
| [Anchor/Localizable.xcstrings](Anchor/Localizable.xcstrings) | String Catalog, Quellsprache Deutsch |
| [Anchor/Fonts/InstrumentSerif-Regular.ttf](Anchor/Fonts/InstrumentSerif-Regular.ttf) | Instrument Serif (OFL-1.1) — die **einzige** mitgelieferte Schrift, nur fürs Ritual |
| `Anchor/Assets.xcassets/Icons/` | 41 Lucide-Icons als Vektor-Imagesets (ISC) plus `daivento-wochenpuls` — die eigene Marke, kein Lucide |
| `Anchor/Assets.xcassets/AppIcon.appiconset/` | App-Icon: die 4×7-Matrix. `AppIcon-*` für iOS (randlos, ohne Alpha), `AppIconMac-*` für macOS (gerundet, mit Rand) |
| [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift) | **Zeichnet** den Iconsatz (Wochenpuls) für iOS, macOS und Menüleiste; `swift Scripts/make-app-icons.swift` |
| `Anchor/Assets.xcassets/MenuBarTemplate.imageset/` | Glyph der macOS-Menüleiste, `template-rendering-intent` |
| ~~[assets/icon/](assets/icon/)~~ | **Überholt.** Die alten roten Vorlagen; seit Lot zeichnet das Skript die Icons selbst |
| [Scripts/design-guard.swift](Scripts/design-guard.swift) | 26 Schranken des Lot-Systems; `swift Scripts/design-guard.swift` |
| [AnchorTests/](AnchorTests/) | 128 Unit-Tests (SwiftData in-memory): Kern, Matrix, Kennzahlen, Tokens, Kontrast, Erfassungssyntax, Zeitschiene |
| [AnchorUITests/AnchorUITests.swift](AnchorUITests/AnchorUITests.swift) | Verankerungs- und Erfassungsfluss; braucht das Startargument `-DaiventoUITest` |
| [AnchorUITests/PhoneChromeTests.swift](AnchorUITests/PhoneChromeTests.swift) | Nur iOS: Detailansicht erreichbar **und verlassbar**, alle vier Tabs. Läuft gegen einen iOS-Simulator, nicht gegen `platform=macOS` |

Alles ist ein einziges Multiplattform-Target (`Anchor`, Produkt `Daivento.app`); Plattformunterschiede
laufen über `#if os(macOS)` / `#if os(iOS)`. Es gibt **kein** SPM-Package und keine getrennten Targets,
auch wenn [Anchor_prompt.md](Anchor_prompt.md) das ursprünglich so vorsah. Das ist eine bewusste
Entscheidung (2026-08-04): das Paket `AnkerKit` lohnt sich erst, wenn Widget- oder Watch-Extensions
tatsächlich anstehen — Begründung in [Analyse_und_Massnahmenplan.md](Analyse_und_Massnahmenplan.md)
unter A5. Modell und Logik liegen aber schon jetzt in eigenen Dateien ohne View-Bezug, damit dieser
Schritt später ein Umzug bleibt und keine Entflechtung.

Neue Dateien werden über `PBXFileSystemSynchronizedRootGroup` automatisch erfasst; `project.pbxproj`
muss dafür nicht angefasst werden.

## Referenzdokumente (Ground Truth für Design & Verhalten)

- **Lot Designsystem.dc.html** und **Daivento in Lot.dc.html** (Claude-Design-Projekt
  *New Daivento direction*, `d96eecb8-cc9f-407d-aadd-80ad4697cf6a`) — **die** verbindliche visuelle
  Referenz seit 2026-08-16. Das erste ist das System (Modi, Farbachsen, Material, Radius,
  Signaturbausteine), das zweite die Anwendung auf die Screens samt Tokentabelle, Zuständen und
  Bewegung. Nicht im Repo; die Umsetzung ist in
  [Scripts/design-guard.swift](Scripts/design-guard.swift) und
  [AnchorTests/AnkerThemeTests.swift](AnchorTests/AnkerThemeTests.swift) festgehalten. **Struktur,
  Daten und Interaktion sind unverändert** — Lot wechselt das Material, nicht den Aufbau.
  Vier bewusste Abweichungen sind dort begründet: die drei gemessenen Kontrastkorrekturen (siehe
  Konventionen) und die Serif ohne tabellarische Ziffern, weil Instrument Serif keine `tnum`-Tabelle
  mitbringt. Wo die beiden Dokumente sich widersprachen — Schrift der Arbeitsfläche —, gilt das
  Systemblatt: **SF Pro in der App**, Instrument Sans nur als Web-Stellvertreter (Entscheidung des
  Nutzers, 2026-08-16).
- **Daivento AppIcon Lot.dc.html** (dasselbe Projekt) — der Iconsatz: vier Anker, sieben Tage,
  Bernstein auf Papierweiß, drei Erscheinungsbilder für iOS, Big-Sur-Maske für macOS, ein
  Template für die Menüleiste. Umgesetzt in
  [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift).
- ~~**Daivento Neu.dc.html**~~ (dasselbe Projekt) — der Modernist-Neuentwurf vom 2026-08-04. Seine
  **Struktur** gilt weiter, sein Material ist von Lot abgelöst. Nur noch als Historie lesen.
- **Daivento Apple-getunt.dc.html** (dasselbe Projekt) — Runde 3 („Objekte werden rund. Struktur
  bleibt scharf."). Von Lot überholt, das alles rundet außer Wochenpuls und Fortschrittsbalken.
  Offen aus der Spalte *Mehr als Radius*: SF Symbols statt Lucide (widerspricht der
  Bündelungsentscheidung, siehe Konventionen) und Dynamic Type in der Breite. Federn und Haptik
  sind mit Lot spezifiziert (Abschnitt *Bewegung und Haptik* in `Daivento in Lot.dc.html`).
- **Daivento Mac Sidebar.dc.html** (dasselbe Projekt) — Runde 2. Legte **zwei** unvereinbare
  Sidebars vor; gewählt ist **2a „Zeitschiene"** (Entscheidung des Nutzers, 2026-08-04). Die vier
  dort gemeinsam festgelegten Punkte gelten unabhängig davon: Rückblick scharf statt laut, Übertrag
  pro Aufgabe, Archiv als Ort, genau ein Zeitnavigator. Verworfen ist 2b („Vorsätze zuerst": Anker
  in der Sidebar, kein Wochenbaum) — nicht umsetzen, ohne das hier zu ändern.
- ~~[Anchor/Anker_Design_System_v2.html](Anchor/Anker_Design_System_v2.html)~~ — **überholt.**
  Liquid Glass; nur noch als Historie lesen, nicht als Vorgabe.
- ~~[Anchor/Anker_Coding_Prompt_v2_Migration.md](Anchor/Anker_Coding_Prompt_v2_Migration.md)~~ — dito.
- [Daivento_Task_Interaktionskonzept.md](Daivento_Task_Interaktionskonzept.md) — Swipe/Kontextmenü/Mehrfachauswahl/Undo
- [Daivento_Task_Flow_Mac_Visuals.html](Daivento_Task_Flow_Mac_Visuals.html) — Mac-Task-Flow (Hover-Reveal, Drag auf Sidebar)
- [Anchor_prompt.md](Anchor_prompt.md) — ursprünglicher Gesamt-Spec (teils überholt, s. o.)

## Projekt-Skills

Für die wiederkehrenden Themen liegen Skills unter [.claude/skills/](.claude/skills/):

- `daivento-build` — Bauen, Testen, Simulator, Xcode-Setup
- `daivento-swiftdata` — SwiftData-/CloudKit-Regeln, Beziehungen mutieren, `TaskActions`
- `daivento-design-system` — Farbtokens, Typo, Icons, Kontrast, die Schranken
- `daivento-task-interactions` — Aufgaben-Interaktionen pro Plattform, Undo, Accessibility

## Konventionen

- **Namensdualismus:** Marke/Produkt = *Daivento*, Code-Präfix bleibt *Anker*/*Anchor*
  (`AnkerColor`, `AnkerTask`, `AnchorApp`). Bundle-ID `com.marcomeisen.Anchor` und iCloud-Container
  `iCloud.com.marcomeisen.Anchor` sind **absichtlich** unverändert — nicht umbenennen, sonst brechen
  bestehende Installationen und der CloudKit-Sync.
- `AnkerTask` heißt so, weil `Task` mit Swift Concurrency kollidiert.
- Jede abgeschlossene Änderung bekommt eine Zeile in [changelog.md](changelog.md) (Deutsch, unter dem
  Datumsheader, Ergebnis statt Vorgehen).
- **Kein Tracking, keine Analytics, keine Netzwerkaufrufe** außer CloudKit.
- Gebündelt sind genau zwei fremde Ressourcen, beide als Datei im Repo und ohne Paketmanager:
  **Instrument Serif** (OFL-1.1) und **Lucide** (ISC). Archivo ist mit dem Lot-Reskin entfallen —
  die Arbeitsfläche spricht die Systemschrift, und damit kommen Dynamic Type, optische Größen und
  die Sprachabdeckung ohne eigene Datei. Weitere Abhängigkeiten bleiben ausgeschlossen.
- **Der Wochenpuls ist die Signaturfigur, nicht ein Icon unter vielen.** Dieselbe Zeichnung trägt
  App-Icon, Menüleiste und die Rolle `AnkerIcon.goal`; Geometrie und Füllstände stehen in
  [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift) und im SVG daneben. Wer eines von
  beiden ändert, ändert beide — sonst zeigen Icon und Glyphe verschiedene Wochen.
- Abstände kommen aus `AnkerSpacing`, Schrift aus `AnkerType`, Icons aus `AnkerIcon`, Farben aus
  `AnkerColor`. Vor dem Abschluss einer Änderung `swift Scripts/design-guard.swift` laufen lassen.
- **App-Icons nicht von Hand anfassen** — [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift)
  **zeichnet** sie (seit Lot aus einer Geometrievorschrift, nicht mehr aus Vorlagen in
  `assets/icon/`). Der Grund für das Zeichnen: die kleinen Größen sind nicht dasselbe Bild in klein.
  Ab 40 px fallen die Tagesfugen weg und aus 4×7 Feldern werden vier Balken mit denselben
  Füllständen — das lässt sich nicht herunterrechnen. Für die Menüleiste zählt dabei die
  **Punktgröße** (immer 18) und nicht die Pixelgröße der Datei, sonst trägt ausgerechnet die
  @3x-Fassung sieben Fugen. Die beiden Plattformen brauchen ausdrücklich
  Verschiedenes: **macOS** maskiert nicht selbst, die Form muss mitgeliefert werden (Apples Raster:
  Körper 824/1024 zentriert, Eckenradius 185,4, transparenter Rand). **iOS** maskiert selbst mit
  demselben fortlaufend gerundeten Quadrat — dort muss das Bild randlos und **ohne** Alphakanal
  sein, sonst gibt es eine doppelte Kante und der App Store lehnt die Einreichung ab.
- Zwei Fallen, die dabei schon zugeschlagen haben: `NSImage.draw` in einen selbst gesetzten
  `NSGraphicsContext` zeichnet in einem Prozess ohne `NSApplication` **nichts** (die Bitmap bleibt
  genullt und fällt nur an gleichen Prüfsummen auf) — reines CoreGraphics benutzen. Und die
  gerundete Ecke gehört über `RoundedRectangle(style: .continuous)` gezogen, nicht über
  `CGPath(roundedRect:)`: Apples Ecke ist eine fortlaufende Kurve, ein Kreisbogen ist sichtbar
  kantiger. `Shape.path(in:)` liefert sie ohne Renderer — eine eigene Bezier-Näherung beult die
  Kante aus, das war beim Lot-Iconsatz schon einmal sichtbar.
- **Alles ist rund, außer zwei Dingen.** Lot hebt die Modernist-Mengentrennung auf: gerundet wird
  auf 4pt-Basis über eine **Rolle** (`AnkerRadius.check`/`.control`/`.card`/`.group`/`.glass`),
  immer `style: .continuous`, **nie** `.circular`. Ohne Radius bleiben genau zwei Dinge, beide mit
  Begründung: der **Wochenpuls** (die sieben Felder müssen als Raster lesbar bleiben) und der
  **Fortschrittsbalken** (ein rundes Ende lügt über den Wert). Beide zeichnen `Rectangle`.
- **Sechs Flächen-Idiome, keine handgebauten siebten.** Jede Fläche kommt aus genau einem, und die
  Wahl beantwortet „was ist das": `.ankerCard()` trägt Inhalt und steht auf Höhe 1 ·
  `.ankerCard(elevated: false)` ist eine getönte Hinweisfläche · `.ankerGlass()` ist **Chrome über
  Inhalt** · `.ankerField()` ist ein Eingabefeld · `.ankerControl()` ist ein Knopf oder eine
  Auswahlkachel · `.ankerPill()` ist Filter, Zähler oder Marke · `.ankerPanel()` bleibt der
  eingelassenen Leiste.
- **Material und Höhe sind erlaubt — aber nur über ein Idiom.** Das ist die ausdrückliche Umkehr der
  Modernist-Regel „nichts schwebt": „Nähe entsteht durch Material und Höhe, nicht durch Rahmen."
  Roh an der Aufrufstelle bleiben beide verboten, denn genau dort entstünden Glas hinter Fließtext
  und ein vierter Schatten ohne Bedeutung. `AnkerElevation` hat vier Stufen: `flat` (Listenzeile),
  `card`, `lifted` (gezogene Karte, Popover), `sheet`.
- **Glas nur für Chrome, Text nur auf deckendem Grund.** `.ankerGlass()` gehört auf Kopfzeile,
  Erfassungsleiste, Tableiste und Sheets — nie auf Inhalt: „Text auf Glas ist auf Fotos und beim
  Scrollen nicht verlässlich lesbar." `design-guard` prüft das über eine Dateiliste, nicht über ein
  Zeilenmuster.
- **Rost ist ausschließlich Rückstand.** `AnkerColor.rust`/`.rustInk` markieren Übertrag und
  Liegengebliebenes, höchstens zweimal pro Bildschirm — **nie** eine Marke, nie den Zustand „aktiv",
  nie einen Knopf. Bernstein ist „jetzt, aktiv, primär" und nie eine Warnung. Kein Grün, kein Gelb,
  kein Blau: die vier Zustände unterscheiden sich über **Füllung**, nicht über Farbton, damit sie
  ohne Legende und ohne Farbsehen lesbar bleiben.
- **Zwei Modi, zwei Schriften.** Die Arbeitsfläche spricht San Francisco (Dynamic Type, optische
  Größen, alle Sprachen — ohne Bündelung), das **Ritual** Instrument Serif. Der Serif ist Display:
  nur im Wochenrückblick, nie unter 28 pt, nie für Fließtext. Gewichte nur 400/500/600 — die
  Hierarchie tragen Grad, Farbe und Fläche, nicht das Gewicht. Der Ritual-Modus ist **immer dunkel**
  und nimmt `AnkerColor.Ritual` statt der kippenden Tokens; Abstände dort × 1,4
  (`AnkerSpacing.ritual(_:)`).
- **Die Linie trennt über Farbe, nicht über Stärke.** Abschnittsgrenze und Zeilentrenner sind beide
  eine Haarlinie; der Unterschied ist `AnkerColor.divider` gegen `.cardDivider`
  (`AnkerRule(weight: .section)` gegen `.row`). Die 2px-Regel ist damit abgelöst — was einen Bereich
  abgrenzt, tut das über Fläche und Höhe. Segmentleisten werden als **ein** gerundetes Objekt
  geklippt, die Trenner darin bleiben Haarlinien.
- **Nicht jedes Farbtoken ist eine Textfarbe.** Schrift kommt aus `ink` / `inkSecond` / `inkMuted` /
  `inkTertiary` bzw. `accentInk` und `rustInk` — nur die tragen einen zugesicherten Kontrast.
  `AnkerColor.faint` (der Entwurfswert `LotTextFaint`) ist **Fläche**: als Schrift sind es 2,10:1
  auf dem Grund, dieselbe Falle wie `#9B9797` im Modernist-System. Ebenso trägt `accentMark` keine
  Schrift — das ist die 3:1-Markenfarbe für Linien und Icons; eine Fläche mit Text darauf ist
  `accentFill`.
- **Drei Werte des Entwurfs sind gemessen korrigiert**, jeder mit seinem Messwert in
  `AnkerThemeTests` festgehalten: `LotTextFaint` als Mikro-Beschriftung (2,10:1 → `inkTertiary`),
  `LotAmber` als Marke (2,15:1 → `accentMark` = `LotAmberDeep`) und Papierweiß auf Bernstein für den
  primären Knopf (2,89:1 → `onAccent` = Tinte). **`onAccent` ist deshalb als einziges Token
  statisch**: Bernstein ist in beiden Modi hell, also bleibt die Schrift darauf in beiden Modi
  Tinte. `goalTint` dagegen kippt weiter mit — sonst ist ein dunkles Ziel als Balken auf dunklem
  Grund unsichtbar.
- **Das Kästchen hakt ab, der Titel wird bearbeitet.** Diese Regel gilt auf jeder Fläche. Kein Klick
  auf eine Zeilenfläche darf einen Zustand ändern; Doppelklick auf den Titel öffnet ihn zum Tippen
  (`TaskTitleField`), das Blatt `TaskEditorSheet` bleibt für Woche, Tag und Anker.
- **Das Onboarding darf niemals eine Falle sein.** `needsOnboarding` fragt den **ganzen** Bestand,
  nie nur die laufende Woche, und `hasCompletedOnboarding` muss immer greifen — ein neu
  installiertes Gerät hat sonst keinen Ausweg, während sein iCloud-Bestand noch unterwegs ist.
  Beim Zusammenführen doppelter Wochen überlebt die **inhaltsreichere**, nicht die mit der
  kleineren UUID. Beides ist mit Tests in
  [AnchorTests/OnboardingSyncTests.swift](AnchorTests/OnboardingSyncTests.swift) festgehalten.
- **Nie zusammenführen, solange der Import läuft.** Die Inhaltsgewichtung allein genügt nicht —
  sie unterstellt, dass beide Wochen zum Vergleichszeitpunkt vollständig vorliegen. CloudKit
  liefert `Week`, `Day`, `Goal` und `AnkerTask` aber als getrennte Records in getrennten Batches:
  trifft die Woche vor ihren Kindern ein, wiegt sie 0 und verliert gegen eine frisch angelegte
  Onboarding-Woche. Sie zu löschen heißt, einen **synchronisierten** Record zu löschen — und das
  wandert als Löschung in die Cloud und auf alle anderen Geräte. Deshalb zwei Schranken:
  `StoreMaintenance` schiebt eine Gruppe auf, in der eine Woche leer und eine andere gefüllt ist,
  und der Aufruf in `AnkerRootView` wartet drei ruhige Sekunden ab, bevor er wiegt. Der Preis ist
  eine dauerhaft leere Dublette, die liegen bleibt — sie trägt keine Information, und die
  Oberfläche zeigt ohnehin die inhaltsreichere Woche.
- **Auf dem iPhone gibt es keine Systemleiste.** Seit iOS 26 zeichnet sie ihre Elemente in
  schwebende Glaskapseln — die Sprache, die der Neuentwurf ersetzt hat. Gemessen und verworfen:
  `toolbarBackground`, `UINavigationBarAppearance` und `UIBarButtonItemAppearance` greifen nicht
  auf die Kapseln durch, und eine gesetzte Appearance ließ zusätzlich den großen Blatt-Titel
  verschwinden. Stattdessen `toolbar(.hidden, for: .navigationBar)` plus die Bausteine aus
  [Anchor/AnkerPhoneChrome.swift](Anchor/AnkerPhoneChrome.swift). Ein Blatt bekommt seine Rahmung
  über **eine** Aufrufstelle, `.ankerSheetChrome(_:cancel:confirm:)`; die Plattformweiche steckt
  darin, der Mac behält die Systemleiste. Zwei Fallen dabei: die Kopfzeile eines obersten
  Bildschirms hat **keinen Titel** (den trägt die Tableiste) und **keine eigene Kante** (die trägt
  die erste Inhaltszeile) — sonst stehen zwei 2px-Kanten 60pt übereinander. Und der Zurück-Weg
  läuft über `@Environment(\.dismiss)`, **nicht** über eine hereingereichte Closure: der Baustein
  von `navigationDestination` ist escapend und fängt eine Momentaufnahme der Wurzelansicht ein.
- **Die Sidebar ist nur Zeit.** Kein Ansichtswechsel, keine Zielliste, kein zweiter Zeitnavigator
  darin — das war der Befund der zweiten Runde und ist keine Geschmacksfrage. Ein Anker gehört in
  den Streifen (`AnchorStripView`), ein Modus in `AnkerViewSwitcher`.
- Nach Modelländerungen muss das CloudKit-Schema in der CloudKit-Konsole von Development nach
  Production deployt werden. Ohne das gilt: läuft in Xcode, tot in TestFlight.
- **Ein Deploy allein genügt dafür nicht.** CloudKit legt ein Record-Feld erst an, wenn ein
  Datensatz **mit einem Wert darin** exportiert wird. Ein neuer Optional, der überall `nil`
  geblieben ist, existiert im Development-Schema deshalb gar nicht und kann folglich auch nicht
  nach Production deployt werden — genau so fehlten `reflection`, `reviewedAt`, `completedAt` und
  `carryOverCount` monatelang. Vor dem Deploy also immer erst den Upload laufen lassen:
  Scheme > Run > Arguments > `-DaiventoInitializeCloudKitSchema`. Er leitet die Felder aus dem
  Managed Object Model ab statt aus vorhandenen Daten. Ergebnis steht im System-Log
  (`CloudKit-Schema hochgeladen`), Argument danach wieder entfernen.
