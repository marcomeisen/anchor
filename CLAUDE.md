# Daivento (Repo-Name: `anchor`)

Multiplattform-SwiftUI-App (iPhone / iPad / Mac) für Wochenplanung: Jahr → Monat → Woche → Tag,
mit max. 4 Wochenzielen pro Woche, an die Aufgaben "verankert" werden. Persistenz über SwiftData
mit CloudKit-Sync.

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
| [Anchor/WeekPlanning.swift](Anchor/WeekPlanning.swift) | Wochen und Tage auflösen, Onboarding-Zustand, erstes Wochenziel — ohne View, deshalb testbar |
| [Anchor/AppNavigation.swift](Anchor/AppNavigation.swift) | `AppDestination`, `AnkerNavigationState`: Sprünge, `@SceneStorage`-Wiederherstellung, `daivento://`-Deep-Links |
| [Anchor/Persistence.swift](Anchor/Persistence.swift) | `ModelContext.saveChanges()` — **statt** `try? save()`; `PersistenceFailureCenter`, Fehlerdialog |
| [Anchor/StoreMaintenance.swift](Anchor/StoreMaintenance.swift) | Zusammenführen von Wochen/Tagen aus dem Sync, mit `MergeReport` und Protokoll |
| [Anchor/Search.swift](Anchor/Search.swift) | `AnkerSearch` über Aufgaben, Ziele, Notizen, Tagesfokus, Zeitblöcke; `SearchResultsList`, `SearchSheet` |
| [Anchor/DataPortability.swift](Anchor/DataPortability.swift) | JSON-Export und vollständige Löschung (DSGVO Art. 15, 17, 20) |
| [Anchor/AppSettings.swift](Anchor/AppSettings.swift) | `AppearanceMode` (Farbmodus), `CloudSyncPreference` (Sync ein/aus, greift erst beim Neustart) |
| [Anchor/CalendarLogic.swift](Anchor/CalendarLogic.swift) | `AnkerCalendar` — **immer** ISO-8601, nie `Calendar.current`; `AnkerDateFormat` — **alle** Datumsformate |
| [Anchor/Theme.swift](Anchor/Theme.swift) | `AnkerColor` / `AnkerRadius` / `AnkerSpacing`, `Color(light:dark:)` — **keine** Hex-Werte in Views |
| [Anchor/SampleData.swift](Anchor/SampleData.swift) | Beispieldaten, nur für Previews und Tests |
| **Views** | |
| [Anchor/AnkerRootView.swift](Anchor/AnkerRootView.swift) | Verteilt auf Onboarding, Split-Layout und iPhone-Layout; hält den Navigationszustand |
| [Anchor/SidebarView.swift](Anchor/SidebarView.swift) | Sidebar (Mac, iPad): Suche, Monatsnavigation, Tage, Ziele, Einstellungen, Sync-Status |
| [Anchor/WeekOverviewView.swift](Anchor/WeekOverviewView.swift) | Wochenübersicht mit Zielpillen und Tagesraster |
| [Anchor/YearOverviewView.swift](Anchor/YearOverviewView.swift) | Jahresübersicht |
| [Anchor/TodayView.swift](Anchor/TodayView.swift) | iPhone-Heute-Screen, Undo-Toast, Mehrfachauswahl |
| [Anchor/DayDetailView.swift](Anchor/DayDetailView.swift) | Tagesdetailansicht: Kennzahlen, Tagesfokus, Ziele, Zeitplan, Aufgaben, Notizen |
| [Anchor/GoalDetailView.swift](Anchor/GoalDetailView.swift) | Zieldetail mit Kennzahlen und Zeitverlauf |
| [Anchor/OnboardingView.swift](Anchor/OnboardingView.swift) | Zwei Schritte: iCloud-Entscheidung, erstes Wochenziel |
| [Anchor/WeeklyReviewView.swift](Anchor/WeeklyReviewView.swift) | Wochenrückblick, auf dem iPhone der Tab „Mehr" |
| [Anchor/SettingsView.swift](Anchor/SettingsView.swift) | Einstellungen: Erscheinungsbild, iCloud-Sync, Zugang zu Daten und Datenschutz |
| [Anchor/DataPrivacyView.swift](Anchor/DataPrivacyView.swift) | Bildschirm „Daten und Datenschutz": Bestand, Export, Löschung |
| [Anchor/TaskCaptureSheets.swift](Anchor/TaskCaptureSheets.swift) | `NewTaskSheet`, `NewGoalSheet`, `QuickCapturePopover`, `CaptureChip` |
| [Anchor/TaskEditorSheets.swift](Anchor/TaskEditorSheets.swift) | `TaskEditorSheet`, `TaskMoveSheet` |
| [Anchor/AnkerComponents.swift](Anchor/AnkerComponents.swift) | `TaskCard` (Kern-Interaktion), `GoalBanner`, `ProgressRing`, `PriorityTag`, `GlassTabBar`, `GlassFAB`, `TaskDragEvents`/`TaskDropHandling` |
| [Anchor/CloudSyncStatus.swift](Anchor/CloudSyncStatus.swift) | `CloudSyncStatusCenter` und die Sync-Anzeigen |
| **Ressourcen und Tests** | |
| [Anchor/PrivacyInfo.xcprivacy](Anchor/PrivacyInfo.xcprivacy) | Privacy Manifest — Pflicht für die App-Store-Einreichung |
| [Anchor/Localizable.xcstrings](Anchor/Localizable.xcstrings) | String Catalog, Quellsprache Deutsch |
| [AnchorTests/AnchorTests.swift](AnchorTests/AnchorTests.swift) | XCTest-Unit-Tests (SwiftData in-memory) |
| [AnchorUITests/AnchorUITests.swift](AnchorUITests/AnchorUITests.swift) | UI-Test des Kernflusses; braucht das Startargument `-DaiventoUITest` |

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

