---
name: anchorit-task-interactions
description: Interaktionsmodell für Aufgaben in Anchorit („Blatt") pro Plattform — TaskCard mit Swipe, Kontextmenü und Mac-Hover, TaskChip im Wochenraster, Einplanen durch Antippen auf dem iPhone, Ziehen im Mac-Raster (Tag und Anker in einem Schritt), Aufgaben ohne Tag, Undo, Haptik und Pflicht-Accessibility-Actions. Nutzen bei Änderungen an TaskCard, TaskChip, Swipe-Aktionen, Kontextmenüs, Shortcuts, Drag-and-Drop, Einplanen oder Undo.
---

# Aufgaben-Interaktionen

Spezifikation: [Daivento_Task_Interaktionskonzept.md](../../../Daivento_Task_Interaktionskonzept.md) ·
Mac-Visuals: [Daivento_Task_Flow_Mac_Visuals.html](../../../Daivento_Task_Flow_Mac_Visuals.html) ·
Umsetzung: `TaskCard` in [Anchor/AnkerComponents.swift](../../../Anchor/AnkerComponents.swift),
`TaskChip` und `BlattDrop` in [Anchor/BlattComponents.swift](../../../Anchor/BlattComponents.swift),
die Woche in [Anchor/WeekScreen.swift](../../../Anchor/WeekScreen.swift)

## Zwei Darstellungen einer Aufgabe

- **`TaskCard`** — die volle Zeile in Listen (Heute, Anker, Tagesdetail): Kästchen, Titel, rechts
  die **Ankernummer** (`showsAnchorNumber: true`, `metaLine: .none`), Swipe, Kontextmenü,
  Mac-Hover, Undo. Die Nummer steht nach den Hover-Aktionen, damit sie rechtsbündig bleibt.
- **`TaskChip`** — die kompakte Form im Wochenraster und in der Ansicht nach Anker: optional
  Kästchen, Ankernummer, Titel. Antippen ändert **nichts**; das Kontextmenü trägt Erledigt/Offen,
  „Ohne Tag" und Löschen; auf dem Mac ist der Chip ziehbar (`draggable(task.id.uuidString)`).

## Einplanen

- **Mac und iPad, Raster:** Zeile = Anker, Spalte = Tag, rechts „Ohne Tag". Ein Drop auf eine
  Zelle setzt **Tag und Anker** in einem Schritt (`TaskActions.place`); ein Drop auf „Ohne Tag"
  nimmt die Aufgabe aus dem Tag (`unschedule`) und hängt sie an den Anker der Zeile.
- **Mac und iPad, Seitenleiste:** eine Aufgabe auf eine Woche ziehen verschiebt sie an denselben
  Wochentag dort (`TaskActions.move(_:toWeekStarting:…)`); ohne Tag landet sie am Montag, ihr Anker
  wird über die Wochengrenze gelöst. Die Leiste zeigt danach einen Rückgängig-Hinweis.
- **Mac und iPad, nach Anker:** ein Drop auf eine Spalte setzt nur den Anker (`TaskActions.link`).
- **`TaskChip`-Kontextmenü:** Erledigt/Offen, „Verschieben …" (`TaskMoveSheet`), „In die nächste Woche" (`TaskActions.move(_:toWeekStarting:…)`), „Ohne Tag", Löschen — jeweils mit Undo und Accessibility-Action.
- **iPhone, nach Tag:** zwei Tipps statt Ziehen — gilt für Aufgaben ohne Tag **und** für geplante; eine angetippte geplante Aufgabe zeigt oben „Neuen Tag wählen" mit Abbrechen — Aufgabe im gestrichelten Vorrat „Noch ohne Tag"
  antippen, dann „Hierher" bei einem Tag. Ziehen über sieben Tage ist auf dem Telefon fummelig.
- **iPhone, nach Anker:** „Tag wählen" an einer Aufgabe ohne Tag springt in die Tagesansicht und
  wählt sie vor.
- Neue Aufgaben im Ankerbildschirm entstehen **ohne Tag** (`createUnscheduled`) — eingeplant wird in
  der Woche.

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
| Verschieben | Trailing, gezielter Tap | 📅 Untermenü | — (kein Zeilenkürzel, siehe unten) | `.impactMedium` |
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
- Drop-Ende über `TaskDragEvents.end(taskID:)`; ein 8-s-Watchdog setzt `isDragging` zurück, falls kein Drop-Ende kommt
- Verschieben ohne Sheet: die Hover-Aktion verschiebt direkt in die nächste Woche. **Keine Tastenkürzel an Zeilen oder Kontextmenüeinträgen:** jede sichtbare Zeile registrierte dasselbe Kürzel, mit vielen Zeilen war es mehrdeutig, und Kürzel an Menüeinträgen greifen nur bei offenem Menü. Globale Befehle stehen im Menü „Gehe zu“ (`AppCommands.swift`)

**iPhone**
- Wischen über `.taskSwipe` ([Anchor/TaskSwipe.swift](../../../Anchor/TaskSwipe.swift)), **nicht** `.swipeActions` — das wirkt nur in einer `List`, und die Zeilen stehen in `ScrollView`s. Nach rechts erledigt/offen (Blau), nach links löschen (Tinte), beides mit Undo; verschieben über das Kontextmenü. Die Geste beginnt nur bei deutlich waagerechter Bewegung, damit das Scrollen frei bleibt.
- Kontextmenü **mit** `preview:` (`TaskContextPreviewCard`)
- Ellipsis-Menü-Button in der Karte statt Hover
- Mehrfachauswahl über „Auswählen" neben der Abschnittsbeschriftung (Heute, Anker) oder „Auswählen" im Kontextmenü einer Zeile (langes Drücken aufs Kästchen kollidierte mit dem Kontextmenü); unten ersetzt `BlattBulkActionBar` die Erfassungszeile (Erledigt, Verschieben, Anker, Löschen, „Alle"); Löschbestätigung ab 3 Aufgaben. Zustand in `TaskSelectionModel` ([Anchor/BlattSelection.swift](../../../Anchor/BlattSelection.swift)); auf dem Mac `⌘⇧A`, Escape beendet

## Drop-Ziele

Die Wochen der Seitenleiste nutzen `TaskDropHandling.loadTaskID` — damit kommen Ziehvorgänge aus
`TaskCard` (NSString) und `TaskChip` (`draggable(String)`) gleichermaßen an. Neue Drop-Ziele im Raster nutzen `BlattDrop.place` mit einem
`String`-Payload.

Aufgaben werden als reine UUID-Zeichenkette gezogen. Jedes Drop-Ziel nutzt `TaskDropHandling`
(in `TaskDropHandling.swift`) statt die drei Schritte erneut zu implementieren:

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

Vorhandene Ziele: Zellen des Wochenrasters, Spalten der Ansicht nach Anker, die Tagesdetailansicht.

Nach einem Drop wird **nicht** navigiert, nur der Zieltag gesetzt (`onFocusDay`) — der Blick soll
dort bleiben, wo gezogen wurde. Ein Klick auf einen Tag (`onSelectDay`) öffnet dagegen die
`DayDetailView`.

## Undo — Pflicht bei jeder mutierenden Aktion

Die Mechanik steckt in `TaskUndoCoordinator` (`TaskActions.swift`), angezeigt als `BlattUndoBar`; jede Ansicht mit
Aufgabenliste hält ein `@StateObject` davon statt eigene Timer-Logik zu bauen.

```swift
let snapshot = TaskActions.snapshot(task)
TaskActions.<aktion>(task, …, modelContext: modelContext)
undo.present(TaskUndoNotice(message: "Aufgabe verschoben", snapshots: [snapshot]))
```

- Leiste unten über der Erfassungszeile, 4 s; ein neuer Hinweis verdrängt den vorherigen sofort (kein Stapel); `⌘Z` auf dem Mac
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
