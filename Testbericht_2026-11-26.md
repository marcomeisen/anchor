# Testbericht Anchorit — 26.11.2026

Stand: `main` @ 32021c0, Xcode 27.2. Geprüft auf macOS (Mac, signiert) und iOS-Simulator
(„iPhone Duo“, unsigniert).

## 0. Stand der Behebung (26.11., nach dem Bericht)

| Befund | Stand | Nachweis |
|---|---|---|
| H1 Startbildschirm-Test auf echten Daten | ✅ behoben | Läuft im Testmodus mit Beispieldaten, 4 von 4 grün (macOS) |
| M12 veraltete UI-Tests | ✅ behoben | Mac-UI-Suite 9 von 9 grün; die Tests laufen nur noch auf macOS |
| H2 Tagesdetail schreibt in den falschen Tag | ✅ behoben | Unit-Tests grün; kein eigener UI-Test |
| H4 Einplanen hält gelöschte Aufgabe | ✅ behoben | iOS-Build grün; kein eigener UI-Test |
| H5 Ankeransicht bleibt nach dem Löschen | ✅ behoben | Neuer UI-Test `testDeletingAnAnchorLeavesItsScreen` grün |
| H7 Anker ohne Aufgabe nicht zu öffnen | ❌ offen, eingegrenzt | Nur das mittlere Band der Zelle reagiert nicht; siehe H7 |
| H3 Zeitzonen ab 12 h | ✅ behoben | `Day.dayKey`, `Week.nominalMonday`; Tests New York → Tokio, Berlin → Neuseeland, Zusammenführen, Nachtragen. **Schema-Deploy nötig** |
| M2 Versionsnummern als Datum | ✅ behoben | Jahresfenster Vorjahr bis +5, Jahr im Hinweis; Tests |
| N3 überschriebenes Wort im Titel | ✅ behoben | Nur Kürzel, die zugleich Wörter sind (de „so“, en „we“, „sat“, „sun“), kehren zurück; echte Korrekturen („Bericht fr morgen“) fallen weiter weg |
| N4 Schlusspunkt-Datum | ✅ als Test festgehalten | `testTrailingDotMakesADate` |
| N2 Monatlich-Drift | ✅ behoben | Rohtext `monthly:31` nur für den 29.–31.; ältere Versionen lesen ihn als einmalig. Test |
| M5 Loslassen beendet Wiederholung | ✅ behoben | Folgeinstanz am nächsten Termin nach der Woche; zwei Tests |
| N1 Undo lässt leere Woche/Tag | ✅ behoben | Undo löscht leer gewordene Tage und Wochen (nichts mit Inhalt); zwei Tests |
| N7 leerer Anker bricht Serie | ✅ behoben | Test |
| M6 Onboarding-Anker verdrängen echte | ✅ behoben | Gleichstand über `Goal.createdAt` (neu, **Schema-Deploy**), Aufgaben zählen weiter nicht; Test |
| M7 `adoptOrphans` löst Anker | ✅ entschärft | Zehn Minuten Karenz (im Speicher) vor dem Lösen; Test |
| N5 falsches „Nichts zu übertragen“ | ✅ behoben | Nur bei `.available`; nicht automatisch getestet |
| N6 einzelne `phase` | ✅ behoben | Laufende Ereignisse als Menge nach `identifier`; nicht automatisch getestet |
| N15 Warnungen CloudSyncStatus | ✅ behoben | 3 von 9; die übrigen liegen in Views |
| H6 Sync bleibt aus | ✅ behoben | Testmodus mit eigenem Defaults-Bereich (`UITestMode.appStorage`, `ankerAppStorage()` an jeder Szene), `.standard` bleibt unberührt; Schnellerfassung erst nach der iCloud-Wahl. Tests `testUITestModeKeepsItsOwnDefaults`, `testCloudSyncFallbackWithoutStoredChoice`. Bereits geschädigte Altinstallationen holt das nicht zurück: dort in den Einstellungen iCloud einschalten |
| M4 Erinnerung öffnet falsche Woche | ✅ behoben | `apply(_:now:)`; Test `testReminderLinksWithoutDateOpenTheCurrentWeek` |
| M3 Rohdaten in Views | ✅ behoben | AnchorScreen über `WeekSheet(week:)`, Menü „Verschieben auf“, „In die nächste Woche“ (TaskCard), Suchsprung, Tagesbeschriftungen der Woche, Heute-Marke der Seitenleiste, Aufgabeneditor. Offen bleibt `TaskChip` (M8, nächstes Paket). Kein Zonentest der Views |
| N11 Popover-Größe | ✅ behoben | `sizingOptions = .preferredContentSize`, Höhe aus dem Inhalt; nicht am Gerät geprüft |
| M1 Wischaktionen wirken nirgends | ✅ behoben | Eigene Wischgeste `.taskSwipe` (UIKit-Pan, beginnt nur bei deutlich waagerechter Bewegung) statt `List`-Umbau: der hätte Abstände, Karten und das Ziehen auf jedem Bildschirm verändert. Rechts erledigt, links löschen, beides mit Undo. iOS-Build grün; **am Gerät nicht geprüft** |
| M8 „Nächste Woche“ am Chip ab heute | ✅ behoben | Ab Tag bzw. `nominalMonday` der Ankerwoche |
| M9 VoiceOver „Ohne Anker“ im Raster | ✅ behoben | Nummer aus `linkedGoal` über `GoalOrdering` |
| M10 Ablegen in fremder Woche verschwindet | ✅ behoben | Hinweis „In den Eingang gelegt“, wenn die Woche den Eingang nicht zeigt; Test `testDropIntoInboxFromAnotherWeekSaysWhereTheTaskWent` |
| M11 langes Drücken aufs Kästchen | ✅ behoben | Geste entfernt; die Mehrfachauswahl beginnt über „Auswählen“ im Kontextmenü der Zeile oder neben dem Abschnitt |
| N8 Hinweis ohne Änderung | ✅ behoben | Raster und Ankerspalten melden nur echte Änderungen |
| N9 an der Mutationsschicht vorbei | ✅ behoben | `GoalActions.update` im Ankereditor, neu `GoalActions.setVerdict`; Test `testVerdictIsOnlyWrittenWhenItChanges` |
| N10 ⌘Z doppelt belegt | ✅ behoben | Nur die zuletzt gezeigte Undo-Leiste trägt ⌘Z (`UndoShortcutOwner`); tippt ein Textfeld, geht ⌘Z an dessen Undo. Nicht im UI-Test geprüft |
| N12 „1 Wochen, 1 Aufgaben“ | ✅ behoben | Einzahl und Mehrzahl je Zählwort, de und en |
| N13 Rückblick verspricht fehlenden Knopf | ✅ behoben | Text ohne „abschließen“, wenn die Woche nie gespeichert wurde |
| N14 Anker im Setzen nicht entfernbar | ✅ behoben | Entfernen-Knopf pro Zeile; bestehende Anker werden erst beim „Woche beginnen“ gelöscht, ihre Aufgaben bleiben ohne Anker, ein Hinweis sagt das |
| N15 übrige Warnungen | ✅ behoben | macOS- und iOS-Build ohne Warnung |
| H7 (Nachtrag Paket C) | ❌ offen | Im Code liegt über der Ankerleiste nichts: kein Overlay, keine Positionierung, das Onboarding wird über `if` ersetzt. Ohne Mac-UI-Lauf keine belastbare Ursache |

