# Task-Interaktionskonzept — Fyndara

Best-in-class-Referenz: die Gesten- und Menüsprache von Things 3, Apple Erinnerungen und Apple Mail — progressive Offenlegung statt einer einzigen überladenen Bearbeitungsseite. Eine Aufgabe wird nie über einen eigenen "Bearbeitungsmodus"-Screen bearbeitet, sondern direkt in der Liste, über drei sich ergänzende Zugriffswege.

---

## 1. Grundprinzip: drei Zugriffswege, eine Handlungsmenge

| Zugriffsweg | Trigger | Zeigt | Wann sinnvoll |
|---|---|---|---|
| **Swipe** | Wischen auf der Zeile | 1–2 häufigste Aktionen sofort ausführbar | Schnelle Alltagsaktion, eine Hand, kein Nachdenken |
| **Kontextmenü (Long-Press / Rechtsklick)** | Gedrückt halten (iOS/iPadOS) oder Rechtsklick (Mac) | Vollständige Aktionsliste inkl. Untermenüs | Seltenere/komplexere Aktion, Auswahl aus vielen Optionen |
| **Mehrfachauswahl-Modus** | "Auswählen"-Button oder Long-Press auf Checkbox | Aktionsleiste unten für alle markierten Aufgaben | Aufräumen, mehrere Aufgaben auf einmal verschieben/löschen |

Keine Aktion existiert nur an einer Stelle — jede swipebare Aktion ist auch im Kontextmenü vorhanden (Redundanz ist hier bewusst: Auffindbarkeit vor Effizienz für Erstnutzer, Effizienz vor Erklärung für Power-User).

---

## 2. Aktionsmatrix

| Aktion | Swipe | Kontextmenü | Mac-Kurzbefehl | Haptik | Rückgängig? |
|---|---|---|---|---|---|
| Als erledigt markieren | Leading (→) | ✓ Als erledigt markieren | ⌘. | `.impactLight` beim Antippen | Ja, 4 s Toast |
| Als offen markieren | Leading (→) auf erledigter Aufgabe | ↩︎ Als offen markieren | ⌘. | `.impactLight` | Ja |
| Löschen | Trailing (←), volle Strecke | 🗑 Löschen | ⌘⌫ | `.notificationSuccess` nach Bestätigung | Ja, 4 s Toast |
| In andere Woche verschieben | Trailing (←), Teilstrecke → „Verschieben"-Button | 📅 Verschieben nach ▸ (Untermenü) | ⌘⇧M | `.impactMedium` beim Einrasten des Sheets | Ja |
| Priorität ändern (A/B/C) | — (zu selten für Swipe) | Priorität ▸ (Untermenü) | ⌘1 / ⌘2 / ⌘3 | `.impactLight` | Ja |
| Mit Wochenziel verknüpfen/lösen | — | 🎯 Mit Ziel verknüpfen ▸ | — | `.impactLight` | Ja |
| Duplizieren | — | 📋 Duplizieren | ⌘D | `.impactLight` | Ja |
| Mehrfachauswahl starten | — | — (eigener Button) | ⌘⇧A | — | — |

**Faustregel für die Swipe-Auswahl:** Nur die zwei häufigsten Aktionen bekommen einen Swipe (erledigt = Leading, löschen/verschieben = Trailing). Alles andere verwässert die Geste und macht sie unvorhersehbar — das ist der häufigste Fehler bei "Swipe-Aktionen-Überladung" in weniger guten Apps.

---

## 3. Swipe-Spezifikation im Detail

**Leading Swipe (von links nach rechts ziehen) — nur eine Aktion:**
- Ab 25 % Zeilenbreite: grüner Hintergrund erscheint, Checkmark-Icon fadet ein
- Ab 60 % Zeilenbreite ODER vollständiges Durchziehen: Aktion löst sofort aus (kein Zwischenstopp, kein Bestätigungsbutton nötig — Erledigt-Markieren ist nicht destruktiv)
- Antwort: Zeile bekommt Strikethrough-Animation (200 ms ease-out) auf dem Titel, Checkbox füllt sich, Zeile rutscht ans Ende der Prio-Sektion (350 ms spring)

