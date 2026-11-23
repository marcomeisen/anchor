---
name: anchorit-swiftdata
description: Regeln für das SwiftData-/CloudKit-Datenmodell von Anchorit — @Model-Klassen, warum jede Property einen Default braucht, wie To-many-Beziehungen korrekt mutiert werden, die TaskActions-Mutationsschicht, order-Normalisierung, Undo-Snapshots, Wochen-/Tages-Anlage und ISO-Kalender. Nutzen bei allem, was Goal, Week, Day, AnkerTask, TimeBlock, ModelContext, @Query, Migration, iCloud-Sync oder Aufgaben-Mutationen betrifft.
---

# Datenmodell & Persistenz

Definition: [Anchor/Models.swift](../../../Anchor/Models.swift) ·
Schema-Registry: `AnkerSchema.models` in [Anchor/AnchorApp.swift](../../../Anchor/AnchorApp.swift)

```
Week ─nullify→ Day ─nullify→ AnkerTask ─nullify→ Goal
  └─nullify→ Goal            └─nullify→ TimeBlock
```

**Alles `.nullify`, nichts `.cascade`** (seit 2026-11-23). Eine Woche wird nur beim Zusammenführen
von Sync-Duplikaten und beim vollständigen Löschen entfernt. Kam die Löschung eines Duplikats von
einem anderen Gerät an, bevor dieses Gerät die Kinder umgehängt hatte, nahm die Kaskade Tage und
Aufgaben mit — und exportierte die Löschung. Jetzt bleiben Waisen stehen und
`StoreMaintenance.adoptOrphans` hängt sie wieder ein. `DataPortability.deleteAllData` löscht jeden
Typ ausdrücklich.

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

[Anchor/TaskActions.swift](../../../Anchor/TaskActions.swift). Aufgaben **nie** direkt in einer View
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

## Wochen und Tage anlegen — nur beim Schreiben

Nie `Week(...)` oder `Day(...)` von Hand erzeugen, und **nie beim Anzeigen**:

```swift
let week = TaskActions.ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
let day  = TaskActions.ensureDay(containing: date, in: week)   // legt genau diesen einen Tag an
```

- `ensureWeek` legt **keine** Tage mehr an. Früher entstanden beim Start und beim Blättern eine
  Woche mit sieben Tagen; auf einem neuen Gerät vor dem iCloud-Import — ein Duplikat pro
  Installation. Views rechnen die sieben Daten aus dem Kalender (`WeekSheet`) und kommen ohne
  gespeicherte Woche aus.
- Gefunden wird über **ISO-Jahr und -Woche** (`WeekPlanning.week(startingAt:in:)`, Fetch mit
  `#Predicate` auf `isoYear`/`isoWeek`), nicht über `monday` — das ist Mitternacht in der Zone des
  anlegenden Geräts.
- Tage über `WeekPlanning.existingDay(on:in:)` bzw. `AnkerCalendar.storedDay(_:isOn:)`;
  `nominalDay(ofStored:)` schiebt ein gespeichertes Datum zwölf Stunden in die Tagesmitte, damit
  ein Tag aus einer anderen Zeitzone (Differenz < 12 h) seinem Kalendertag zugeordnet wird.
- `ensureWeekDays(in:)` (alle sieben) gibt es nur noch für Altbestand und Tests; in Tests
  `TaskActions.ensureFullWeek` aus `AnchorTests/TestSupport.swift`.

## Aufgaben ohne Tag

`AnkerTask.day == nil` ist ein gültiger Zustand:

- **mit Anker** — „noch nicht eingeplant"; die Aufgabe gehört über `linkedGoal.week` zu ihrer Woche
  (`TaskActions.unscheduledTasks(in:)`)
- **ohne Anker** — der Eingang (`TaskActions.inboxTasks(modelContext:)`, in Views
  `@Query(filter: #Predicate<AnkerTask> { $0.day == nil && $0.linkedGoal == nil })`)