- [Anchor/Anker_Design_System_v2.html](Anchor/Anker_Design_System_v2.html) — verbindliche visuelle Referenz, alle 9 Screens, Light/Dark
- [Anchor/Anker_Coding_Prompt_v2_Migration.md](Anchor/Anker_Coding_Prompt_v2_Migration.md) — Liquid-Glass-Regeln, Kontrastkorrekturen
- [Daivento_Task_Interaktionskonzept.md](Daivento_Task_Interaktionskonzept.md) — Swipe/Kontextmenü/Mehrfachauswahl/Undo
- [Daivento_Task_Flow_Mac_Visuals.html](Daivento_Task_Flow_Mac_Visuals.html) — Mac-Task-Flow (Hover-Reveal, Drag auf Sidebar)
- [Anchor_prompt.md](Anchor_prompt.md) — ursprünglicher Gesamt-Spec (teils überholt, s. o.)

## Projekt-Skills

Für die wiederkehrenden Themen liegen Skills unter [.claude/skills/](.claude/skills/):

- `daivento-build` — Bauen, Testen, Simulator, Xcode-Setup
- `daivento-swiftdata` — SwiftData-/CloudKit-Regeln, Beziehungen mutieren, `TaskActions`
- `daivento-design-system` — Farbtokens, Liquid Glass, Kontrast, Typo
- `daivento-task-interactions` — Aufgaben-Interaktionen pro Plattform, Undo, Accessibility

## Konventionen

- **Namensdualismus:** Marke/Produkt = *Daivento*, Code-Präfix bleibt *Anker*/*Anchor*
  (`AnkerColor`, `AnkerTask`, `AnchorApp`). Bundle-ID `com.marcomeisen.Anchor` und iCloud-Container
  `iCloud.com.marcomeisen.Anchor` sind **absichtlich** unverändert — nicht umbenennen, sonst brechen
  bestehende Installationen und der CloudKit-Sync.
- `AnkerTask` heißt so, weil `Task` mit Swift Concurrency kollidiert.
- Jede abgeschlossene Änderung bekommt eine Zeile in [changelog.md](changelog.md) (Deutsch, unter dem
  Datumsheader, Ergebnis statt Vorgehen).
- Keine Custom-Fonts, keine Drittanbieter-Dependencies, kein Tracking.
