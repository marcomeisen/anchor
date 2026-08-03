---
name: daivento-task-interactions
description: Interaktionsmodell für Aufgaben in Daivento pro Plattform — iPhone-Swipes, Kontextmenü mit Untermenüs, Mac-Hover-Aktionen und Tastaturkürzel, Drag-and-Drop auf Sidebar-Wochen, Mehrfachauswahl, Undo-Toast, Haptik und Pflicht-Accessibility-Actions. Nutzen bei Änderungen an TaskCard, Swipe-Aktionen, Kontextmenüs, Shortcuts, Drag-and-Drop, Auswahlmodus oder Undo.
---

# Aufgaben-Interaktionen

Spezifikation: [Daivento_Task_Interaktionskonzept.md](../../../Daivento_Task_Interaktionskonzept.md) ·
Mac-Visuals: [Daivento_Task_Flow_Mac_Visuals.html](../../../Daivento_Task_Flow_Mac_Visuals.html) ·
Umsetzung: `TaskCard` in [Anchor/AnkerComponents.swift](../../../Anchor/AnkerComponents.swift)

## Grundprinzip

Drei Zugriffswege auf **dieselbe** Handlungsmenge, bewusst redundant: Swipe (schnell),
Kontextmenü (vollständig), Mehrfachauswahl (Aufräumen). Es gibt **keinen** eigenen
Bearbeitungsmodus-Screen — bearbeitet wird in der Liste. `TaskEditorSheet` ist die Ausnahme für
den vollständigen Datensatz, kein Standardweg.

Neue Aktionen deshalb immer in `taskMenuItems` ergänzen, und nur wenn sie zu den häufigsten
gehören zusätzlich als Swipe. Swipe-Überladung ist explizit unerwünscht.

## Aktionsmatrix

| Aktion | iPhone-Swipe | Kontextmenü | Mac-Shortcut | Haptik |
|---|---|---|---|---|
| Erledigt / offen | Leading, Full-Swipe | ✓ oben | `⌘.` | `.impactLight` |
| Löschen | Trailing, destruktiv | 🗑 unten, isoliert | `⌘⌫` | `.notificationSuccess` |
| Verschieben | Trailing, gezielter Tap | 📅 Untermenü | `⌘⇧M` | `.impactMedium` |
| Priorität A/B/C | — | ⚑ Untermenü | `⌘1`/`⌘2`/`⌘3` | `.impactLight` |
| Mit Ziel verknüpfen | — | 🎯 Untermenü | — | `.impactLight` |
| Duplizieren | — | 📋 | `⌘D` | `.impactLight` |

Menü-Reihenfolge folgt Apples Konvention: Preview → primäre Aktionen → Untermenüs → `Divider()` →
destruktive Aktion ganz unten mit `role: .destructive`.

Untermenü „Verschieben": Heute · Morgen · Diese Woche ▸ (Mo–So) · Nächste Woche · Datum wählen …
(letzteres nur auf iOS, weil der Mac stattdessen direkt in die nächste Woche verschiebt bzw. Drag nutzt).

## Plattformzuschnitt

Der Zuschnitt läuft über `#if os(macOS)` in `TaskCard` und die beiden Helper
`platformTaskContextMenu(menuItems:preview:)` und `conditionalTaskDrag(task:isEnabled:isDragging:)`.

**macOS**
- Hover enthüllt drei Icon-Buttons rechts (erledigt / nächste Woche / löschen), `opacity` + `allowsHitTesting` an `isHovering`, `accessibilityHidden(!isHovering)`
- Jeder Icon-Button hat `.help("… (⌘X)")` mit Shortcut im Text
- Kontextmenü **ohne** `preview:` — macOS unterstützt das nicht
- Drag: `NSItemProvider(object: task.id.uuidString as NSString)` + `TaskDragPreviewCard`, Ursprungszeile auf `opacity 0.35`
- Drop auf Sidebar-Wochen: Highlight `← Ziel`, Ende über `TaskDragEvents.end(taskID:)`; ein 8-s-Watchdog setzt `isDragging` zurück, falls kein Drop-Ende kommt
- Verschieben ohne Sheet: Hover-Aktion und `⌘⇧M` verschieben direkt in die nächste Woche

