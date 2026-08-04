# Daivento (Repo-Name: `anchor`)

Multiplattform-SwiftUI-App (iPhone / iPad / Mac) für Wochenplanung: max. 4 Wochenziele („Anker")
pro Woche, an die Aufgaben verankert werden. Persistenz über SwiftData mit CloudKit-Sync.

Seit dem Neuentwurf *Modernist* (2026-08-04) ist **das Datenmodell die Oberfläche**: 4 Anker × 7 Tage
als ein sichtbares Raster, nicht als Kalenderabbild. Visuell heißt das flach — Radius 0, keine
Verläufe, keine Materialien, keine Schatten, 2px-Regeln, Archivo in schweren Schnitten.
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
| [Anchor/Theme.swift](Anchor/Theme.swift) | `AnkerColor` (Rampen, dreiteiliger Akzent, Karten), `AnkerSpacing`, `AnkerBorder`, `AnkerRadius` — **keine** Hex-Werte in Views |
| [Anchor/ThemeType.swift](Anchor/ThemeType.swift) | `AnkerType` — 20 Typo-Tokens mit Größe, Gewicht, Laufweite, Großschreibung; `.ankerType(_:)` |
| [Anchor/ThemeFont.swift](Anchor/ThemeFont.swift) | Archivo-Registrierung und Gewichtsachse; Ziffern mit gleicher Laufweite |
| [Anchor/ThemeIcon.swift](Anchor/ThemeIcon.swift) | `AnkerIcon` (Lucide), `AnkerIconSize`, `AnkerLabel` |
| [Anchor/ThemeSurfaces.swift](Anchor/ThemeSurfaces.swift) | `AnkerRule` (`.section`/`.row`), die vier Flächen-Idiome `ankerCard()` / `ankerField()` / `ankerControl()` / `ankerPanel()`, `ankerEdge(_:)`, `AnkerProgressBar`, `AnkerButtonStyle`, `AnkerToggleStyle` |
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
| [Anchor/WeeklyReviewView.swift](Anchor/WeeklyReviewView.swift) | Wochenrückblick als rotes Plakat (die einzige Vollfläche im Akzent) plus Übertrag **pro Aufgabe** |
| [Anchor/SettingsView.swift](Anchor/SettingsView.swift) | Einstellungen: Erscheinungsbild, iCloud-Sync, Zugang zu Daten und Datenschutz |
| [Anchor/DataPrivacyView.swift](Anchor/DataPrivacyView.swift) | Bildschirm „Daten und Datenschutz": Bestand, Export, Löschung |
| [Anchor/TaskCaptureSheets.swift](Anchor/TaskCaptureSheets.swift) | `NewTaskSheet`, `NewGoalSheet`, `QuickCapturePopover`, `CaptureChip` |
| [Anchor/TaskEditorSheets.swift](Anchor/TaskEditorSheets.swift) | `TaskEditorSheet`, `TaskMoveSheet` |
| [Anchor/AnkerComponents.swift](Anchor/AnkerComponents.swift) | `TaskCard` (**die** Aufgabenzeile, überall dieselbe), `TaskTitleField` (Titel inline), `TaskCheckmark`, `SectionLabel`, `AnchorRow`, `PriorityTag`, `TaskDragEvents`/`TaskDropHandling` |
| [Anchor/CloudSyncStatus.swift](Anchor/CloudSyncStatus.swift) | `CloudSyncStatusCenter` und die Sync-Anzeigen |
| **Ressourcen und Tests** | |
| [Anchor/PrivacyInfo.xcprivacy](Anchor/PrivacyInfo.xcprivacy) | Privacy Manifest — Pflicht für die App-Store-Einreichung |
| [Anchor/Localizable.xcstrings](Anchor/Localizable.xcstrings) | String Catalog, Quellsprache Deutsch |
| [Anchor/Fonts/Archivo.ttf](Anchor/Fonts/Archivo.ttf) | Archivo als Variable Font (OFL-1.1); Gewichte über die `wght`-Achse |
| `Anchor/Assets.xcassets/Icons/` | 43 Lucide-Icons als Vektor-Imagesets (ISC) |
| `Anchor/Assets.xcassets/AppIcon.appiconset/` | App-Icon: die 4×7-Matrix. `AppIcon-*` für iOS (randlos, ohne Alpha), `AppIconMac-*` für macOS (gerundet, mit Rand) |
| [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift) | Erzeugt den Iconsatz aus [assets/icon/](assets/icon/); `swift Scripts/make-app-icons.swift` |
| `Anchor/Assets.xcassets/MenuBarTemplate.imageset/` | Glyph der macOS-Menüleiste, `template-rendering-intent` |
| [assets/icon/](assets/icon/) | Iconquellen. Was hier liegt, ist die Vorlage — der Katalog hält Kopien |
| [Scripts/design-guard.swift](Scripts/design-guard.swift) | 18 Grep-Schranken gegen Rückfall in die alte Sprache; `swift Scripts/design-guard.swift` |
| [AnchorTests/](AnchorTests/) | 128 Unit-Tests (SwiftData in-memory): Kern, Matrix, Kennzahlen, Tokens, Kontrast, Erfassungssyntax, Zeitschiene |
| [AnchorUITests/AnchorUITests.swift](AnchorUITests/AnchorUITests.swift) | Verankerungs- und Erfassungsfluss; braucht das Startargument `-DaiventoUITest` |

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

- **Daivento Neu.dc.html** (Claude-Design-Projekt *New Daivento direction*,
  `d96eecb8-cc9f-407d-aadd-80ad4697cf6a`) — **die** verbindliche visuelle Referenz seit 2026-08-04.
  Nicht im Repo; die Umsetzung ist in [Scripts/design-guard.swift](Scripts/design-guard.swift) und
  [AnchorTests/AnkerThemeTests.swift](AnchorTests/AnkerThemeTests.swift) festgehalten. Drei bewusste
  Abweichungen sind dort begründet: der Akzent ist für Marke, Fläche und Schrift dreigeteilt (eine
  Farbe erreicht nicht in allen drei Rollen 4,5:1), die Mikro-Beschriftung nutzt `inkSecond` statt
  `#9b9797` (2,59:1 wäre unlesbar), und Archivo liegt als Variable Font statt in statischen Schnitten.
- **Daivento Apple-getunt.dc.html** (dasselbe Projekt) — Runde 3, Variante **3b** ist umgesetzt
  („Objekte werden rund. Struktur bleibt scharf."). 3a war der Stand davor, nur als Referenz.
  Offen aus der Spalte *Mehr als Radius*: SF Symbols statt Lucide (widerspricht der
  Bündelungsentscheidung, siehe Konventionen), Dynamic Type, Federn und Haptik.
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
  **Archivo** (OFL-1.1) und **Lucide** (ISC). Der Neuentwurf verlangt sie; die frühere Regel
  „keine Custom-Fonts, keine Drittanbieter-Dependencies" ist damit ausdrücklich aufgehoben
  (Entscheidung des Nutzers, 2026-08-04). Weitere Abhängigkeiten bleiben ausgeschlossen.
- Abstände kommen aus `AnkerSpacing`, Schrift aus `AnkerType`, Icons aus `AnkerIcon`, Farben aus
  `AnkerColor`. Vor dem Abschluss einer Änderung `swift Scripts/design-guard.swift` laufen lassen.
- **App-Icons nicht von Hand anfassen** — [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift)
  erzeugt sie aus [assets/icon/](assets/icon/). Die beiden Plattformen brauchen ausdrücklich
  Verschiedenes: **macOS** maskiert nicht selbst, die Form muss mitgeliefert werden (Apples Raster:
  Körper 824/1024 zentriert, Eckenradius 185,4, transparenter Rand). **iOS** maskiert selbst mit
  demselben fortlaufend gerundeten Quadrat — dort muss das Bild randlos und **ohne** Alphakanal
  sein, sonst gibt es eine doppelte Kante und der App Store lehnt die Einreichung ab.
- Zwei Fallen, die dabei schon zugeschlagen haben: `NSImage.draw` in einen selbst gesetzten
  `NSGraphicsContext` zeichnet in einem Prozess ohne `NSApplication` **nichts** (die Bitmap bleibt
  genullt und fällt nur an gleichen Prüfsummen auf) — reines CoreGraphics benutzen. Und die
  gerundete Ecke gehört über `RoundedRectangle(style: .continuous)` gezogen, nicht über
  `CGPath(roundedRect:)`: Apples Ecke ist eine fortlaufende Kurve, ein Kreisbogen ist sichtbar
  kantiger.
- **Objekte sind rund, Struktur bleibt scharf.** Runde 3 hat den Nullradius nicht aufgeweicht,
  sondern zwei Mengen getrennt. Rund ist, was man **anfasst oder was schwebt**: Knöpfe und Felder
  (`AnkerRadius.control`), Karten (`.card`), das Häkchen (`.check`), Auswahlkacheln (`.tile`) —
  immer `style: .continuous`, **nie** `.circular`. Scharf bleibt die Struktur: das 4×7-Raster, die
  Fortschrittsbalken, alle Sektionskanten und das Rückblick-Plakat. Daten und Flächen sind keine
  Objekte. Radius nur über eine **Rolle**, nie als Zahl — eine Rolle sagt, *warum* etwas rund ist.
- **Vier Flächen-Idiome, keine handgebauten fünften.** Jede Fläche in einer View kommt aus genau
  einem davon, und die Wahl beantwortet die Frage „was ist das":
  `.ankerCard()` trägt Inhalt und schwebt (Elevation, kein Rahmen) · `.ankerCard(fill:elevated: false)`
  ist eine getönte Hinweisfläche — rund, aber ohne Gewicht · `.ankerField()` ist ein Eingabefeld
  (rund, flach, Haarlinie) · `.ankerControl()` ist ein Knopf, eine Auswahlkachel oder eine
  Schrittschalter-Anzeige (rund, 2px-Kante) · `.ankerPanel()` bleibt der **scharfen** Struktur
  vorbehalten. Das alte Muster `background(surface)` + `Rectangle().stroke(divider, rule)` +
  `clipShape(Rectangle())` ist damit ersetzt; `clipShape(Rectangle())` ist eine eigene Schranke,
  weil es auf einer scharfen Fläche wirkungslos und auf einer runden falsch ist.
- **2px trennt Bereiche, 1px trennt Zeilen.** `AnkerRule(weight: .section)` gegen
  `.row`/`AnkerBorder.hairline`. Eine 2px-Kante an jeder Listenzeile liest sich wie ein
  Tabellengitter. Listen sitzen in `.ankerCard()` — Elevation **statt** Rahmen; das ist die einzige
  Stelle, an der „nichts schwebt" bewusst zurückgenommen ist, und `.shadow(` bleibt außerhalb der
  Tokendateien verboten. Segmentleisten (Ankerstreifen, Ansichtswechsel, Behalten/Streichen) werden
  als **ein** gerundetes Objekt geklippt, die Trenner darin bleiben 2px.
- **Die Rampe ist keine Textfarbe.** Schrift und Icons kommen aus `ink` / `inkSecond` / `inkTertiary`
  bzw. `accentInk` — nur die tragen einen zugesicherten Kontrast. Eine Rampenstufe direkt als
  `foregroundStyle` ist geraten: `neutral[500]` (`#9B9797`) stand an sechs Stellen und lag bei
  2,4:1. Ebenso trägt `accentMark` **keine** Schrift — das ist die 3:1-Markenfarbe für Linien und
  Icons; eine Fläche mit Text darauf ist `accentFill` oder eine tiefere Rampenstufe.
- **Der Akzent kippt im Dunkelmodus.** `accentFill` geht hoch (sonst säuft die Fläche auf dunklem
  Grund ab), und `onAccent` kippt mit auf Tinte. Fest auf Weiss wäre 1,9:1. Dasselbe gilt für
  `goalTint`: die angebotenen Zielfarben sind Rampenstufen und spiegeln mit — sonst ist ein dunkles
  Ziel als Balken auf dunklem Grund unsichtbar.
- **Das Kästchen hakt ab, der Titel wird bearbeitet.** Diese Regel gilt auf jeder Fläche. Kein Klick
  auf eine Zeilenfläche darf einen Zustand ändern; Doppelklick auf den Titel öffnet ihn zum Tippen
  (`TaskTitleField`), das Blatt `TaskEditorSheet` bleibt für Woche, Tag und Anker.
- **Das Onboarding darf niemals eine Falle sein.** `needsOnboarding` fragt den **ganzen** Bestand,
  nie nur die laufende Woche, und `hasCompletedOnboarding` muss immer greifen — ein neu
  installiertes Gerät hat sonst keinen Ausweg, während sein iCloud-Bestand noch unterwegs ist.
  Beim Zusammenführen doppelter Wochen überlebt die **inhaltsreichere**, nicht die mit der
  kleineren UUID. Beides ist mit Tests in
  [AnchorTests/OnboardingSyncTests.swift](AnchorTests/OnboardingSyncTests.swift) festgehalten.
- **Die Sidebar ist nur Zeit.** Kein Ansichtswechsel, keine Zielliste, kein zweiter Zeitnavigator
  darin — das war der Befund der zweiten Runde und ist keine Geschmacksfrage. Ein Anker gehört in
  den Streifen (`AnchorStripView`), ein Modus in `AnkerViewSwitcher`.
- Nach Modelländerungen muss das CloudKit-Schema in der CloudKit-Konsole von Development nach
  Production deployt werden. Ohne das gilt: läuft in Xcode, tot in TestFlight.
