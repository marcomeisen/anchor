# Anchorit (Repo-Name: `anchor`)

Multiplattform-SwiftUI-App (iPhone / iPad / Mac) für Wochenplanung: max. 4 Wochenziele („Anker")
pro Woche, an die Aufgaben verankert werden. Persistenz über SwiftData mit CloudKit-Sync.

Seit dem Neuentwurf **„Blatt"** (2026-11-23) gilt: **ein Blatt pro Woche.** Höchstens vier Dinge,
die diese Woche zählen, jedes mit einem Satz, warum. Jede Aufgabe gehört zu einem Anker oder steht
ausdrücklich ohne. Am Sonntag zählt, was gehalten wurde — beantwortet vom Menschen, nicht
errechnet. Der Wochenablauf hat vier Schritte: **Setzen** (Montag), **Erledigen**, **Prüfen**
(Sonntag), **Ablegen** (Archiv).

Visuell ist „Blatt" ruhig: Tinte auf kühlem Hellgrau, weiße Karten mit Haarlinie, Systemschrift
(SF Pro) und **genau eine Farbe** — ein tiefes Blau, das „erledigt" oder „heute" bedeutet und sonst
nichts. Anker unterscheiden sich über ihre **Nummer**, nicht über eine Farbe. Auf dem iPhone gibt
es Tabs (Heute, Woche, Archiv). Auf Mac und iPad steht links eine **einklappbare Seitenleiste mit
den Wochen** (ansehen, Aufgaben hineinziehen), rechts ein Fensterkopf mit Bereichswahl.

Der Entwurf ist mehrere Runden durchlaufen (Modernist, Zeitschiene, Glas-Varianten, Kartenmetapher)
und hat die verspielte Kartenmetapher und die bunte Palette bewusst verworfen. Was davon geblieben
ist: das Blatt als Bild, der Punkt pro Aufgabe, „ohne Anker" und „ohne Tag" als eigene Orte.

**Sprache:** Alle sichtbaren UI-Texte, Commits, Changelog-Einträge und Doku sind auf Deutsch.
Code-Identifier sind Englisch.

## Struktur

| Datei | Inhalt |
|---|---|
| **Rahmen** | |
| [Anchor/AnchorApp.swift](Anchor/AnchorApp.swift) | `@main`, `AnkerStore`, `CloudSyncConfiguration`, macOS-Statusbar-Popover und Einstellungen-Szene, verborgene Titelleiste auf dem Mac |
| [Anchor/ContentView.swift](Anchor/ContentView.swift) | Wurzel-View: Farbmodus, Fehlerdialog, `PreviewContainer` |
| **Modell und Logik** (keine Views) | |
| [Anchor/Models.swift](Anchor/Models.swift) | `@Model`: `Goal` (mit `why`, `verdictRaw`), `Week`, `Day`, `AnkerTask`, `TimeBlock`; `GoalVerdict`, `Priority` |
| [Anchor/WeekSheet.swift](Anchor/WeekSheet.swift) | **Das Blatt einer Woche ohne View:** Anker × Tage plus „ohne Anker" und „ohne Tag"; funktioniert auch ohne gespeicherte Woche |
| [Anchor/TaskActions.swift](Anchor/TaskActions.swift) | `TaskActions` (**die** Mutations-Schicht für Aufgaben), Aufgaben ohne Tag, `ensureWeek`/`ensureDay`, Undo |
| [Anchor/GoalEditing.swift](Anchor/GoalEditing.swift) | `GoalActions` — Wochenziele löschen, Aufgaben bleiben erhalten; `goalDeleteConfirmation` |
| [Anchor/WeekPlanning.swift](Anchor/WeekPlanning.swift) | Wochen und Tage **finden** (über ISO-Schlüssel, zonensicher), `needsOnboarding`/`hasContent`, erste Anker |
| [Anchor/AppNavigation.swift](Anchor/AppNavigation.swift) | `AppDestination`, `AnkerNavigationState`: Sprünge, `@SceneStorage`-Wiederherstellung, `anchorit://`-Deep-Links |
| [Anchor/Persistence.swift](Anchor/Persistence.swift) | `ModelContext.saveChanges()` — **statt** `try? save()`; `PersistenceFailureCenter` |
| [Anchor/StoreMaintenance.swift](Anchor/StoreMaintenance.swift) | Zusammenführen von Sync-Duplikaten (Gewinner: kleinste UUID) und Einsammeln verwaister Datensätze, mit `MergeReport` |
| [Anchor/Search.swift](Anchor/Search.swift) | `AnkerSearch` über Aufgaben, Ziele, Notizen, Tagesfokus, Zeitblöcke; `SearchSheet` |
| [Anchor/DataPortability.swift](Anchor/DataPortability.swift) | JSON-Export und vollständige Löschung (DSGVO Art. 15, 17, 20) |
| [Anchor/AppSettings.swift](Anchor/AppSettings.swift) | `AppearanceMode`, `CloudSyncPreference`, `UITestMode` (inkl. `-AnchoritDemoData`, `-AnchoritTab`) |
| [Anchor/CalendarLogic.swift](Anchor/CalendarLogic.swift) | `AnkerCalendar` — **immer** ISO-8601; `nominalDay(ofStored:)` für Tage aus anderen Zeitzonen; `AnkerDateFormat` |
| [Anchor/CaptureSyntax.swift](Anchor/CaptureSyntax.swift) | Erfassungssyntax `!a` / `#2` / `mo…so` — reiner Parser |
| [Anchor/GoalOrdering.swift](Anchor/GoalOrdering.swift) | Ankernummer 1–4 aus `Goal.order` — **nie** über `week.goalList` sortieren |
| [Anchor/WeekActions.swift](Anchor/WeekActions.swift) | Woche schließen/öffnen, Rückblickantwort, `ReviewReadiness`, `CarryDecision` pro Aufgabe |
| [Anchor/AnkerStatistics.swift](Anchor/AnkerStatistics.swift), [Anchor/AnkerArchive.swift](Anchor/AnkerArchive.swift), [Anchor/AnkerMatrix.swift](Anchor/AnkerMatrix.swift), [Anchor/SidebarTimeline.swift](Anchor/SidebarTimeline.swift) | Kennzahlen und ältere Logikschichten; von Tests abgedeckt, die Oberfläche von „Blatt" nutzt `WeekSheet` und `ArchiveSummary` |
| **Designtokens** (dürfen die Grundbausteine benutzen, alles andere nicht) | |
| [Anchor/Theme.swift](Anchor/Theme.swift) | `AnkerColor` (Tinte, Grund, Karte, **ein** Blau), `AnkerSpacing`, `AnkerBorder`, `AnkerRadius` — **keine** Hex-Werte in Views |
| [Anchor/ThemeType.swift](Anchor/ThemeType.swift), [Anchor/ThemeFont.swift](Anchor/ThemeFont.swift) | `AnkerType` in der Systemschrift, auf iOS mit Dynamic Type skaliert; `.ankerType(_:)` |
| [Anchor/ThemeIcon.swift](Anchor/ThemeIcon.swift) | `AnkerIcon` (Lucide), `AnkerIconSize`, `AnkerLabel` |
| [Anchor/ThemeSurfaces.swift](Anchor/ThemeSurfaces.swift) | `AnkerRule`, `ankerCard()` / `ankerField()` / `ankerControl()` / `ankerPanel()` / `ankerLooseArea()` / `ankerLifted()`, `AnkerProgressBar`, `AnkerPips`, `AnkerSegmented`, `AnkerButtonStyle`, `AnkerToggleStyle` |
| [Anchor/SampleData.swift](Anchor/SampleData.swift) | Beispieldaten für Previews, Tests und den UI-Testmodus |
| **Views** | |
| [Anchor/SidebarScreen.swift](Anchor/SidebarScreen.swift) | `BlattSidebar`: Wochenliste mit Tagesquadraten, Ablegen einer Aufgabe auf eine Woche (gleicher Wochentag), Archiv, Sync-Status |
| [Anchor/AnkerRootView.swift](Anchor/AnkerRootView.swift) | Onboarding, iPhone-Tabs, Fensterkopf (Mac/iPad), Sheets für Setzen und Rückblick, Aufräumen nach dem Sync |
| [Anchor/TodayScreen.swift](Anchor/TodayScreen.swift) | Heute: Ankerleiste mit Punkten, Aufgaben des Tages, „noch ohne Tag", Erfassungszeile |
| [Anchor/WeekScreen.swift](Anchor/WeekScreen.swift) | Woche in zwei Ansichten mit denselben Daten: iPhone *nach Tag / nach Anker*, Mac und iPad *Raster / nach Anker* |
| [Anchor/AnchorScreen.swift](Anchor/AnchorScreen.swift) | Ein Anker: große Nummer, Warum-Satz, Fortschritt, seine Woche Tag für Tag; `AnchorEditSheet` |
| [Anchor/WeekStartScreen.swift](Anchor/WeekStartScreen.swift) | Montag: „Was zählt diese Woche?" — bis zu vier Anker mit Warum, Übernahme aus der Vorwoche |
| [Anchor/ReviewScreen.swift](Anchor/ReviewScreen.swift) | Sonntag: gehalten / teilweise / nicht pro Anker, mitnehmen / loslassen pro Aufgabe |
| [Anchor/ArchiveScreen.swift](Anchor/ArchiveScreen.swift) | Archiv: das Jahr als Raster aus Wochen, ehrliche Kennzahlen, vergangene Wochen; `ArchiveSummary` |
| [Anchor/BlattSelection.swift](Anchor/BlattSelection.swift) | Mehrfachauswahl: `TaskSelectionModel`, „Auswählen"-Knopf, `BlattBulkActionBar` (Erledigt, Verschieben, Anker, Löschen) |
| [Anchor/BlattComponents.swift](Anchor/BlattComponents.swift) | `BlattHeading`, `BlattAnchorStrip`, `TaskChip`, `BlattDrop`, `BlattUndoBar`, `BlattBackBar`, `BlattIconButton` |
| [Anchor/CaptureBarView.swift](Anchor/CaptureBarView.swift) | Erfassungszeile: tippen, Enter, fertig — legt die Woche erst beim Sichern an |
| [Anchor/DayDetailView.swift](Anchor/DayDetailView.swift) | Tagesdetail: Fokus, Zeitplan, Aufgaben, Notizen |
| [Anchor/OnboardingView.swift](Anchor/OnboardingView.swift) | Zwei Schritte: iCloud-Entscheidung, dann bis zu vier Anker |
| [Anchor/SettingsView.swift](Anchor/SettingsView.swift), [Anchor/DataPrivacyView.swift](Anchor/DataPrivacyView.swift) | Einstellungen, Daten und Datenschutz |
| [Anchor/TaskCaptureSheets.swift](Anchor/TaskCaptureSheets.swift), [Anchor/TaskEditorSheets.swift](Anchor/TaskEditorSheets.swift) | Schnellerfassung in der Menüleiste, Aufgaben- und Zieleditor |
| [Anchor/AnkerComponents.swift](Anchor/AnkerComponents.swift) | `TaskCard` (**die** Aufgabenzeile, mit Kontextmenü, Swipe, Undo), `TaskTitleField`, `TaskCheckmark`, `AnkerTabBar` |
| [Anchor/AnkerPhoneChrome.swift](Anchor/AnkerPhoneChrome.swift) | Die eigene Kopfzeile des iPhones statt der Systemleiste |
| [Anchor/CloudSyncStatus.swift](Anchor/CloudSyncStatus.swift) | `CloudSyncStatusCenter` und die Sync-Anzeigen |
| **Ressourcen, Skripte, Tests** | |
| [Anchor/PrivacyInfo.xcprivacy](Anchor/PrivacyInfo.xcprivacy) | Privacy Manifest — Pflicht für die App-Store-Einreichung |
| `Anchor/Assets.xcassets/Icons/` | Lucide-Icons als Vektor-Imagesets (ISC). Katalog und `AnkerIcon.all` müssen deckungsgleich sein |
| `Anchor/Assets.xcassets/AppIcon.appiconset/` | App-Icon „Blatt": vier Reihen zu fünf Quadraten, Erledigtes blau. Hell, dunkel, getönt (iOS) und macOS |
| [Scripts/make-icon-sources.swift](Scripts/make-icon-sources.swift) | Zeichnet die Icon-Vorlagen nach [assets/icon/](assets/icon/) und das Menüleisten-Glyph |
| [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift) | Leitet daraus den Katalog ab (iOS randlos ohne Alpha, macOS gerundet mit Haarlinie) |
| [Scripts/design-guard.swift](Scripts/design-guard.swift) | Grep-Schranken für „Blatt"; `swift Scripts/design-guard.swift` |
| [AnchorTests/](AnchorTests/) | Unit-Tests (SwiftData in-memory): Kern, Sync-Zusammenführung über zwei Geräte, Zeitzonen, Aufgaben ohne Tag, Kennzahlen, Tokens, Kontrast, Erfassungssyntax |
| [AnchorUITests/](AnchorUITests/) | Verankern und Erfassen, beide Wochenansichten, Titel bearbeiten (Mac); `PhoneChromeTests` nur iOS |

Alles ist ein einziges Multiplattform-Target (`Anchor`, Produkt `Anchorit.app`); Plattformunterschiede
laufen über `#if os(macOS)` / `#if os(iOS)`. Es gibt **kein** SPM-Package (Begründung in
[Analyse_und_Massnahmenplan.md](Analyse_und_Massnahmenplan.md) unter A5).

Neue Dateien werden über `PBXFileSystemSynchronizedRootGroup` automatisch erfasst; `project.pbxproj`
muss dafür nicht angefasst werden.

## Referenzdokumente

- **Anchorit Blatt** — Claude-Design-Leinwand (Artifact `https://claude.ai/artifact/Jui7Q1ESaZ1Fb5EidHDGeN`),
  **die** verbindliche visuelle Referenz seit 2026-11-23: Prinzip, iPhone (Setzen, Heute, Woche in
  zwei Ansichten, Anker, Rückblick), Mac (Raster und nach Anker), Archiv. Nicht im Repo.
- **Anchorit Glas-Runde** (Artifact `https://claude.ai/artifact/23uFewh1UDy4L4LSznMa6H`) — die
  verworfenen Glas- und Lichtvarianten samt Kritik. Nur als Historie.
- ~~Daivento Neu / Apple-getunt / Mac Sidebar~~ (*Modernist*, Runden 1–3, noch unter dem früheren Namen) und
  ~~[Anchor/Anker_Design_System_v2.html](Anchor/Anker_Design_System_v2.html)~~ — **überholt.**
- [CloudKit_Schema_Anleitung.md](CloudKit_Schema_Anleitung.md) — Schema nach jeder Modelländerung von Development nach Production bringen, Schritt für Schritt
- [Daivento_Task_Interaktionskonzept.md](Daivento_Task_Interaktionskonzept.md) — Swipe/Kontextmenü/Mehrfachauswahl/Undo, gilt weiter
- [Anchor_prompt.md](Anchor_prompt.md) — ursprünglicher Gesamt-Spec (teils überholt)

## Projekt-Skills

Unter [.claude/skills/](.claude/skills/):

- `anchorit-build` — Bauen, Testen, Simulator, unsignierte Builds, Bildschirmfotos
- `anchorit-swiftdata` — SwiftData-/CloudKit-Regeln, Sync-Robustheit, `TaskActions`, Aufgaben ohne Tag
- `anchorit-design-system` — „Blatt": Tokens, eine Farbe, Flächen, Kontrast, die Schranken
- `anchorit-task-interactions` — Aufgaben-Interaktionen pro Plattform, Chips, Einplanen, Undo

## Konventionen

### Allgemein

- **Namensdualismus:** Marke/Produkt = *Anchorit* (bis 2026-11-23 *Daivento*), Code-Präfix bleibt
  *Anker*/*Anchor*. App, Modul und Executable heißen `Anchorit`; Tests importieren `@testable import Anchorit`.
  Das URL-Schema ist `anchorit://`, `daivento://` bleibt als Rückfall für alte Links registriert.
  Bundle-ID `com.marcomeisen.Anchor` und iCloud-Container `iCloud.com.marcomeisen.Anchor` sind
  **absichtlich** unverändert — nicht umbenennen, sonst brechen Installationen und der Sync.
- `AnkerTask` heißt so, weil `Task` mit Swift Concurrency kollidiert.
- Jede abgeschlossene Änderung bekommt eine Zeile in [changelog.md](changelog.md) (Deutsch, unter dem
  Datumsheader, Ergebnis statt Vorgehen).
- **Kein Tracking, keine Analytics, keine Netzwerkaufrufe** außer CloudKit.
- Gebündelt ist genau eine fremde Ressource: **Lucide** (ISC). Archivo ist mit „Blatt" entfallen —
  die App setzt in der Systemschrift. Weitere Abhängigkeiten bleiben ausgeschlossen.

### Sync und Daten — diese Regeln verhindern Datenverlust

- **Wochen und Tage entstehen nur beim Schreiben.** Kein Anlegen beim Start, beim Blättern oder
  beim Anzeigen. Vorher legte jedes neue Gerät die laufende Woche an, bevor der iCloud-Import sie
  brachte — ein Duplikat bei jeder Installation. Views rechnen die sieben Daten aus dem Kalender
  (`WeekSheet`); `TaskActions.ensureWeek` legt **keine** Tage an, `ensureDay` genau einen.
- **Wochen werden über ISO-Jahr und -Woche gefunden, nie über `monday`.** Das Montagsdatum ist
  Mitternacht in der Zeitzone des anlegenden Geräts. Tage gespeicherter Wochen über
  `AnkerCalendar.storedDay(_:isOn:)` bzw. `nominalDay(ofStored:)` vergleichen.
- **Beim Zusammenführen überlebt immer die kleinste UUID** — nicht die inhaltsreichere Kopie.
  Inhalt wird lokal gezählt und ist mitten in einem Import auf zwei Geräten verschieden; zwei
  Geräte löschten so jeweils die andere Kopie. Dass dabei eine leere Kopie gewinnt, ist kein
  Verlust: Kinder werden vor dem Löschen umgehängt. Benutzte Anker (Aufgaben, Warum, Antwort)
  kommen in der Reihenfolge vor leeren, damit frische Onboarding-Anker die echten nicht verdrängen.
- **Löschregeln sind `.nullify`, nicht `.cascade`** (`Week.goals`, `Week.days`, `Day.tasks`,
  `Day.timeBlocks`). Kommt die Löschung eines Duplikats von einem anderen Gerät an, bevor dieses
  Gerät umgehängt hat, bleiben die Kinder als Waisen stehen; `StoreMaintenance.adoptOrphans` hängt
  sie wieder ein. Vollständiges Löschen (`DataPortability`) löscht jeden Typ ausdrücklich.
- **Aufgeräumt wird erst, wenn kein Import läuft**, auf einem frischen Fetch
  (`StoreMaintenance.run`), nicht auf dem `@Query`-Schnappschuss einer View.
- **Aufgaben ohne Tag sind gültig:** mit Anker heißt das „noch nicht eingeplant" (sie gehören über
  den Anker zur Woche), ohne Anker liegen sie im Eingang. Nie als Datenmüll behandeln.
- **Neue Felder sind optional und additiv** (`Goal.why`, `Goal.verdictRaw`). Enums als Rohtext
  speichern, damit ein unbekannter Wert auf einem älteren Gerät den Import nicht bricht.
- **Nach Modelländerungen** das Schema nach Production bringen — Ablauf in
  [CloudKit_Schema_Anleitung.md](CloudKit_Schema_Anleitung.md). Ohne das gilt: läuft in Xcode, tot in
  TestFlight. Ein Debug-Mac und ein TestFlight-iPhone sehen sich **nie** — zwei Umgebungen.
- **Das Onboarding darf niemals eine Falle sein.** `needsOnboarding` fragt den **ganzen** Bestand
  einschließlich Eingang, und `hasCompletedOnboarding` muss immer greifen.
- **Der Testmodus hinterlässt nichts.** `UITestMode.prepare` darf Schlüssel nur **entfernen**, nie
  setzen; Startargumente (`-AnchoritTab week`) werden nur gelesen. Ein geschriebener Wert überlebt
  den Testlauf und gilt für jeden späteren echten Start — so wurde schon einmal der Sync dauerhaft
  abgeschaltet.

### Gestaltung „Blatt"

- **Eine Farbe.** `accentMark`/`accentFill`/`accentInk` sind dasselbe Blau und heißen „erledigt"
  oder „heute". Der Hauptknopf ist **Tinte** (`AnkerButtonStyle.primary`), nicht Blau. Keine
  Zielfarben: `goalTint(_:)` gibt für Altbestand überall das Blau zurück.
- **Schrift und Icons kommen aus `ink` / `inkSecond` / `inkTertiary` bzw. `accentInk`.** Nur die
  tragen einen zugesicherten Kontrast (Tests in beiden Modi). Die Rampen sind keine Textfarbe.
- **Flächen:** `.ankerCard()` (weiß, Haarlinie, 14pt) trägt Inhalt; `.ankerLooseArea()`
  (gestrichelt) ist alles ohne festen Platz — „ohne Anker", „noch ohne Tag"; `.ankerField()` ist
  ein Eingabefeld; `.ankerControl()` ein Knopf oder eine Kachel. **Kein Schatten** außer
  `.ankerLifted()` für Gezogenes, keine Verläufe, kein Glas.
- **Jede Linie ist eine Haarlinie.** Bereiche trennt der Abstand.
- **Beschriftungen in normaler Schreibung**, keine Versalien.
- Radius nur über eine **Rolle** aus `AnkerRadius`, immer `style: .continuous`. Abstände aus
  `AnkerSpacing` (2/4/6/8/12/16/24/32). Vor dem Abschluss `swift Scripts/design-guard.swift`.
- **Das Kästchen hakt ab, der Titel wird bearbeitet.** Kein Klick auf eine Zeilen- oder Chipfläche
  ändert einen Zustand. Doppelklick auf den Titel öffnet ihn zum Tippen (`TaskTitleField`).
- **Die Seitenleiste ist nur Zeit** (Mac, iPad): Wochen ansehen und Aufgaben in eine andere Woche
  ziehen — kein Ansichtswechsel, keine Ankerliste darin. Einklappbar (⌃⌘S, Zustand pro Gerät in
  `sidebarVisible`). Ist sie offen, entfällt der Wochenschalter im Kopf: es bleibt bei **genau
  einem** Zeitnavigator. Der Kopf passt sich über `ViewThatFits` an, damit er im iPad-Hochformat
  nicht unter die Leiste rutscht.
- **Beide Wochenansichten zeigen dieselben Daten.** Was im Raster eingeplant wird, steht in der
  Ansicht nach Anker — beide lesen `WeekSheet`, keine hält eigenen Zustand über Aufgaben.
- **Auf dem iPhone gibt es keine Systemleiste** (iOS 26 zeichnet sie als Glaskapseln). Stattdessen
  `toolbar(.hidden, for: .navigationBar)` plus `AnkerPhoneChrome`; Blätter über
  `.ankerSheetChrome(_:cancel:confirm:)`. Der Zurück-Weg läuft über `@Environment(\.dismiss)`, nie
  über eine hereingereichte Closure — der Baustein von `navigationDestination` ist escapend. Auf
  dem Mac trägt `BlattBackBar` denselben Weg; die Titelleiste ist verborgen, der Fensterkopf lässt
  den Ampelknöpfen Platz.
- **App-Icons nicht von Hand anfassen.** `swift Scripts/make-icon-sources.swift` zeichnet die
  Vorlagen, `swift Scripts/make-app-icons.swift` leitet den Katalog ab. **macOS** maskiert nicht
  selbst (Körper 824/1024, Eckenradius 185,4, transparenter Rand, Haarlinie gegen hellen Grund);
  **iOS** maskiert selbst und braucht das Bild randlos und **ohne** Alphakanal. Die Ecke über
  `RoundedRectangle(style: .continuous)`, nicht `CGPath(roundedRect:)`; Bitmaps über reines
  CoreGraphics oder `ImageRenderer`, nie `NSImage.draw` in einen eigenen `NSGraphicsContext`.