**iPhone**
- `.swipeActions(edge: .leading, allowsFullSwipe: true)` → erledigt/offen, `.tint(AnkerColor.success)`
- `.swipeActions(edge: .trailing, allowsFullSwipe: true)` → löschen (`role: .destructive`) + verschieben (`.tint(AnkerColor.indigo)`)
- Kontextmenü **mit** `preview:` (`TaskContextPreviewCard`)
- Ellipsis-Menü-Button in der Karte statt Hover
- Mehrfachauswahl über Toolbar-Button oder Long-Press auf die Checkbox; Aktionsleiste unten in Glas-Material; Löschbestätigung ab 3 Aufgaben

## Drop-Ziele

Aufgaben werden als reine UUID-Zeichenkette gezogen. Jedes Drop-Ziel nutzt `TaskDropHandling`
(in `AnkerComponents.swift`) statt die drei Schritte erneut zu implementieren:

```swift
.onDrop(of: TaskDropHandling.draggedTypes, isTargeted: …) { providers in
    TaskDropHandling.loadTaskID(from: providers) { taskID in
        TaskDropHandling.moveTask(id: taskID, to: targetDate, weeks: weeks, modelContext: modelContext)
        …
    }
}
```

Über die Concurrency-Grenze geht bewusst nur die `UUID` — Modellobjekte sind nicht `Sendable`.
`moveTask` meldet in jedem Fall `TaskDragEvents.end`, sonst bleibt die Ursprungszeile auf macOS
transparent. Das Zieldatum vor dem Closure in eine lokale `Date` ziehen.

Vorhandene Ziele: Sidebar-Wochen, Sidebar-Tage, Tageszeilen der Wochenübersicht,
iPhone-Wochenstreifen (`WeekDot`) und die Tagesdetailansicht. Jedes davon zeigt ein Highlight
(Rahmen in `AnkerColor.indigo` plus leichte Vergrößerung).

Nach einem Drop wird **nicht** navigiert, nur der Zieltag gesetzt (`onFocusDay`) — der Blick soll
dort bleiben, wo gezogen wurde. Ein Klick auf einen Tag (`onSelectDay`) öffnet dagegen die
`DayDetailView`.

## Undo — Pflicht bei jeder mutierenden Aktion

Die Toast-Mechanik steckt in `TaskUndoCoordinator` (`TaskEditing.swift`); jede Ansicht mit
Aufgabenliste hält ein `@StateObject` davon statt eigene Timer-Logik zu bauen.

```swift
let snapshot = TaskActions.snapshot(task)
TaskActions.<aktion>(task, …, modelContext: modelContext)
undo.present(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: [snapshot]))
```

- Toast unten, 4 s, mit Fortschrittsbalken; ein neuer Toast verdrängt den vorherigen sofort (kein Stapel)
- Wiederherstellung an der **exakten** Ursprungsposition, nicht am Listenende
- Erzeugende Aktionen (Duplizieren) brauchen `operation: .deleteCreated`, sonst entfernt das Undo die Kopie nicht
- Meldungen sind kurze deutsche Perfekt-Sätze: „Aufgabe gelöscht", „Ziel verknüpft", „Priorität geändert"

## Accessibility — nicht optional

- **Jede** Swipe-Aktion braucht ein `.accessibilityAction(named:)`-Pendant. VoiceOver-Nutzer:innen
  wischen zur Navigation und erreichen Swipe-Aktionen sonst nicht.
- Destruktive Labels nennen die Konsequenz: „Aufgabe löschen", nicht „Löschen".
- Bei `@Environment(\.accessibilityReduceMotion)` statt Spring ein `.easeOut(duration: 0.15)` —
  in `TaskCard` über `taskAnimation` gelöst.
- `.contextMenu` nicht durch eigene Gesture-Recognizer überschreiben; es ist bereits barrierefrei.

## Haptik

Nur iOS, immer gekapselt (`iOSImpact(_:)` / `iOSNotificationSuccess()` in `TaskCard`), damit der
macOS-Build sauber bleibt. Auf dem Mac gibt es stattdessen den kurzen Farb-Flash am Zielelement.