## 1. Ergebnis auf einen Blick

| Prüfung | macOS | iOS-Simulator |
|---|---|---|
| Build | ✅ fehlerfrei, 9 Compiler-Warnungen (N15) | ✅ |
| Unit-Tests (`AnchorTests`, 191 Fälle) | ✅ alle grün | ✅ alle grün |
| UI-Tests `AnchorUITests` | ❌ 2 von 4 rot (M12) | ❌ 3 von 4 rot (M12) |
| UI-Test `PhoneChromeTests` | – (nur iOS) | ✅ 5 von 5 |
| UI-Test Startbildschirm | ✅, aber auf **echten Daten** (H1) | ❌ Absturz (H1) |
| `design-guard` | ✅ alle Schranken halten | |
| `l10n-guard` | ✅ 515 Schlüssel, alle de + en | |
| Plists (Entitlements, Privacy Manifest, Info) | ✅ gültig | |

Dazu kam eine Code-Prüfung aller Funktionsbereiche: Daten und Sync, Erfassung und Logik, Oberfläche.
Jeder Befund wurde an der Codezeile nachgelesen. **Bestätigt** heißt, dass Fehlerpfad oder Rechnung
belegt sind. **Plausibel** heißt, dass der Fehler nach dem Code wahrscheinlich ist, aber nicht in der
laufenden App nachgestellt wurde.

Die Logik ist solide, der Kern ist gut abgesichert:
- Die Unit-Tests sind vollständig grün.
- Die Duplikatregel hält: Es gewinnt überall die kleinste UUID.
- Die Löschregeln stehen auf `.nullify`.
- Export und Löschung sind vollständig.
- Die Lokalisierung ist lückenlos.
- Keine View legt beim Anzeigen eine Woche an.

