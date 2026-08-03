---
name: daivento-swiftdata
description: Regeln für das SwiftData-/CloudKit-Datenmodell von Daivento — @Model-Klassen, warum jede Property einen Default braucht, wie To-many-Beziehungen korrekt mutiert werden, die TaskActions-Mutationsschicht, order-Normalisierung, Undo-Snapshots, Wochen-/Tages-Anlage und ISO-Kalender. Nutzen bei allem, was Goal, Week, Day, AnkerTask, TimeBlock, ModelContext, @Query, Migration, iCloud-Sync oder Aufgaben-Mutationen betrifft.
---

# Datenmodell & Persistenz

Definition: [Anchor/Models.swift](../../../Anchor/Models.swift) ·
Schema-Registry: `AnkerSchema.models` in [Anchor/AnchorApp.swift](../../../Anchor/AnchorApp.swift)

```
Week ─cascade→ Day ─cascade→ AnkerTask ─nullify→ Goal
  └─cascade→ Goal            └─cascade→ TimeBlock
```

`AnkerTask` heißt so, weil `Task` mit Swift Concurrency kollidiert. Beim Anlegen neuer Modelle:
Typ **muss** in `AnkerSchema.models` eingetragen werden, sonst existiert er zur Laufzeit nicht.

## CloudKit-Zwänge — nicht verletzen

Der Store läuft gegen `.private("iCloud.com.marcomeisen.Anchor")`. CloudKit-kompatibles SwiftData heißt:

- **Jede** gespeicherte Property hat einen Default (`var title: String = ""`) oder ist optional.
  Ohne Default startet der Container nicht.
- **Jede** To-many-Beziehung ist optional (`var tasks: [AnkerTask]? = []`) mit einem nicht-optionalen
  Convenience-Accessor daneben (`var taskList: [AnkerTask] { tasks ?? [] }`). In der UI immer
  `taskList`/`goalList`/`dayList`/`timeBlockList` benutzen, nie das rohe Optional.
- Keine `@Attribute(.unique)`-Constraints, keine `deny`-Delete-Rules — beides unterstützt CloudKit nicht.
- Eindeutigkeit läuft über die eigene `id: UUID` plus Lookup, nicht über den Store.

## To-many-Beziehungen mutieren

SwiftData registriert Änderungen an einem optionalen Array **nicht** zuverlässig, wenn man direkt
darauf mutiert. Immer neu zuweisen:

```swift
// falsch
day.tasks?.append(task)

// richtig
day.appendTask(task)                                     // Model-Helper
day.tasks = day.taskList.filter { $0.id != task.id }     // Entfernen
week.appendGoal(goal)
```

Die Helper `Day.appendTask(_:)` und `Week.appendGoal(_:)` existieren genau dafür.

## `TaskActions` ist die einzige Mutationsschicht für Aufgaben

[Anchor/TaskEditing.swift](../../../Anchor/TaskEditing.swift). Aufgaben **nie** direkt in einer View
mutieren — jede Änderung geht durch `TaskActions`, weil dort Reihenfolge, Beziehungspflege und
`save()` zusammenhängen:

| Funktion | Nebeneffekt, den man leicht vergisst |
|---|---|
| `toggleDone(_:modelContext:)` | Erledigte Aufgabe wandert ans **Ende** der Tagesreihenfolge, danach `normalizeOrders` |
| `delete(_:modelContext:)` | Löst aus `day.tasks` **und** `goal.tasks`, danach `normalizeOrders` |
| `duplicate(_:modelContext:)` | Kopie ist immer `isDone == false`, hängt am selben Tag |
| `move(_:to:weeks:modelContext:)` | Legt Zielwoche/-tag bei Bedarf an; löst `linkedGoal`, wenn das Ziel zu einer anderen Woche gehört |
| `move(_:byDays:weeks:modelContext:)` | Rechnet ab `task.day?.date`, nicht ab heute |
| `setPriority`, `link` | Speichern sofort |
| `normalizeOrders(in:)` | Vergibt `order` lückenlos ab 0, Tie-Break über `localizedStandardCompare` des Titels |

Alle diese Funktionen rufen selbst `try? modelContext.save()` — nicht zusätzlich speichern.

## Wochen und Tage anlegen

Nie `Week(...)` oder `Day(...)` von Hand in einer View erzeugen. Stattdessen:

```swift
let week = TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
let day  = TaskActions.ensureDay(containing: date, in: week)
```

`ensureWeek` prüft in dieser Reihenfolge: übergebene `weeks`-Liste → `FetchDescriptor<Week>` →
Neuanlage. Der Fetch-Schritt ist wichtig, weil `@Query`-Listen verzögert aktualisiert werden und
sonst Duplikate für dieselbe Kalenderwoche entstehen (abgedeckt durch
`testEnsureWeekReusesPersistedWeekWhenQueryListIsStale`).