**Trailing Swipe (von rechts nach links ziehen) — zwei Aktionen:**
- Ab 25 % Zeilenbreite: „Verschieben"-Button erscheint (Indigo, Kalender-Icon)
- Ab 50 % Zeilenbreite: zusätzlich „Löschen"-Button (Rot, Papierkorb-Icon) daneben
- Teilstrecke + Loslassen: Buttons bleiben eingerastet stehen, Nutzer tippt gezielt einen der beiden an
- Volle Strecke durchgezogen (>85 %): Löschen löst direkt aus (das ist die einzige Aktion, die bei voller Wischstrecke ausgelöst wird — Verschieben erfordert immer einen gezielten Tap, da es eine Zusatzentscheidung braucht)

---

## 4. Kontextmenü (Long-Press / Rechtsklick)

Aufbau von oben nach unten (folgt Apples eigener Kontextmenü-Konvention: Vorschau → primäre Aktionen → Untermenüs → destruktive Aktion ganz unten, per Trennlinie abgesetzt):

```
┌─────────────────────────────┐
│   [vergrößerte Task-Karte]  │  ← Peek-Preview, keine Aktion
├─────────────────────────────┤
│ ✓  Als erledigt markieren   │
│ 📅 Verschieben nach      ▸  │  ← Untermenü
│ 🎯 Mit Ziel verknüpfen   ▸  │  ← Untermenü
│ ⚑  Priorität             ▸  │  ← Untermenü
│ 📋 Duplizieren               │
├─────────────────────────────┤
│ 🗑  Löschen              (rot)│  ← destruktiv, immer isoliert unten
└─────────────────────────────┘
```

Untermenü „Verschieben nach ▸":
```
Heute
Morgen
Diese Woche ▸ (Mo–So zur Auswahl)
Nächste Woche
Datum wählen …
```

---

## 5. Mehrfachauswahl-Modus

- Aktivierung: Button „Auswählen" in der Navigationsleiste, oder Long-Press auf eine Checkbox (dann ist diese Aufgabe direkt vorausgewählt)
- Jede Zeile bekommt eine Auswahl-Checkbox links, Tap wechselt Auswahlzustand
- Aktionsleiste erscheint unten (Glas-Material, wie Tab-Leiste), zeigt Auswahlzähler + 4 Buttons: Erledigt / Verschieben / Priorität / Löschen
- Löschen mehrerer Aufgaben zeigt eine Bestätigung, wenn ≥ 3 Aufgaben betroffen sind (Schwelle bewusst >1, damit Aufräumen von 1–2 Aufgaben nicht durch ein Popup gebremst wird)

---

## 6. Rückgängig-Mechanismus

- Nach Löschen oder Erledigt-Markieren erscheint unten ein Toast: „Aufgabe gelöscht · Rückgängig"
- 4 Sekunden sichtbar, mit dünnem Fortschrittsbalken, der die verbleibende Zeit zeigt
- Tap auf „Rückgängig" macht die letzte Aktion exakt rückgängig (Zeile erscheint an ursprünglicher Position, keine "irgendwo unten neu einfügen"-Krücke)
- Mehrere schnelle Löschungen stapeln sich nicht zu einem Toast — jede Aktion bekommt ihren eigenen Toast, der vorherige wird beim Erscheinen des neuen sofort verdrängt (kein Toast-Stapel-Chaos)

---

## 7. Barrierefreiheit (Pflicht, nicht optional)

- **Jede** Swipe-Aktion muss zusätzlich als `accessibilityAction` verfügbar sein — VoiceOver-Nutzer:innen wischen zur Navigation, nicht für App-Gesten, und würden sonst ausgeschlossen
- Kontextmenü ist für VoiceOver nativ zugänglich (Doppeltipp-und-Halten löst es aus) — hier ist SwiftUIs `.contextMenu` bereits barrierefrei, sofern keine Custom-Gesture-Recognizer das überschreiben
- Destruktive Aktionen (Löschen) brauchen ein klares `accessibilityLabel`, das die Konsequenz nennt („Aufgabe löschen", nicht nur „Löschen")
- Bei `reduceMotion`: Strikethrough- und Spring-Animationen werden durch einfaches Fade (150 ms) ersetzt, keine Bewegung/Skalierung

