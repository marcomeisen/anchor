# Daivento (Repo-Name: `anchor`)

Multiplattform-SwiftUI-App (iPhone / iPad / Mac) für Wochenplanung: Jahr → Monat → Woche → Tag,
mit max. 4 Wochenzielen pro Woche, an die Aufgaben "verankert" werden. Persistenz über SwiftData
mit CloudKit-Sync.

**Sprache:** Alle sichtbaren UI-Texte, Commits, Changelog-Einträge und Doku sind auf Deutsch.
Code-Identifier sind Englisch.

## Struktur

| Datei | Inhalt |
|---|---|
| [Anchor/AnchorApp.swift](Anchor/AnchorApp.swift) | `@main`, `ModelContainer`, CloudKit-Konfiguration, macOS-Statusbar-Popover, `AnkerSchema.models` |
| [Anchor/Models.swift](Anchor/Models.swift) | `@Model`: `Goal`, `Week`, `Day`, `AnkerTask`, `TimeBlock`; `Priority` |
| [Anchor/TaskEditing.swift](Anchor/TaskEditing.swift) | `TaskActions` (**die** Mutations-Schicht für Aufgaben), `TaskSnapshot`/Undo, `TaskEditorSheet`, `TaskMoveSheet` |
| [Anchor/OverviewViews.swift](Anchor/OverviewViews.swift) | `AnkerRootView` (Navigation, Onboarding, Wochen-/Monatssprünge), `SidebarView`, `WeekOverviewView`, `YearOverviewView` |
| [Anchor/TodayView.swift](Anchor/TodayView.swift) | iPhone-Heute-Screen, Undo-Toast, Mehrfachauswahl |
| [Anchor/DayDetailView.swift](Anchor/DayDetailView.swift) | Tagesdetailansicht: Kennzahlen, Tagesfokus, Ziele, Zeitplan, Aufgaben, Notizen |
| [Anchor/StoreMaintenance.swift](Anchor/StoreMaintenance.swift) | Zusammenführen von Wochen/Tagen, die der iCloud-Sync doppelt erzeugt |
| [Anchor/AnkerComponents.swift](Anchor/AnkerComponents.swift) | `TaskCard` (Kern-Interaktion), `GoalBanner`, `ProgressRing`, `PriorityTag`, `GlassTabBar`, `GlassFAB`, `TaskDragEvents`/`TaskDropHandling` |
| [Anchor/DetailAndCaptureViews.swift](Anchor/DetailAndCaptureViews.swift) | `NewTaskSheet`, `NewGoalSheet`, `QuickCapturePopover`, `WeeklyReviewView`, `GoalDetailView`, `OnboardingView` |
| [Anchor/Theme.swift](Anchor/Theme.swift) | `AnkerColor` / `AnkerRadius` / `AnkerSpacing`, `Color(light:dark:)` |
| [Anchor/CalendarLogic.swift](Anchor/CalendarLogic.swift) | `AnkerCalendar` — **immer** ISO-8601, nie `Calendar.current` |
| [Anchor/CloudSyncStatus.swift](Anchor/CloudSyncStatus.swift) | `CloudSyncStatusCenter` — Sync-Anzeige in der Sidebar |
| [AnchorTests/AnchorTests.swift](AnchorTests/AnchorTests.swift) | XCTest-Unit-Tests (SwiftData in-memory) |

Alles ist ein einziges Multiplattform-Target (`Anchor`, Produkt `Daivento.app`); Plattformunterschiede
laufen über `#if os(macOS)` / `#if os(iOS)`. Es gibt **kein** SPM-Package und keine getrennten Targets,
auch wenn [Anchor_prompt.md](Anchor_prompt.md) das ursprünglich so vorsah.

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