## Undo

`TaskSnapshot` friert `title`, `priority`, `isDone`, `order`, `dayID`, `goalID` ein — bewusst IDs
statt Objektreferenzen, weil das Objekt beim Undo gelöscht sein kann.

- Vor der Aktion: `let snapshot = TaskActions.snapshot(task)`
- Danach: `TaskUndoNotice(message:snapshots:)` an `onUndoableAction` reichen
- Bei *erzeugenden* Aktionen (Duplizieren) `operation: .deleteCreated` setzen, sonst wird die Kopie
  beim Undo nur neu gespeichert statt entfernt
- `TaskActions.restore` setzt die Aufgabe **an ihrer Ursprungsposition** wieder ein, nicht ans Ende

## Datum

Immer `AnkerCalendar` ([Anchor/CalendarLogic.swift](../../../Anchor/CalendarLogic.swift)), nie
`Calendar.current`. Der Kalender ist ISO-8601, damit die Woche montags beginnt und KW 01 über den
Jahreswechsel korrekt liegt (KW 01/2026 startet am 29.12.2025 — als Test fixiert). Tagesvergleiche
über `AnkerCalendar.isSameDay(_:_:)`, nicht über `==` auf `Date`.

## Tests

`AnchorTests` bauen den Container in-memory:

```swift
let schema = Schema(AnkerSchema.models)
let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
return try ModelContainer(for: schema, configurations: [configuration])
```

Tests, die Modelle anfassen, brauchen `@MainActor`. Neue Logik in `TaskActions` oder `AnkerCalendar`
bekommt einen Test — das ist im Projekt bisher durchgehalten worden.

## Duplikate aus dem Sync

Ohne Unique-Constraints erzeugen zwei Geräte, die offline dieselbe Kalenderwoche anlegen, nach
dem Sync zwei `Week`-Zeilen mit je sieben Tagen — sichtbar als doppelte Tagesliste und als
scheinbar verschwundene Aufgaben. `ensureWeek` verhindert das nur **lokal**.

[Anchor/StoreMaintenance.swift](../../../Anchor/StoreMaintenance.swift) räumt das auf und wird in
`AnkerRootView` über `.task(id: StoreMaintenance.duplicateSignature(for: weeks))` getriggert, läuft
also nach jedem Import automatisch erneut. Bei jeder Erweiterung beachten:

- Gruppierung über `isoYear`/`isoWeek` bzw. Tages-Datumskomponenten, **nicht** über `Date`-Werte —
  `AnkerCalendar` rechnet mit `TimeZone.current`, derselbe Montag ist auf Geräten in verschiedenen
  Zeitzonen ein anderer `Date`.
- Gewinner ist deterministisch die kleinste `id.uuidString`, damit beide Geräte unabhängig
  denselben Datensatz behalten und das Ergebnis konvergiert.
- Kinder erst umhängen, dann den Duplikat-Datensatz löschen — die `.cascade`-Regel nimmt Tage,
  Ziele und Aufgaben sonst mit.
- Notizen werden zusammengefügt statt überschrieben; Datenverlust beim Aufräumen wäre schlimmer
  als eine doppelte Zeile.

## CloudKit-Fehler sind nicht abfangbar

`ModelContainer.init` wirft **nicht**, wenn die iCloud-Entitlements fehlen. CloudKit richtet sich
danach asynchron auf einem Hintergrund-Queue ein und bricht den Prozess dort ab — außerhalb jedes
`do`/`catch`. Der Fallback in `AnkerStore.make()` deckt nur Fehler beim *Öffnen* des Stores ab
(z. B. inkompatible Metadaten nach dem Umstellen der CloudKit-Konfiguration). Wer einen Absturz
kurz nach dem Start ohne Swift-Stackframes sieht, prüft zuerst Entitlements und Provisioning.

## Sync-Status

`CloudSyncStatusCenter.shared` ([Anchor/CloudSyncStatus.swift](../../../Anchor/CloudSyncStatus.swift))
hört auf `NSPersistentCloudKitContainer.eventChangedNotification`, `didSaveObjectsNotification` und
`.NSPersistentStoreRemoteChange` und speist die Statuszeile unten in der Sidebar. Ein lokaler Save
schaltet auf `.pendingExport`; meldet CloudKit binnen 120 s keinen Export, wird daraus `.issue`.
Wer neue Save-Pfade einführt, bekommt das automatisch — kein manuelles Melden nötig.

Saves aus CloudKits eigenen Import-Kontexten werden über `isMirroringContext(_:)` ausgefiltert.
Ohne diesen Filter gilt jeder empfangene Datensatz als neue lokale Änderung und der Status fällt
nach jedem Import fälschlich auf „Sync prüfen".