---

## 8. Plattformunterschiede

| | iPhone | iPad | Mac |
|---|---|---|---|
| Primärer Zugriff | Swipe | Swipe + Kontextmenü | Rechtsklick-Kontextmenü |
| Verschieben | Swipe → Sheet | Swipe → Sheet ODER Drag auf Sidebar-Woche | Drag auf Sidebar-Woche ODER ⌘⇧M |
| Mehrfachauswahl | Button „Auswählen" | Button „Auswählen" ODER ⌘-Klick | ⌘-Klick / Shift-Klick wie im Finder |
| Tastaturkürzel | — | Extern: gleiche wie Mac | Vollständig (Tabelle Abschnitt 2) |

**Drag & Drop auf iPad/Mac:** Beim Ziehen einer Aufgabe auf einen Wochen- oder Tages-Eintrag in der Sidebar hebt sich der Zieleintrag optisch hervor (Glas-Highlight + leichte Vergrößerung), beim Loslassen kurzes Bestätigungs-Haptik (Mac: kein Haptik, stattdessen kurzer Farb-Flash am Zielelement).

---

## 9. SwiftUI-Implementierungshinweise

```swift
// Swipe Actions
.swipeActions(edge: .leading, allowsFullSwipe: true) {
    Button { task.toggleDone() } label: { Label("Erledigt", systemImage: "checkmark") }
        .tint(.green)
}
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button(role: .destructive) { deleteWithUndo(task) } label: { Label("Löschen", systemImage: "trash") }
    Button { showMoveSheet(task) } label: { Label("Verschieben", systemImage: "calendar") }
        .tint(AnkerColor.indigo) // Tokenname ggf. an finalen Markennamen anpassen
}

// Context Menu
.contextMenu {
    Button { task.toggleDone() } label: { Label("Als erledigt markieren", systemImage: "checkmark") }
    Menu("Verschieben nach") {
        Button("Heute") { move(task, to: .today) }
        Button("Morgen") { move(task, to: .tomorrow) }
        Menu("Diese Woche") { /* Mo–So Buttons */ }
        Button("Nächste Woche") { move(task, to: .nextWeek) }
        Button("Datum wählen …") { showDatePicker(task) }
    }
    Menu("Mit Ziel verknüpfen") { /* dynamische Zielliste */ }
    Menu("Priorität") {
        Button("A – Wichtig & dringend") { task.priority = .a }
        Button("B – Wichtig") { task.priority = .b }
        Button("C – Kann warten") { task.priority = .c }
    }
    Button { duplicate(task) } label: { Label("Duplizieren", systemImage: "doc.on.doc") }
    Divider()
    Button(role: .destructive) { deleteWithUndo(task) } label: { Label("Löschen", systemImage: "trash") }
} preview: {
    TaskPreviewCard(task: task) // Peek-Preview, kein interaktives Element
}

// Undo-Toast (eigene View, kein natives API dafür)
@State private var undoContext: UndoContext?
// ... ToastView unten im ZStack, 4s Timer, Fortschrittsbalken via TimelineView
```

Rückgängig-Mechanismus **nicht** über `UIKit UndoManager` allein lösen — der ist gut für Shake-to-Undo/⌘Z, aber die sichtbare Toast-UI mit Fortschrittsbalken muss als eigene View gebaut werden, die intern denselben `UndoManager` anspricht (Doppelnutzung: Toast-Tap UND ⌘Z lösen dieselbe Rückgängig-Funktion aus).

---

*Visuelle Referenz für alle hier beschriebenen Zustände: siehe beigefügte HTML-Datei mit den 5 Kernbildschirmen.*