Schwach sind drei Stellen: die UI-Tests, Geräte in **weit auseinanderliegenden Zeitzonen** und
einige **Interaktionen auf dem iPhone**.

---

## 2. Hoch — vor dem Release beheben

### H1 · Der Startbildschirm-Test läuft gegen echte Daten und echtes iCloud  *(bestätigt)*
- **Wo:** [AnchorUITestsLaunchTests.swift:23](AnchorUITests/AnchorUITestsLaunchTests.swift#L23)
- **Was passiert:** `app.launch()` startet ohne `-AnchoritUITest`. Auf dem Mac lief der Test viermal
  gegen den echten Store des Nutzers, mit CloudKit, und legt Bildschirmfotos echter Daten ins
  Testergebnis.
- **Was passiert im unsignierten Simulator:** Die App stürzt in
  `CloudSyncStatusCenter.refreshAccountStatus()` ab ([CloudSyncStatus.swift:316](Anchor/CloudSyncStatus.swift#L316),
  `CKContainer` ohne Entitlement). Absturzberichte: `~/Library/Logs/DiagnosticReports/Anchorit-2026-11-26-0935*.ips`.
- **Lösung:** Dieselben Startargumente wie in `AnchorUITests.launchApp()` setzen
  (`-AnchoritUITest -AppleLanguages (de)`). Besser noch eine gemeinsame Hilfsfunktion, damit kein
  UI-Test mehr ohne Testmodus starten kann.

### H2 · Das Tagesdetail schreibt Fokus und Notiz in den falschen Tag  *(bestätigt)*
- **Wo:** [DayDetailView.swift:25](Anchor/DayDetailView.swift#L25) und [DayDetailView.swift:341](Anchor/DayDetailView.swift#L341)
- **Schritte:**
  1. Den Montag öffnen.
  2. Als Fokus „A“ tippen.
  3. Über die Suche (⌘F) eine Aufgabe vom Donnerstag öffnen. Dasselbe passiert, wenn die Ansicht über Mitternacht offen bleibt.
- **Folge:** Die View bleibt dieselbe, die Entwürfe werden nicht neu geladen (`hasLoadedDrafts`).
  Angezeigt werden die Aufgaben vom Donnerstag, aber Fokus und Notiz vom Montag. Beim Verlassen
  landet „A“ im Donnerstag, und Woche und Tag werden dafür angelegt.
- **Lösung:** `DayDetailView(…).id(navigation.dayDate)` in [AnkerRootView.swift:431](Anchor/AnkerRootView.swift#L431).
  Alternativ `.onChange(of: date)`: zuerst den alten Entwurf sichern, dann neu laden.

### H3 · Zwischen Zeitzonen mit 12 Stunden Abstand oder mehr springen Aufgaben auf einen anderen Tag  *(bestätigt durch Rechnung)*
- **Wo:** [CalendarLogic.swift:96](Anchor/CalendarLogic.swift#L96) (`nominalDay(ofStored:)` addiert +12 h)
- **Was passiert:** Ein Montag wird in New York angelegt (00:00 EST). In Tokio ist das Montag
  14:00, plus 12 h ergibt Dienstag. Zwischen Berlin und Neuseeland im Südsommer reicht schon der
  Abstand von genau 12 h.
- **Folge:** Die Aufgabe steht einen Tag zu spät. Schlimmer ist der Sync:
  `StoreMaintenance.mergeDuplicateDays` führt den fremden „Montag“ mit dem eigenen Dienstag zusammen.
  Die Aufgaben wandern **dauerhaft** auf einen anderen Tag, und die Geräte kommen nicht zum selben
  Ergebnis.
- **Wer ist betroffen:** Selten, aber realistisch bei Reisen oder einem Gerät in einer anderen
  Region. Der Kommentar im Code nennt die Grenze selbst.
- **Lösung:** Ein optionales, additives Feld `Day.dayKey: String?` („2026-11-23“), das beim Anlegen
  geschrieben wird. Die 12-h-Regel bleibt nur der Rückfall für Altbestand. Sofortmaßnahme: Tage nur
  zusammenführen, wenn auch ihre Rohdaten weniger als 12 h auseinanderliegen. Danach das Schema nach
  Production bringen ([CloudKit_Schema_Anleitung.md](CloudKit_Schema_Anleitung.md)).

### H4 · Einplanen auf dem iPhone hält eine gelöschte oder fremde Aufgabe fest  *(Absturz plausibel, Wochenwechsel bestätigt)*
- **Wo:** [WeekScreen.swift:27](Anchor/WeekScreen.swift#L27) (`placing`) und [WeekScreen.swift:193-216](Anchor/WeekScreen.swift#L193-L216)
- **Fall A (Absturz plausibel):**
  1. Einen Chip antippen; er ist jetzt gewählt.
  2. Lang drücken und „Löschen“ wählen.
  3. Die Leiste „Jetzt einen Tag wählen“ bleibt stehen. Ein Tipp auf „Hierher“ arbeitet auf dem
     gelöschten Objekt; die Folge ist ein Absturz oder eine Geisterzeile.
- **Fall B (bestätigt):** Die Auswahl überlebt den Wechsel in eine andere Woche. Dort legt „Hierher“
  die Aufgabe ab und löst still ihren Anker.
- **Lösung:** `placing` als UUID halten und beim Rendern auflösen; ist die Aufgabe gelöscht, ist die
  Auswahl leer. Bei einem Wechsel von `weekStart` und bei jeder Chip-Aktion zurücksetzen.

### H5 · Nach „Anker löschen“ bleibt die Ankeransicht stehen  *(plausibel)*
- **Wo:** [AnkerRootView.swift:415](Anchor/AnkerRootView.swift#L415) (`{ navigation.popToTopLevel() }`)
  und [AnkerRootView.swift:434](Anchor/AnkerRootView.swift#L434) (`onSelectGoal`)
- **Was passiert:** Beide Closures entstehen im escapenden Baustein von `navigationDestination`.
  Genau dieses Muster „tat sichtbar nichts“ ([changelog.md:332](changelog.md#L332)), und CLAUDE.md
  verbietet es.
- **Folge:** Nach dem Löschen zeigt die Ansicht weiter das gelöschte `goal`; auch ein Absturz ist
  möglich. Im Tagesdetail öffnet ein Tipp auf eine Ankerzeile vermutlich nichts.
- **Lösung:** In `AnchorScreen` nach dem Löschen `@Environment(\.dismiss)` aufrufen. Die Ankerzeile im
  Tagesdetail als `NavigationLink(value: AppDestination.goal(id))` bauen. Dazu ein UI-Test, der
  einen Anker wirklich löscht.

### H6 · Wird das Onboarding umgangen, bleibt iCloud-Sync dauerhaft aus  *(plausibel)*
- **Wo:** `CloudSyncPreference.isEnabled()` ([AppSettings.swift:291](Anchor/AppSettings.swift#L291)) hängt an
  `hasCompletedOnboarding`.
- **Weg 1:** Auf einem frischen Mac ist das Onboarding offen. Über die Menüleiste
  ([AnchorApp.swift:383](Anchor/AnchorApp.swift#L383)) wird eine Aufgabe erfasst. Damit ist
  `hasContent` wahr, das Onboarding verschwindet, und die iCloud-Frage wird nie gestellt.
- **Weg 2:** Ein UI-Testlauf auf dem Entwicklungs-Mac entfernt `hasCompletedOnboarding`
  ([AppSettings.swift:37-42](Anchor/AppSettings.swift#L37-L42)). Eine Altinstallation ohne gespeicherten
  `cloudSyncEnabled` startet danach ohne Sync. Weil schon Daten da sind, erscheint kein Onboarding,
  das den Wert wieder setzen könnte.
- **Zusatz:** Umgekehrt **schreibt** der Testmodus über `@AppStorage` die Werte
  `hasCompletedOnboarding` und `onboardingVersion` ([AnkerRootView.swift:475-488](Anchor/AnkerRootView.swift#L475-L488)).
  Das verstößt gegen die Regel „Der Testmodus hinterlässt nichts“.
- **Lösung:** Die Schnellerfassung erst nach der iCloud-Wahl anbieten. `isEnabled()` an
  `hasBeenChosen()` statt an `hasCompletedOnboarding` koppeln. Der Testmodus bekommt eigene Defaults
  (`UserDefaults(suiteName:)`).

### H7 · Ein Anker ohne Aufgabe lässt sich auf dem Mac nicht öffnen  *(bestätigt, nachträglich gefunden)*
- **Wo:** Ankerleiste auf „Heute“ ([BlattComponents.swift:105](Anchor/BlattComponents.swift#L105)), Navigation in [AnkerRootView.swift:402](Anchor/AnkerRootView.swift#L402)
- **Schritte:**
  1. Frisch starten.
  2. Im Onboarding einen Anker setzen.
  3. Auf „Heute“ die Ankerzelle 1 anklicken.
- **Folge:** Die App bleibt auf „Heute“. Mit einer Aufgabe öffnet derselbe Klick die Ankeransicht.
  Ohne Aufgabe gibt es also keinen Weg, Warum-Satz und Titel über die Ankeransicht zu bearbeiten oder
  den Anker zu löschen.
- **Belegt durch:**
  - UI-Probeläufe: Ohne Aufgabe scheitert der Klick, auch nach 3 s Wartezeit und nach einem Klick ins
    Fenster. Mit einer Aufgabe gelingt er.
  - Derselbe Lauf auf dem unveränderten Stand `main`: Der Fehler besteht dort genauso, er ist also
    nicht durch die Fixes entstanden.
- **Eingrenzung (Diagnoselauf mit protokolliertem Navigationszustand):**
  - Die Aktion des Knopfes läuft gar nicht: `onOpenAnchor` wird nicht aufgerufen, `destination` bleibt `.today`. Es ist also kein Navigationsfehler und keine Rücknahme über `pushedPath`.
  - Es hängt an der **Klickstelle**: Ein Klick in die obere Zeile (Nummer, Zähler) oder ganz unten öffnet den Anker auch ohne Aufgabe. Nur das mittlere Band auf Höhe des Titels reagiert nicht, über die ganze Breite. XCUITest klickt in die Mitte, deshalb scheiterte der Test.
  - Der AppKit-Treffer an der Stelle ist die `NSClipView` der Scroll-Ansicht, also keine fremde AppKit-Ansicht darüber. Es fängt etwas innerhalb von SwiftUI den Klick.
  - Nach der ersten Datenänderung (Aufgabe erfasst) reagiert das Band wieder. Ein Klick ins Erfassungsfeld oder ein Wechsel nach „Woche“ und zurück hilft nicht.
  - Das Band liegt genau auf der Höhe des ersten Onboarding-Felds (y 97–119 gegenüber Zellmitte 110). Den Fokus im Onboarding vor dem Abschluss zu lösen (`focusedSlot = nil`), behebt es aber nicht.
- **Nächster Schritt:** Prüfen, ob ein Überbleibsel des Onboardings (Textfeld, Fokusbereich) im neu aufgebauten Fensterinhalt Klicks schluckt. Zum Beispiel das Fenster nach dem Onboarding über `.id` neu aufbauen, `makeFirstResponder(nil)` aufrufen, oder die Zeile anders anordnen und vergleichen. Jeder Versuch braucht einen Mac-UI-Lauf; die weiteren Läufe hat der Nutzer in dieser Runde abgelehnt. Der Test `testDeletingAnAnchorLeavesItsScreen` legt deshalb weiter zuerst eine Aufgabe an.

---

## 3. Mittel

| # | Befund | Folge | Lösung |
|---|---|---|---|
| **M1** | **Wischaktionen wirken nirgends** ([AnkerComponents.swift:312](Anchor/AnkerComponents.swift#L312)). `TaskCard` steht überall in `VStack`/`ScrollView`, `.swipeActions` geht aber nur in einer `List`. *bestätigt* | Auf dem iPhone fehlen „Erledigt“ und „Löschen“ per Wisch, obwohl das Interaktionskonzept sie als Hauptweg nennt. | Die Listen als `List` mit eigenem Zeilenhintergrund bauen oder eine eigene Wischgeste schreiben. |
| **M2** | **Versionsnummern werden zu Daten** ([CaptureSyntax.swift:250](Anchor/CaptureSyntax.swift#L250)). *bestätigt* | `Release 1.2.10` wird zum 01.02.2010, `Patch 3.1.24` zum 03.01.2024. Die Aufgabe verschwindet in eine alte Woche, und die Hinweiszeile zeigt kein Jahr. | Jahre weit außerhalb von heute (etwa −1 bis +5) nicht als Datum lesen. Weicht das Jahr ab, es im Hinweis zeigen. |
| **M3** | **Rohe Tagesdaten statt `nominalDate`**: [AnchorScreen.swift:24](Anchor/AnchorScreen.swift#L24) (`WeekSheet(monday:)`), Menü „Verschieben auf“ [AnkerComponents.swift:610](Anchor/AnkerComponents.swift#L610), Suchsprung [AnkerRootView.swift:470](Anchor/AnkerRootView.swift#L470), Heute-Marke [SidebarTimeline.swift:31](Anchor/SidebarTimeline.swift#L31), [WeekScreen.swift:357](Anchor/WeekScreen.swift#L357). *bestätigt, wirkt nur bei Zonenversatz* | Eine Woche aus einer östlicheren Zone, westlich davon angesehen: Die Ankerseite ist leer, das Menü bietet So–Sa an, „Verschieben“ landet einen Tag zu früh, die Suche öffnet die Vorwoche, „heute“ sitzt falsch. | Überall `WeekSheet(week:)`, `AnkerCalendar.nominalDate(ofStored:)` und `storedDay(_:isOn:)` verwenden. Dafür einen design-guard-ähnlichen Grep auf `.monday`/`day.date` in Views. |
| **M4** | **Die Erinnerung öffnet die falsche Woche** ([AppNavigation.swift:213](Anchor/AppNavigation.swift#L213), [AnkerRootView.swift:115](Anchor/AnkerRootView.swift#L115)). *bestätigt* | Wer zuletzt die nächste Woche angesehen hat, bekommt am Sonntag über „Rückblick“ die nächste statt der laufenden Woche. Ebenso springt die Montags-Erinnerung nicht zur neuen Woche. | `anchorit://review` und `anchorit://week` ohne Argument auf die Woche von heute setzen, oder das Datum in den Link schreiben. |
| **M5** | **„Loslassen“ beendet eine Wiederholung still** ([WeekActions.swift:189](Anchor/WeekActions.swift#L189)). *bestätigt* | Die wöchentliche Aufgabe „Sport“ wurde nicht erledigt. Im Rückblick „loslassen“ löscht die einzige Instanz mit der Regel, ohne Undo. | Vor dem Löschen die nächste Instanz erzeugen, oder ausdrücklich fragen: „Wiederholung beenden?“ |
| **M6** | **Beim Zusammenführen verdrängen frische Onboarding-Anker echte** ([StoreMaintenance.swift:212](Anchor/StoreMaintenance.swift#L212), `usageRank`). *bestätigt (Logik)* | Ein neues Gerät legt vier Anker an, bevor der Import fertig ist. Echte Anker mit Aufgaben, aber ohne Warum-Satz, landen im selben Rang. Zwei echte Anker fallen heraus, ihre Aufgaben gehen nach „ohne Anker“. | Ein Anker mit Aufgaben bekommt einen höheren Rang. Alternativ Onboarding-Anker markieren. |
| **M7** | **`adoptOrphans` kann Aufgaben dauerhaft vom Anker lösen** ([StoreMaintenance.swift:380](Anchor/StoreMaintenance.swift#L380)). *plausibel* | Kommt die Löschung einer Duplikat-Woche vor dem Update des Ziels an, und die Wartung läuft dazwischen, verlieren Aufgaben ohne Tag ihren Anker. | Solche Aufgaben nur im Eingang **anzeigen**, statt `linkedGoal` zu löschen. Oder erst nach einer Karenzzeit lösen. |
| **M8** | **„In die nächste Woche“ am Chip rechnet ab heute** ([BlattComponents.swift:358](Anchor/BlattComponents.swift#L358)). *bestätigt* | Auf dem Mac ist KW 50 offen, heute ist KW 48. Eine Aufgabe ohne Tag landet in KW 49, also rückwärts, und verliert ihren Anker. | Ab der Woche des Ankers rechnen (`owningWeek`), wie `TaskCard` es tut. |
| **M9** | **VoiceOver liest im Raster jede Aufgabe als „Ohne Anker“** ([BlattComponents.swift:317](Anchor/BlattComponents.swift#L317)). Die Aufrufe übergeben keine `number`. *bestätigt* | Die Angabe ist für blinde Nutzer falsch. | Die Ankernummer aus `task.linkedGoal` über `GoalOrdering` bilden. |
| **M10** | **Ablegen auf „ohne Anker“ in einer fremden Woche lässt die Aufgabe verschwinden** ([WeekScreen.swift:649](Anchor/WeekScreen.swift#L649), [WeekScreen.swift:772](Anchor/WeekScreen.swift#L772)). *bestätigt* | Der Eingang erscheint nur in der laufenden Woche. Die Aufgabe ist weg, der Hinweis sagt nur „Ohne Anker gelegt“. | Im Hinweis „in den Eingang“ sagen, oder das Ziel in fremden Wochen auf den Montag einplanen. |
| **M11** | **Langes Drücken aufs Kästchen** ([AnkerComponents.swift:224](Anchor/AnkerComponents.swift#L224)): `simultaneousGesture` zusammen mit dem Kontextmenü der Karte. *plausibel* | Die Auswahl startet, gleichzeitig öffnet sich das Menü, oder die Aufgabe wird beim Loslassen abgehakt. | `highPriorityGesture` verwenden oder das Kästchen vom Kontextmenü ausnehmen. Am Gerät prüfen. |
| **M12** | **Die UI-Testsuite ist veraltet und auf beiden Plattformen rot.** *bestätigt* | **(a)** [AnchorUITests.swift:42](AnchorUITests/AnchorUITests.swift#L42) erwartet „Prio A“; die App zeigt seit dem Release-Commit „wichtig“. **(b)** [AnchorUITests.swift:113](AnchorUITests/AnchorUITests.swift#L113) sucht den Titel als `staticText`; die Karte ist aber über `.accessibilityElement(children: .combine)` **ein** Knopf („Vertrag prüfen, Anker 1 · …“). **(c)** Auf iOS laufen die Mac-Tests mit `click()`/`rightClick()`, das bricht ab („Pointer events are not supported“). | (a) Die Erwartung auf „wichtig“ ändern. (b) Über `element(app, "taskCard")` gehen und dort doppelklicken, oder den Titel über einen Identifier erreichbar machen. (c) Die Mac-Tests unter `#if os(macOS)` oder mit `XCTSkip` auf iOS. Danach die Suite in jeden Release-Ablauf aufnehmen. |

---

## 4. Niedrig

| # | Befund | Lösung |
|---|---|---|
| N1 | Undo nach dem Abhaken einer täglichen Sonntagsaufgabe, nach „Verschieben“ oder „Duplizieren“ lässt eine leere Folgewoche oder einen leeren Tag zurück, der synchronisiert wird ([TaskActions.swift:495](Anchor/TaskActions.swift#L495)). | Neu angelegte Woche/Tag in der Undo-Notiz merken und beim Undo löschen, wenn sie leer sind. |
| N2 | „Monatlich“ ab dem 31.01. läuft 28.02., 28.03., … und driftet dauerhaft ([Models.swift:233](Anchor/Models.swift#L233)). | Den ursprünglichen Monatstag mitführen (Rohtext `monthly:31`, additiv). |
| N3 | Ein überschriebenes Kürzel verschwindet trotzdem aus dem Titel: „Mach das so morgen“ ergibt „Mach das“, „Ask if we may 5“ ergibt „Ask if“ ([CaptureSyntax.swift:140](Anchor/CaptureSyntax.swift#L140)). | Nur das wirksame Kürzel entfernen, die übrigen in den Titel zurücklegen. |
| N4 | „Python 3.12.“ wird zum 3. Dezember, „Kapitel 1.5.“ zum 1. Mai. Das ist so gewollt („Schlusspunkt“), aber nicht getestet. | Als Test festhalten. Der Hinweis zeigt das Datum ohnehin schon an. |
| N5 | „Jetzt synchronisieren“ meldet „iCloud-Account erreichbar“, auch wenn die Abfrage gescheitert ist ([CloudSyncStatus.swift:381](Anchor/CloudSyncStatus.swift#L381)). | `refreshAccountStatus` ein Ergebnis zurückgeben lassen und nur bei `.available` „Nichts zu übertragen“ melden. |
| N6 | `phase` ist nur ein einzelner Wert. Endet ein Export-Event während eines laufenden Imports, könnte das Aufräumen mitten im Import starten ([CloudSyncStatus.swift:463](Anchor/CloudSyncStatus.swift#L463)). *plausibel* | Laufende Events als Menge nach `identifier` führen. |
| N7 | Archiv: Eine Woche mit einem gehaltenen und einem leeren Anker zeigt „1/1“, bricht aber die Serie ([ArchiveScreen.swift:51](Anchor/ArchiveScreen.swift#L51)). | `.empty` in `isAllHeld` ignorieren. |
| N8 | Wird ein Chip in seine eigene Zelle gezogen, erscheint trotzdem „Auf X gelegt“ mit Undo ([WeekScreen.swift:659](Anchor/WeekScreen.swift#L659)). | Den Hinweis nur zeigen, wenn sich etwas geändert hat (`onUndoable` von `BlattDrop`). |
| N9 | Anker bearbeiten ([AnchorScreen.swift:248](Anchor/AnchorScreen.swift#L248)) und die Rückblickantwort ([ReviewScreen.swift:244](Anchor/ReviewScreen.swift#L244)) gehen an der Mutationsschicht vorbei. `why` wird auch unverändert geschrieben und löst so einen CloudKit-Export aus. | `GoalActions.update` verwenden und eine eigene Funktion für das Urteil anlegen. |
| N10 | ⌘Z ist auf dem Mac doppelt belegt: Undo-Leiste in der Seitenleiste und im Inhalt; dazu nimmt es womöglich Textfeldern ihr Undo ([BlattComponents.swift:467](Anchor/BlattComponents.swift#L467)). *plausibel* | Genau eine aktive Undo-Leiste. Den Shortcut nicht setzen, solange ein Textfeld den Fokus hat. |
| N11 | Das Menüleisten-Popover hat eine feste Größe von 300×252. Bei langen Ankertiteln werden die Knöpfe abgeschnitten ([AnchorApp.swift:534](Anchor/AnchorApp.swift#L534)). *plausibel* | `sizingOptions = .preferredContentSize`. |
| N12 | Die Löschbestätigung sagt „1 Wochen, 1 Aufgaben“ ([DataPrivacyView.swift:302](Anchor/DataPrivacyView.swift#L302)). | Einzahl und Mehrzahl als eigene Schlüssel, wie in CLAUDE.md verlangt. |
| N13 | Der Rückblick verspricht „…oder sie so abschließen“, in einer nie gespeicherten Woche fehlt aber der Knopf ([ReviewScreen.swift:212](Anchor/ReviewScreen.swift#L212)). | Den Text anpassen. |
| N14 | Im Setzen-Schritt lässt sich ein Anker nicht entfernen. Ein geleerter Titel wird still verworfen ([WeekStartScreen.swift:182](Anchor/WeekStartScreen.swift#L182)). | Einen Entfernen-Knopf pro Zeile anbieten oder einen Hinweis zeigen. |
| N15 | 9 Compiler-Warnungen, die in Swift 6 zu Fehlern werden: `self`-Capture in [CloudSyncStatus.swift:166](Anchor/CloudSyncStatus.swift#L166), [CloudSyncStatus.swift:181](Anchor/CloudSyncStatus.swift#L181) und [CloudSyncStatus.swift:191](Anchor/CloudSyncStatus.swift#L191); MainActor-Zugriffe in [ThemeIcon.swift:139](Anchor/ThemeIcon.swift#L139) und [ThemeIcon.swift:148](Anchor/ThemeIcon.swift#L148) sowie [TodayScreen.swift:193](Anchor/TodayScreen.swift#L193); ein ungenutztes Ergebnis in [WeekScreen.swift:650](Anchor/WeekScreen.swift#L650). | Jetzt beheben, solange es wenige sind. |
| — | Zur Kenntnis: Beim Zusammenführen gewinnt `reviewedAt = min`. Ein Wiederöffnen auf einem Gerät kann deshalb durch eine geschlossene Kopie überschrieben werden ([StoreMaintenance.swift:232](Anchor/StoreMaintenance.swift#L232)). Das ist ein bewusster Kompromiss. | – |

---

## 5. Fehlende Tests (empfohlen)

1. **Zeitzonen mit 12 h Abstand oder mehr** (New York → Tokio, Berlin → Neuseeland) für
   `storedDay`, `mergeDuplicateDays`, `WeekSheet` und `AnchorScreen`. Bisher ist nur der Fall
   „Anlage weiter östlich“ abgedeckt.
2. **Zusammenführen bei Ranggleichstand:** vier frische Onboarding-Anker gegen vier echte mit Aufgaben (M6).
3. **Erfassung:** `Release 1.2.10`, Jahre weit in Vergangenheit oder Zukunft, „Mach das so morgen“ (M2, N3).
4. **Deep Links** `anchorit://review` und `anchorit://week`, während eine andere Woche offen ist (M4).
5. **Rückblick:** „Loslassen“ einer wiederkehrenden Aufgabe (M5).
6. **UI:** Anker löschen und zurückkommen (H5), Tagesdetail wechseln (H2), Einplanen nach dem Löschen (H4).
7. **Testmodus und Defaults:** Nach `UITestMode.prepare` und einem Onboarding im Testmodus ist der
   spätere Sync-Zustand unverändert (H6).

## 6. Umgebung (keine App-Fehler)

- `xcode-select` zeigt auf die Command Line Tools. Gebaut wurde mit
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. Dauerhaft:
  `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`.
- Auf iOS liefen die UI-Tests unsigniert. Der Startbildschirm-Test konnte den Test-Runner teils nicht
  starten (`RequestDenied`). Die iOS-UI-Läufe deshalb mit Signatur wiederholen, sobald H1 und M12
  behoben sind.

## 7. Empfohlene Reihenfolge

1. **H1** und **M12**, damit die Testsuite grün und harmlos ist; das ist schnell erledigt.
2. **H2, H4, H5**: Datenfehler und Absturzgefahr in der Bedienung.
3. **H6** und **H3**: Sync-Robustheit. H3 braucht eine Modelländerung und das Schema in Production.
4. **M1** (Wischen) und **M9** (VoiceOver): Kernbedienung und Barrierefreiheit.
5. Die übrigen M-Punkte, danach N.