`createUnscheduled`, `unschedule`, `duplicate`, `restore` und das Undo des Löschens können damit
umgehen. Wer nach Aufgaben sucht, fragt den Store oder `WeekSheet`, nicht nur `week.dayList`.

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

Ohne Unique-Constraints erzeugen zwei Geräte, die offline in dieselbe neue Woche schreiben, nach
dem Sync zwei `Week`-Zeilen. [Anchor/StoreMaintenance.swift](../../../Anchor/StoreMaintenance.swift)
führt sie zusammen. Regeln, die bei jeder Erweiterung gelten:

- **Gewinner ist immer die kleinste `id.uuidString`** — für Wochen und Tage. Früher gewann die
  inhaltsreichere Kopie; Inhalt wird aber lokal gezählt, und mitten in einem Import (Wochen kommen
  vor ihren Tagen) sahen zwei Geräte dieselben Kopien verschieden schwer und löschten jeweils die
  andere. Festgehalten in `OnboardingSyncTests.testElectionIgnoresLocallyVisibleContent`.
- Benutzte Anker (Aufgaben, Warum, Antwort) kommen in der gemeinsamen Reihenfolge vor leeren —
  damit verdrängen frische Onboarding-Anker die echten nicht.
- Kinder erst umhängen, dann das Duplikat löschen; Notizen und Rückblicke zusammenfügen.
- Gruppierung über `isoYear`/`isoWeek` bzw. `nominalDay`, nicht über `Date`-Werte.
- **Wann:** `AnkerRootView` startet `StoreMaintenance.run(modelContext:)` nach jeder
  Remote-Änderung, aber nur, wenn `CloudSyncStatusCenter.phase != .syncing`, mit zwei Sekunden
  Pause, und auf einem **frischen Fetch** statt auf dem `@Query`-Array.
- Danach `adoptOrphans`: Tage ohne Woche (über ihr Datum), Ziele ohne Woche (über ihre Aufgaben),
  Zeitblöcke ohne Tag (über ihre Startzeit). Aufgaben ohne Tag sind **kein** Waisenfall.

## Development und Production sind zwei Datenbanken

Xcode-Builds laufen gegen die **Development**-Umgebung des Containers, TestFlight- und
App-Store-Builds gegen **Production** (gesteuert über `ICLOUD_CONTAINER_ENVIRONMENT` je
Konfiguration). Sie synchronisieren nicht miteinander.

Entscheidender Unterschied: In Development legt `NSPersistentCloudKitContainer` fehlende
Record-Types **automatisch** an. In Production ist das Schema **read-only** — was dort nicht
deployt ist, existiert nicht, und der Sync scheitert. Nach jeder Modelländerung deshalb:

1. Einmal lokal mit `-AnchoritInitializeCloudKitSchema` starten (schreibt nach Development).
2. CloudKit Console → Container → Schema → **Deploy Schema Changes** → Development → Production.

Ausführlich mit Prüfschritten und Fehlerbildern: [CloudKit_Schema_Anleitung.md](../../../CloudKit_Schema_Anleitung.md).

Offen seit 2026-11-23: `Goal.why` und `Goal.verdictRaw` (beide optional, additiv). Ältere
App-Versionen ignorieren die Felder; ohne Deploy fehlen sie in Production.

„Läuft in Xcode, tot in TestFlight" ist fast immer dieser Schritt.

## Sync im TestFlight-Build diagnostizieren

Ereignisse gehen über `cloudSyncLog` ins System-Log — in Console.app nach Subsystem
`com.marcomeisen.Anchor` und Kategorie `CloudSync` filtern. Bewusst `notice`/`error`, weil
`debug` und `info` nicht dauerhaft gespeichert werden.

`CloudSyncErrorFormatter.describe(_:)` löst `CKError` auf: Code mit Klartextnamen, Teilfehler
aus `partialErrorsByItemID`, verschachtelte `NSUnderlyingError`. Niemals auf
`localizedDescription` allein verlassen — bei CloudKit steht dort meist nichts Verwertbares.

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
