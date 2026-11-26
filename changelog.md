# Changelog

## 2026-11-26

- **Das Mac-Fenster erscheint bei jedem Start.** Die App startete zeitweise ohne Fenster, nur mit Menüleiste — unter XCUITest bei jedem Lauf, sodass vier UI-Tests das Onboarding nicht fanden. Das Hauptfenster wird jetzt beim Start immer gezeigt; die Mac-UI-Suite ist wieder 9 von 9 grün.
- **Testlauf im Testmodus.** Der Startbildschirm-Test lief ohne `-AnchoritUITest` gegen den echten Store und das echte iCloud und legte ein Bildschirmfoto davon ins Ergebnis; im unsignierten Simulator stürzte er beim iCloud-Zugriff ab. Er startet jetzt mit Testmodus und Beispieldaten. Die Mac-UI-Tests passen wieder zur App („wichtig“ statt „Prio A“, Titel über die zusammengefasste Karte) und laufen nur noch auf macOS. Neu ist ein Test, der einen Anker löscht.
- **Tagesdetail behält den richtigen Tag.** Beim Sprung auf einen anderen Tag (Suche, Mitternacht) standen Fokus und Notiz des alten Tages da und wurden in den neuen gesichert. Der alte Tag wird jetzt gesichert, dann werden die Entwürfe neu geladen.
- **Einplanen auf dem iPhone:** Die gewählte Aufgabe hängt an ihrer Kennung. Wird sie gelöscht, löst sich die Auswahl auf, statt auf ein gelöschtes Modell zu zeigen; beim Wechsel der Woche wird sie zurückgesetzt, statt die Aufgabe still in die fremde Woche zu legen.
- **Anker löschen führt zurück.** Die Ankeransicht schließt sich nach dem Löschen über `dismiss`; die Closure aus dem Baustein von `navigationDestination` tat sichtbar nichts.
- **Tage bleiben über zwölf und mehr Zeitzonen dieselben.** Neue Tage tragen ihren Kalendertag als `Day.dayKey` („2026-11-23“); ein Montag aus New York ist in Tokio kein Dienstag mehr, und das Zusammenführen legt solche Tage nicht mehr aufeinander. Wochen rechnen ihren Montag aus ISO-Jahr und -Woche. Altbestand behält die Zwölf-Stunden-Regel und bekommt den Schlüssel bei der Wartung nur, wenn er eindeutig ist. Das optionale CloudKit-Feld `dayKey` braucht vor TestFlight einen Schema-Deploy.
- **Zusammenführen:** Bei Gleichstand stehen ältere Anker vor frisch im Onboarding angelegten (neues optionales Feld `Goal.createdAt`, ebenfalls Schema-Deploy). Aufgaben eines Ziels, das kurz ohne Woche ist, behalten ihren Anker zehn Minuten lang, statt sofort in den Eingang zu fallen.
- **Erfassung:** Versionsnummern wie „Release 1.2.10“ werden nicht mehr zum Datum — Jahre außerhalb von Vorjahr bis fünf Jahre voraus bleiben Titel. Liegt ein Datum in einem anderen Jahr, nennt die Hinweiszeile das Jahr. Ein überschriebenes Kürzel, das zugleich ein Wort ist, bleibt im Titel („Mach das so morgen“ heißt „Mach das so“, morgen).
- **Wiederholungen:** „Monatlich“ ab dem 31. läuft 28.02., 31.03., 30.04. statt dauerhaft auf den 28. „Loslassen“ im Rückblick lässt nur diese Woche los; die Kette läuft am nächsten Termin danach weiter.
- **Undo räumt auf.** Nimmt ein Undo eine verschobene, duplizierte oder wiederkehrend erzeugte Aufgabe zurück, verschwinden Tag und Woche, die dafür angelegt wurden und jetzt leer sind.
- **Archiv:** Ein leerer Anker bricht die Serie gehaltener Wochen nicht mehr.
- **Sync-Anzeige:** „Jetzt synchronisieren“ meldet „Nichts zu übertragen“ nur noch bei erreichbarem Account, sonst „iCloud-Account nicht erreichbar“. Endet ein Export, während ein Import läuft, bleibt der Status auf „Synchronisiert“, damit das Aufräumen nicht mitten im Import startet. Drei Swift-6-Warnungen sind behoben.
- **iCloud-Sync bleibt nach UI-Tests an.** Der UI-Testmodus arbeitet in einem eigenen Defaults-Bereich und fasst die Einstellungen der App nicht mehr an — er entfernte `hasCompletedOnboarding`, und eine ältere Installation ohne gespeicherte iCloud-Wahl startete danach ohne Sync. Die Schnellerfassung in der Menüleiste steht erst nach der iCloud-Frage zur Verfügung; vorher ließ eine Erfassung dort das Onboarding samt Frage verschwinden.
- **Erinnerungen öffnen die laufende Woche.** `anchorit://review` und `anchorit://week` ohne Datum springen in die Woche von heute, nicht in die zuletzt angesehene.
- **Wochen aus anderen Zeitzonen in den Ansichten:** Ankerseite, Menü „Verschieben auf“, „In die nächste Woche“, Suchsprung, Tagesbeschriftungen, Heute-Marke der Seitenleiste und der Aufgabeneditor rechnen mit dem gemeinten Tag statt mit dem Rohdatum.
- **Menüleisten-Popover** wächst mit seinem Inhalt; lange Ankertitel schneiden die Knöpfe nicht mehr ab.
- **Wischen auf dem iPhone funktioniert.** Nach rechts hakt eine Aufgabe ab, nach links löscht sie, beides mit Rückgängig. Vorher stand `.swipeActions` an Zeilen, die nicht in einer `List` liegen, und tat nichts; statt alle Listen umzubauen, hat die Zeile jetzt eine eigene Geste, die nur bei waagerechter Bewegung beginnt und das Scrollen nicht stört.
- **Mehrfachauswahl** beginnt über „Auswählen“ im Kontextmenü einer Zeile. Das lange Drücken aufs Kästchen ist entfallen: es lief gleichzeitig mit dem Kontextmenü und hakte beim Loslassen zusätzlich ab.
- **Wochenraster:** „In die nächste Woche“ am Chip rechnet ab der Woche der Aufgabe, nicht ab heute. VoiceOver nennt die Ankernummer statt „Ohne Anker“. Ein Chip, der in seine eigene Zelle fällt, meldet nichts mehr; landet eine Aufgabe aus einer anderen Woche im Eingang, sagt der Hinweis „In den Eingang gelegt“.
- **Anker im Setzen-Schritt entfernen:** Jede Zeile hat ein Entfernen. Bestehende Anker werden erst mit „Woche beginnen“ gelöscht; ihre Aufgaben bleiben, ohne Anker.
- **Ankereditor und Rückblickantwort** schreiben nur noch bei einer echten Änderung (über `GoalActions`) und lösen so keinen unnötigen iCloud-Export aus.
- **⌘Z auf dem Mac** gehört der zuletzt gezeigten Undo-Leiste; beim Tippen in einem Textfeld macht es dessen Eingabe rückgängig.
- **Texte:** Die Löschbestätigung zählt in Einzahl und Mehrzahl („1 Woche“). Der leere Rückblick bietet das Abschließen nur an, wenn es den Knopf dafür gibt. Die übrigen Swift-6-Warnungen sind behoben.

## 2026-11-25

- **Onboarding wieder bedienbar.** Bei einer frischen Installation wurde das Fenster auf dem Mac endlos lang, die Wahl „Mit iCloud synchronisieren / Nur auf diesem Gerät" lag unter dem Bildschirmrand, und es ging nicht weiter. Ursache: Das Fenster nimmt seine Mindestgröße aus dem Inhalt, und die umbrechenden Texte meldeten bei Breite null eine riesige Höhe. Das Onboarding scrollt jetzt (Knöpfe weiter unten, solange alles passt) und steht auf Mac und iPad in einer lesbaren Spalte von 560 pt.

## 2026-11-24

- **Korrekturen für App Review:** Der Erinnerungsimport liest Einträge erst für die ausgewählten Listen und aktualisiert nur belegte Zuordnungen. Die vollständige lokale Löschung entfernt auch die Importhistorie, bricht bei Lesefehlern ab und meldet das iCloud-Ergebnis getrennt. Datenschutzhinweise und Review-Notizen sind angepasst. Build 16 und das CloudKit-Werkzeugargument sind vorbereitet.
- **Einstellungen:** Kompakte Auswahlzeilen und klare Bereiche für Allgemein, Mitteilungen, Daten und Hilfe.
- **Erinnerungsimport:** Der Einstieg liegt im Drei-Punkte-Menü der Woche. Die Importvorschau kann eindeutig zugeordnete Aufgaben aktualisieren und zeigt Neuanlagen und Aktualisierungen getrennt. Rückgängig stellt die vorherigen Angaben wieder her.
- **Start und Navigation:** Anchorit fordert die Push-Registrierung pro Start nur einmal an und bündelt Änderungen am Navigationszustand. Identische Pfade werden nicht erneut geschrieben.
- **Import aus Apple Erinnerungen:** Fälligkeit mit Uhrzeit und Zeitzone, Notizen und Links bleiben in der Aufgabe erhalten, auch im Eingang. Die Angaben stehen im Aufgabeneditor und im JSON-Export. Das optionale CloudKit-Feld `importedReminderData` braucht vor TestFlight einen Schema-Deploy.

## 2026-11-23

### Vor dem Release: Übertrag, Wiederholen, Erinnerungen, Datumseingabe, Import

- **Unerledigtes rückt nach.** Heute zeigt unter dem Tag „Noch offen aus dieser Woche" — was an früheren Tagen der laufenden Woche liegen blieb, statt bis zum Rückblick zu verschwinden. „Alle auf heute" legt alles mit einem Griff auf heute, mit Rückgängig.
- **Wiederkehrende Aufgaben:** täglich, werktags, wöchentlich, alle 2 Wochen, monatlich. Beim Abhaken entsteht die nächste Aufgabe am nächsten Termin, gerechnet vom gemeinten Tag der erledigten; der Anker geht mit, in einer anderen Woche an den gleichnamigen. Rückgängig entfernt die Folgeaufgabe wieder, erneutes Abhaken erzeugt keine zweite, der Rückblick nimmt nichts doppelt mit. Einstellbar im Editor und im Kontextmenü. Zwei neue optionale Felder (`AnkerTask.recurrenceRaw`, `recurrenceNextID`) — **Schema-Deploy nötig**, siehe CloudKit-Anleitung (jetzt vier Felder).
- **Natürliche Datumseingabe** in der Erfassungszeile und in der Menüleiste: „heute", „morgen", „übermorgen", „nächste Woche", „in 3 Tagen", „24.11." bzw. „today", „tomorrow", „next week", „in 3 days", „Nov 24". Nur am Zeilenende, damit „Ich ruf morgen nicht an" Titel bleibt. Die Hinweiszeile zeigt vorher Tag und Datum; liegt der Tag in einer anderen Woche, sagt sie, dass der Anker entfällt.
- **Erinnerungen an das Ritual:** Einstellungen → Erinnerungen, montags „Anker setzen" und sonntags „Rückblick", Uhrzeit wählbar, Standard aus. Sie kommen nur, wenn sie passen: montags nur ohne Anker, sonntags nur mit Ankern und offener Woche. Tippen öffnet Woche bzw. Rückblick. Lokal, ohne Server.
- **Import aus Apple Erinnerungen** (Einstellungen → Daten): einmalig, nur lesend. Listen wählen, Vorschau, Import. Mit Datum in dieser oder nächster Woche an den Tag, sonst in den Eingang; hohe Priorität wird „wichtig"; Erledigtes und schon Vorhandenes wird übersprungen. Rückgängig möglich. Neue Berechtigung `NSRemindersFullAccessUsageDescription` (de/en über `InfoPlist.xcstrings`), auf dem Mac `ENABLE_RESOURCE_ACCESS_CALENDARS`. Datenschutzerklärung ergänzt.
- **Tagesdetail ohne „Zeitplan".** Der Abschnitt zeigte Zeitblöcke, die man nirgends anlegen konnte. Das Modell bleibt.
- 514 Katalogschlüssel auf Deutsch und Englisch; 189 Unit-Tests (neu: `CaptureDateTests`, `RecurrenceTests`, `RitualReminderTests`, `RemindersImportTests`), iPhone-Oberflächentests grün.
- Entwurf für die **Quartalsplanung** als Leinwand „Anchorit Quartal" (claude.ai-Artifact `U1SWebYdJaRExGjLCxyFGK`), noch nicht gebaut.

### Englisch als zweite Sprache

- **Anchorit spricht Deutsch und Englisch.** Einstellungen → Sprache: *Wie das System* (Deutsch auf deutschen Geräten, sonst Englisch), *Deutsch* oder *English*. Die Wahl gilt nach einem Neustart, auf dem Mac per Knopf „Jetzt neu starten"; der Hinweis steht schon in der gewählten Sprache.
- Alle rund 460 Texte sind übersetzt: Oberfläche, VoiceOver-Beschriftungen, Hinweise, Rückgängig-Meldungen, Sync-Status und Fehlertexte. Begriffe durchgehend: *anchor*, *Review*, *Carry over / Let go*, *Held / Partly / Missed*, *No day yet*.
- Datumsangaben folgen der Sprache („Nov 23 – 29, 2026", „Week 48"). Die Erfassungskürzel auch: auf Englisch `mo tu we th fr sa su` (oder `mon`…`sun`), ohne „do", damit „things to do" kein Donnerstag wird.
- Rückfall: Ein Gerät mit einer anderen Sprache als Deutsch oder Englisch bekommt Englisch.
- Demodaten für Bildschirmfotos gibt es in beiden Sprachen.
- **Datenschutzerklärung und Hilfe öffnen sich in der App**, in den Einstellungen von rechts hereingeschoben, in der Sprache der App. Name und Kontakt stehen an einer Stelle (`LegalInfo`). Die Seiten unter `docs/` bleiben nur für die Pflicht-URLs in App Store Connect.
- „Woche setzen" heißt jetzt überall „Anker setzen". Restliche „Wochenziel"/„Ziele" sind „Anker".
- Absicherung: `Scripts/l10n-guard.swift` prüft jeden Schlüssel auf Deutsch und Englisch; neue Tests für Sprachtabellen, Rückfall, Sprachwahl und englische Erfassung; iPhone-Oberflächentests öffnen die Rechtstexte auf Deutsch und Englisch. Unit-Tests laufen fest auf Deutsch.
- Behoben dabei: Jahreszahlen erschienen im Englischen als „2,026".

### Release-Prüfung vor dem App Store

Fünf Prüfungen (Sync und Daten, Sicherheit und Datenschutz, Architektur und Leistung, UX und Barrierefreiheit, Fachlogik). Die Befunde sind behoben bis auf die unten genannten.

**Datenschutz und Daten**
- **Ein frisches Gerät überträgt nichts, bevor gefragt wurde.** Vorher lief der Speicher schon vor der Frage mit iCloud, und wer „Nur auf diesem Gerät“ wählte, hatte seine ersten Anker trotzdem in iCloud. Jetzt startet ein neues Gerät lokal; „Mit iCloud synchronisieren“ baut den Speicher sofort mit CloudKit neu auf. Bestehende Installationen synchronisieren unverändert weiter.
- **„Alle Daten löschen“ erreicht iCloud wirklich:** Zusätzlich zur lokalen Löschung wird die CloudKit-Zone entfernt, auch was hier noch nicht angekommen ist und auch bei abgeschaltetem Sync. Ein fehlgeschlagenes Speichern rollt zurück, statt die Löschung beim nächsten Speichern ohne Bestätigung nachzuholen. Die Texte sagen ehrlich, was passiert.
- Der Export enthält Warum-Satz und Rückblickantwort (Format 3).
- Datenschutzerklärung und Hilfe liegen unter `docs/` für GitHub Pages und sind in der App verlinkt (Richtlinie 5.1.1).
- Texte zu iCloud versprechen nichts mehr, was ohne erweiterten Datenschutz nicht stimmt.

**Sync**
- Aufgeräumt wird erst nach dem ersten Import der Sitzung. Verwaiste Tage und Anker werden nur noch an **vorhandene** Wochen gehängt; vorher legte das Aufräumen nach einem abgebrochenen Import neue Wochen an.
- Die Reihenfolge zusammengeführter Anker hängt nur noch an Feldern des Ankers selbst, nicht an lokal sichtbaren Aufgaben, und ist damit auf allen Geräten gleich.
- Das Tagesdetail legt Woche und Tag erst beim Schreiben an, nicht mehr beim Öffnen (Startansicht „Zuletzt“, Deep Link).
- Anker werden beim Verschieben über den ISO-Schlüssel verglichen; Rückgängig stellt auch nach einem Zusammenführen wieder her.
- Übertrag und „um n Tage verschieben“ treffen bei Tagen aus anderen Zeitzonen den richtigen Wochentag.

**Abläufe**
- Rückblick auf dem iPhone über die Wochenansicht erreichbar, für jede Woche, auch zum Wiederöffnen; „Heute“ erinnert an eine ungeprüfte Vorwoche.
- „Woche setzen“ und „Rückblick“ lassen sich abbrechen (Escape auf dem Mac). Eine Woche ohne Anker lässt sich schließen. Loslassen fragt nach, die Zusammenfassung sagt vorher, was wohin geht, und die Reflexion wird beim Tippen gesichert.
- „Mitnehmen“ behält den Anker, wenn die Folgewoche einen gleichnamigen hat; Aufgaben ohne Tag werden mit abgeschlossen.
- Das Tagesdetail hat eine Erfassungszeile (der Knopf „Neu“ tat nichts).
- Aufgaben ohne Tag haben dieselben Aktionen wie andere. Der Editor plant sie beim Umbenennen nicht mehr still auf heute ein.
- Chips im Raster: Bearbeiten und Anker im Kontextmenü, Rückgängig nach dem Ablegen.
- Das Menüleisten-Popover startet leer (vorher mit Beispieltext), schließt mit Abbrechen, sichert mit Enter.
- Mac-Menü „Gehe zu“ (⌘1–3, ⌘[ / ⌘], ⌘F); ⌘N öffnet kein zweites Fenster mehr. Das mehrdeutige ⌘⇧M an jeder Zeile ist entfernt.
- „Heute“ rückt über Nacht auf den neuen Tag vor.
- Archiv über alle Jahre mit Jahresschalter und Legende; die Serie bricht bei fehlenden Wochen.
- Suche findet Aufgaben ohne Tag und den Warum-Satz; jeder Treffer führt irgendwohin.
- `anchorit://review` öffnet den Rückblick; ungültige Daten in Deep Links werden abgewiesen.
- Erfassung: der Hinweis nennt `#1–#4` richtig, Wochentagskürzel gelten nur am Ende („Mach das so gut wie möglich“ landet nicht mehr am Sonntag).
- Wer bewusst lokal arbeitet, sieht keinen Dauerbanner „Sync aus“ mehr.

**Gestaltung und Barrierefreiheit**
- Tippflächen auf iOS mindestens 44 pt bei gleicher Optik.
- Begriffe einheitlich „Anker“, Pluralformen, echte Umlaute und Halbgeviertstriche. Entwicklertexte der Sync-Anzeige stehen unter „Technische Details“.
- Wochenraster ohne Querscroll ab 960 pt Inhalt; Chiptitel bekommen in schmalen Spalten die volle Breite, der Tag steht in „Nach Anker“ über dem Chip.
- VoiceOver liest den Wochenüberblick pro Anker vor.

**Leistung und Aufräumen**
- Keine `@Query` mehr in jeder Aufgabenzeile, ein Speichern pro Sammelaktion, Aufräumen mit Prädikaten statt Vollscan, Datenschutzseite zählt per `fetchCount`.
- Entfernt: `AnkerMatrix`, `AnkerArchive`, `AnkerStatistics` (nur noch von Tests benutzt), `NewTaskSheet`, `NewGoalSheet` und vier ungenutzte Icons. `AnkerComponents` ist aufgeteilt.
- Repo: `.gitignore`, Xcode-Benutzerdaten, Profildaten und ein ZIP sind nicht mehr eingecheckt.
- Test-Erkennung nur noch im Debug-Build; Speicherfehler gehen ins Log statt auf die Konsole.
- 118 Unit-Tests (neu: `ReleaseLogicTests`, `ComponentReleaseTests`), `design-guard` mit Schranke gegen `Color(hex:)`.

**Bewusst offen**
- Lange zusammengesetzte Wörter brechen in sehr schmalen Rasterspalten weiter um; SwiftUI trennt keine Silben.
- `Priority` bleibt als Codable-Enum gespeichert; das Schema steht schon in Production.
- Mitgenommene Aufgaben bekommen einen Anker, der erst nach dem Schließen gesetzt wird, nicht nachträglich.

### Zusammengeführt mit main: „Blatt" bleibt, die iCloud-Korrekturen von „Lot" kommen dazu

- **Gestaltung:** „Blatt" ersetzt „Lot" (Bernstein, Glas, Instrument Serif). Lot-Schrift, Wochenpuls-Icon und Glasflächen sind entfernt.
- **Stille Pushes auf dem iPhone:** Ein eigener App-Delegate registriert die CloudKit-Benachrichtigungen schon beim Start und hält die App im Hintergrund wach, bis der Import angekommen ist (höchstens 25 s). Auf dem Mac genauso, ohne Hintergrundfenster.
- **Sync-Diagnose:** zeigt jetzt Push-Status, eine direkte Serverprüfung der CloudKit-Zone („Server prüfen") und die Zahl empfangener Fremdänderungen. Ein „erfolgreicher" Export mit abgewiesenen Datensätzen erscheint als Warnung statt als Erfolg.
- **Schema-Upload:** läuft verzögert und abseits des Main-Threads; die App bleibt dabei selbst ohne CloudKit. Der Upload brach vorher nach rund 130 s mit Zeitüberschreitung ab.
- **Startansicht** in den Einstellungen: Heute, Woche oder zuletzt geöffnet. Ohne gespeicherten Stand überschreibt „Zuletzt" keinen Deep Link.
- **Export-Compliance:** `ITSAppUsesNonExemptEncryption = false` in der Info.plist, damit TestFlight-Uploads nicht mehr an der Rückfrage hängen bleiben.
- **Nicht übernommen:** Lot schob das Zusammenführen auf, solange eine Kopie leer war. Neben der Wahl der kleinsten UUID würde das dauerhaft eine leere Woche anzeigen. Blatt räumt stattdessen erst nach dem Import auf und hängt Verwaiste wieder ein.

### Seitenleiste mit den Wochen ist zurück

- **Auf Mac und iPad steht links wieder eine Seitenleiste** — die Wochen um die laufende herum mit ihren sieben Tagesquadraten und der Zahl offener Aufgaben. Ein Klick öffnet die Woche, „Heute" springt zur laufenden.
- **Aufgaben in eine andere Woche ziehen:** eine Aufgabe aus dem Raster, der Ansicht nach Anker oder einer Liste auf eine Woche der Leiste ziehen. Sie landet am selben Wochentag, ohne Tag am Montag; ihr Anker wird über die Wochengrenze gelöst. Rückgängig direkt in der Leiste. Als Test festgehalten.
- **Verschieben auch in der iPhone-Wochenansicht.** Langes Drücken auf eine Aufgabe bietet jetzt „Verschieben …" (dasselbe Blatt wie in Heute, auch in andere Wochen und auf ein freies Datum) und „In die nächste Woche" (gleicher Wochentag). Außerdem lässt sich in der Ansicht „Nach Tag" jede offene Aufgabe antippen und per „Hierher" auf einen anderen Tag legen — mit Rückgängig.
- **Einklappbar** über den Knopf links im Kopf oder ⌃⌘S, pro Gerät gemerkt. Ist die Leiste zu, erscheint der Wochenschalter im Kopf — es bleibt bei genau einem Zeitnavigator.
- Der Fensterkopf passt sich an: im iPad-Hochformat wird die Bereichswahl schmaler und „Rückblick" zum Symbol, statt dass der Kopf unter die Leiste rutscht. Das Mac-Fenster hat eine Mindestgröße, unter der Raster und Leiste nicht mehr lesbar wären.

### Neuer Produktname: Anchorit

- **Die App heißt jetzt Anchorit.** Anzeigename, App- und Modulname (`Anchorit.app`, `@testable import Anchorit`), alle sichtbaren Texte, Exportdatei (`Anchorit-Export-….json`), Datenschutzhinweis und Startargumente (`-AnchoritUITest`, `-AnchoritDemoData`, `-AnchoritTab`, `-AnchoritInitializeCloudKitSchema`).
- **Bundle-ID und iCloud-Container bleiben** `com.marcomeisen.Anchor` bzw. `iCloud.com.marcomeisen.Anchor` — sonst verlören bestehende Installationen ihre Daten und der Sync bräche ab. Der Speicherort der Daten hängt nicht am Produktnamen.
- **Neues URL-Schema `anchorit://`.** `daivento://` bleibt registriert, damit vorhandene Links und Kurzbefehle weiter funktionieren; als Test festgehalten.
- **Testlauf stürzte nach der Umbenennung ab — Ursache war ein Scheme-Argument.** Im geteilten Scheme stand `DaiventoInitializeCloudKitSchema` ohne führenden Bindestrich und wirkte deshalb nie. Mit Bindestrich lief die Schema-Initialisierung bei **jedem** Start und im unsignierten Testhost in CloudKit hinein. Das Argument ist jetzt standardmäßig aus, und die Initialisierung läuft nie im Test und nie ohne iCloud-Berechtigung.
- **Unsignierte Mac-Builds stürzen nicht mehr in CloudKit ab**, sondern arbeiten lokal: CloudKit wird nur noch angebunden, wenn das Programm die iCloud-Berechtigung wirklich trägt. Die Testerkennung achtet zusätzlich auf alle Zeichen der XCTest-Einspritzung, nicht nur auf `XCTestConfigurationFilePath`.
- Die Projekt-Skills heißen `anchorit-build`, `anchorit-swiftdata`, `anchorit-design-system`, `anchorit-task-interactions`. Ältere Entwurfsdokumente (`Daivento_Task_…`) und frühere Changelog-Einträge behalten den alten Namen als Historie.

### Neuentwurf „Blatt": ein Blatt pro Woche

- **Die Oberfläche folgt dem Entwurf „Blatt".** Tinte auf kühlem Hellgrau, weiße Karten mit Haarlinie, Systemschrift und genau eine Farbe — ein tiefes Blau, das „erledigt" oder „heute" heißt. Anker sind Nummern, keine Farben. Der Wochenablauf hat vier Schritte: Setzen (Montag), Erledigen, Prüfen (Sonntag), Ablegen.
- **Heute** zeigt die vier Anker als Leiste mit einem Punkt pro Aufgabe; jeder Haken füllt sofort den Punkt bei seinem Anker. Darunter die Aufgaben des Tages, ein Hinweis auf „noch ohne Tag" und die Erfassungszeile.
- **Die Woche gibt es in zwei Ansichten mit denselben Daten:** auf Mac und iPad als Raster (Zeile Anker, Spalte Tag, rechts „Ohne Tag") oder nach Anker; auf dem iPhone nach Tag — mit Überblick-Raster und Einplanen durch Antippen — oder nach Anker. Ziehen im Raster setzt Tag und Anker in einem Schritt; bei schmalem Fenster scrollt das Raster waagerecht statt die Chips abzuschneiden.
- **Neu: Warum-Satz pro Anker** und ein Montagsschritt „Was zählt diese Woche?", der nicht gehaltene Anker der Vorwoche zur Übernahme anbietet.
- **Neu: Am Sonntag antwortet der Mensch.** Pro Anker gehalten, teilweise oder nicht — die Zahl daneben ist nur ein Hinweis. Danach pro offener Aufgabe mitnehmen oder loslassen.
- **Archiv** zeigt das Jahr als Raster aus Wochen mit je vier Strichen, die längste Serie und den Anker, der immer wieder gesetzt wird und selten hält.
- **Keine Sidebar mehr.** Auf dem Mac ein eigener Fensterkopf mit Wochenschalter, Bereichswahl, Rückblick, Suche und Sync-Status; die Titelleiste ist verborgen, die Ampelknöpfe bleiben. Detailansichten haben einen Zurück-Knopf.
- **Neues App-Icon:** das Blatt selbst — vier Reihen zu fünf Quadraten, Erledigtes blau. Hell, dunkel, getönt (iOS) und macOS mit Haarlinie gegen hellen Grund; dazu ein neues Menüleisten-Glyph. Gezeichnet von `Scripts/make-icon-sources.swift`, nicht von Hand.
- Archivo ist entfallen; die App setzt in SF Pro und wächst auf iPhone und iPad mit Dynamic Type mit.

### iCloud-Sync: Zusammenführen konvergiert, nichts geht mehr verloren

Eine Prüfung der Sync-Schicht fand einen Fehler mit Datenverlust und zwei Ursachen für Duplikate:

- **Das Zusammenführen doppelter Wochen lief auf zwei Geräten auseinander.** Gewonnen hatte die inhaltsreichere Kopie — gezählt wurde aber, was gerade lokal vorlag, und mitten in einem Import kommen Wochen vor ihren Tagen an. Zwei Geräte löschten so je die andere Kopie, und die Löschkaskade nahm Tage und Aufgaben mit. Jetzt gewinnt immer die kleinste UUID, die Löschregeln sind `.nullify`, und verwaiste Tage, Ziele und Zeitblöcke werden wieder eingehängt. Benutzte Anker kommen dabei vor leeren, damit frische Onboarding-Anker die echten nicht verdrängen.
- **Start und Blättern legten Wochen an.** Auf jedem neuen Gerät entstand so die laufende Woche, bevor der iCloud-Import sie brachte. Wochen und Tage entstehen jetzt nur noch beim Schreiben, und zwar nur der eine Tag, der gebraucht wird.
- **Wochen wurden über das Montagsdatum gefunden.** Das ist Mitternacht in der Zone des anlegenden Geräts; eine Woche aus einer anderen Zeitzone wurde nicht gefunden und doppelt angelegt. Jetzt über ISO-Jahr und -Woche, Tage über den gemeinten Kalendertag.
- Aufgeräumt wird erst, wenn kein Import läuft, und auf dem aktuellen Bestand statt auf dem Schnappschuss der Ansicht.
- „Nur lokal gespeichert" wurde nach dem nächsten Speichern durch „wartet auf Export" überschrieben, obwohl in diesem Prozess nie exportiert wird. Der Hinweis bleibt jetzt stehen.
- Aufgaben ohne Tag sind ein gültiger Zustand (mit Anker „noch nicht eingeplant", ohne Anker im Eingang): anlegen, einplanen, ausplanen, duplizieren und Löschen rückgängig machen.
- Neue Tests halten fest: zwei Geräte in verschiedenem Importzustand wählen dieselbe Kopie, eine gelöschte Woche nimmt ihre Tage nicht mit, Tage aus einer anderen Zeitzone landen auf ihrem Tag, Wochen entstehen ohne Tage.

### Mehrfachauswahl in „Blatt"

- **Mehrere Aufgaben auf einmal bearbeiten** — auf Heute und in der Ankeransicht über „Auswählen" oder ein langes Drücken auf ein Kästchen. Unten erscheint statt der Erfassungszeile eine Leiste: Erledigt, Verschieben, Anker setzen, Löschen und „Alle". Löschen fragt ab drei Aufgaben nach, jede Aktion lässt sich rückgängig machen — auch für Aufgaben ohne Tag. Auf dem Mac `⌘⇧A`, Escape beendet.
- Am iPhone-Simulator geprüft: Heute, Woche und Archiv sehen aus wie im Entwurf; die Tagesbeschriftung steht bei langen Tagen jetzt oben statt mittig. Die iPhone-UI-Tests (Detail erreichbar und verlassbar, alle Tabs) laufen grün.
- Neu: [CloudKit_Schema_Anleitung.md](CloudKit_Schema_Anleitung.md) — Schema von Development nach Production, Schritt für Schritt, mit Prüfpunkten und Fehlerbildern.

**Vor dem nächsten TestFlight-Build nötig:** `Goal.why` und `Goal.verdictRaw` sind neue, optionale Felder. Einmal mit `-DaiventoInitializeCloudKitSchema` starten und das Schema in der CloudKit-Konsole nach Production deployen.

**Offen:** Die Mac-UI-Tests sind umgeschrieben, aber nicht gelaufen — das Signieren scheitert aus einer Terminal-Sitzung mit `errSecInternalComponent` (gesperrter Schlüsselbund). In Xcode mit ⌘U ausführen. iPad und ein echtes Gerät sind noch nicht angesehen.

## 2026-08-06

### Zielsymbol, Bildschirmränder, Ziehen zum Abgleichen

- **Der Anker ist überall ein Balken, jetzt auch auf dem Knopf.** Die Zielscheibe war der letzte Rest der Ringdarstellung aus Runde 1 und stand ausgerechnet dort, wo man einen Anker **anlegt**. `AnkerIcon.goal` traegt alle fuenf Aufrufstellen mit; `lucide-target` ist aus dem Katalog raus, damit die Schranke „kein verwaistes Asset" haelt. Gewaehlt ist die Variante **mit Achse**: die reinen liegenden Balken lasen sich am Geraet als Menue-Symbol — drei gleich lange Striche direkt neben einem Plus. Am Bildschirm geprueft, nicht geraten.
- **Ein Bildschirmrand fuer alles.** Kopfzeile und Ankerstreifen standen bei 24pt, die Erfassungszeile bei 16pt, das 4×7-Raster bei 0 — es lief bis an den Fensterrand. Alle drei liegen jetzt auf `AnkerSpacing.screenPadding`; dieselbe Korrektur in der Wochenuebersicht und beim Undo-Streifen des Tagesdetails. Die 2px-Sektionsgrenzen bleiben randlos: sie trennen Baender des Bildschirms, nicht Inhalt.
- **Ziehen nach unten fordert einen Abgleich an** (iPhone, alle obersten Bildschirme). Ehrlich gebaut: CloudKit kennt **kein** „jetzt synchronisieren", weder ueber SwiftData noch ueber Core Data. Die Geste prueft den iCloud-Accountstatus neu — der haeufigste Grund fuer „synct nicht" —, wartet danach kurz auf ein CloudKit-Ereignis und berichtet, was sie gesehen hat. Kein Fortschrittsbalken, der so tut als ob.
- **Die Sync-Anzeige ist auf allen drei Plattformen dieselbe.** Das iPhone zeigt jetzt `CloudSyncStatusRow` — denselben Baustein wie der Sidebar-Fuss von Mac und iPad — statt nur eines Symbols. Nicht dauerhaft: eingeblendet waehrend eines angeforderten Abgleichs, bei einem Problem und bei abgeschaltetem Sync. Im Normalfall genuegt das Symbol im Kopf, und 40pt Telefonhoehe bleiben frei.

**Drei Fehler kamen beim Ausmessen heraus, alle drei aelter als diese Aenderung** — gefunden, weil ich
die Raender in Pixeln gemessen habe statt sie anzusehen:

- Die Kopfzeile der Matrix baute ihre Ankerspalte als `.frame(width: 212).padding(.horizontal, 16)`, war damit **244pt** breit und 32pt breiter als dieselbe Spalte in den Datenzeilen. Der VStack nahm die groessere Breite, die Zeilen wurden darin zentriert und standen 16pt zu weit rechts — links 39pt Rand, rechts 9pt. Die Polsterung steht jetzt vor der Breite.
- Eine `ScrollView` mit **beiden** Achsen zentriert Inhalt, der kleiner ist als ihr Fenster. Bei wenigen Ankern hing die Tabelle deshalb in der Bildschirmmitte, mit einem Loch zwischen Schlagzeile und Kopfzeile. `maxHeight: .infinity` hilft dagegen nicht — in einer Scrollansicht ist der Hoehenvorschlag unbegrenzt. Eine Mindesthoehe aus dem gemessenen Fenster greift, und `fixedSize` haelt die Zeilen dabei auf ihrer natuerlichen Hoehe.
- Die senkrechte 2px-Regel zwischen Ankerspalte und Tagen fehlte in der Spaltenrechnung. Das Raster war dadurch genau diese 2px breiter als sein Platz.

## 2026-08-05

### iCloud-Sync: der UI-Testmodus schaltete ihn dauerhaft ab

Gemeldet war „iPhone synct nicht mit dem Mac in TestFlight". Der Mac war nachweislich gesund — der
installierte TestFlight-Build exportiert und importiert erfolgreich, mit `aps-environment:
production` und `Production`-Container. Damit schied das aus, was zuerst naheliegt: das
CloudKit-Schema, die Entitlements, `remote-notification`, die Container-Kennung.

Gefunden wurde stattdessen ein Fehler mit langer Reichweite im Testmodus:

- `UITestMode.prepare` schrieb `cloudSyncEnabled = false` in die Nutzereinstellungen. Der Wert ueberlebt den Testlauf, und Debug- und TestFlight-Build teilen Bundle-ID und damit den Defaults-Bereich. Auf einem Geraet, auf dem je ein UI-Test lief, blieb der iCloud-Sync danach **dauerhaft** aus — lautlos, ohne Fehler, mit lokal weiterlaufender App. Genau die Sorte Fehler, die man in TestFlight als „synct nicht" sieht und im Code nicht findet.
- Der Schreibvorgang war fuer seinen Zweck ueberfluessig: `CloudSyncConfiguration.usesCloudKit` und `modelConfiguration` fragen `UITestMode.isActive` ohnehin direkt ab. Jetzt tun `CloudSyncPreference.isEnabled` und `hasBeenChosen` dasselbe, und `prepare` **entfernt** nur noch Schluessel, statt welche zu setzen.
- Festgehalten als Test ueber `UITestMode.resetKeys`: die Sync-Schluessel duerfen nicht darin vorkommen. Bewusst ueber die Liste statt ueber den Aufruf — `prepare` ist im Unit-Test wirkungslos, eine Zusicherung ueber den Aufruf waere eine Zusicherung ueber nichts.

Ein bereits abgeschaltetes Geraet heilt der Fix nicht: dort steht der Wert schon. Die App zeigt das
als „Nur auf diesem Geraet" an; Einstellungen > iCloud-Sync einschalten und die App **vollstaendig**
neu starten, weil `activeAtLaunch` pro Prozess feststeht.

Nebenbefund, nicht behoben: `AnchorUITests` scheitert gegen einen iOS-Simulator („Onboarding wurde
nicht angezeigt"). Durch Zurueckstellen der Aenderung geprueft — der Fehler ist aelter, die Suite ist
fuer den Mac geschrieben. `AnchorUITests/PhoneChromeTests` laeuft auf iOS gruen.

## 2026-08-16

### Reskin *Lot* — dieselben Screens, in neuem Material

Grundlage sind `Lot Designsystem.dc.html` und `Daivento in Lot.dc.html`. **Struktur, Daten und
Interaktion sind unveraendert** — der Modernist-Aufbau hat sich bewaehrt, gewechselt ist das
Material: warme Neutralen statt Blaugrau, Bernstein statt Rot, Rost nur noch fuer Rueckstand,
weiche Radien und Hoehe statt 2px-Linien, Glas fuer Chrome.

- Die Tokenschicht traegt die fuenfzehn Lot-Werte. Die gespiegelte Neunerrampe ist weg: Lot gibt
  fuer jede Rolle ein eigenes Hell-Dunkel-Paar an, weil eine Spiegelung im Warmen danebenliegt.
  Die Tokennamen sind geblieben — dadurch rasten rund 400 Aufrufstellen ohne eigene Aenderung ein.
- **Drei Werte des Entwurfs sind gemessen korrigiert.** `LotTextFaint` (`#A09889`) als
  Mikro-Beschriftung sind 2,10:1 auf dem Grund und damit unlesbar; sie laeuft auf `LotTextMuted`,
  der Entwurfswert bleibt als `AnkerColor.faint` fuer Flaechen. `LotAmber` (`#D9820F`) als Marke
  sind 2,15:1; Linien und Icons nehmen `LotAmberDeep` (3,21:1), waehrend `LotAmber` die Flaeche
  bleibt. Und Papierweiss auf Bernstein — der primaere Knopf des Entwurfs — sind 2,89:1; `onAccent`
  ist deshalb **Tinte** (5,92:1 hell, 8,09:1 dunkel) und als einziges Token statisch, weil
  Bernstein in beiden Modi hell ist.
- Material und Schatten sind nicht mehr verboten, sondern gebunden: `.ankerGlass()` fuer Chrome
  ueber Inhalt, `AnkerElevation` mit vier Stufen fuer alles, was schwebt. Roh an der Aufrufstelle
  bleiben beide gesperrt. Kopfzeile, Erfassungsleiste, Tableiste und Blattkopf sind jetzt Glas.
- Radius laeuft auf 4pt-Basis ueber fuenf Rollen (8/12/16/20/28). Ohne Radius bleiben genau zwei
  Dinge, beide mit Begruendung: der Wochenpuls und der Fortschrittsbalken.
- Die Abschnittsgrenze ist eine Haarlinie geworden. Was zwei Bereiche trennt, ist jetzt die
  **Farbe** der Linie, nicht ihre Staerke — die 2px-Regel ist abgeloest.
- Rost hat genau eine Bedeutung. „Tage Rest" im Ankerdetail und „Uebertragungen" im Jahresband
  hiessen vorher `isEmphasized` und waren bernsteinfarben; sie heissen jetzt `isBacklog` und sind
  rostfarben. Die Prioritaet verliert ihre gefuellte Marke und steht als Buchstabe an der Zeile.
- **Der Wochenrueckblick ist ein Ritual.** Statt des roten Plakats jetzt dunkel, Instrument Serif,
  Abstaende × 1,4 — und immer dunkel, auch wenn die App hell laeuft. Dieselbe Hierarchie wie
  vorher (eine Zahl, das nicht Gehaltene, eine Frage), aber die Lautstaerke kommt aus Flaeche und
  Schriftwechsel statt aus Signalfarbe. Die Einstellungszeile bleibt trotz „kein Chrome" stehen:
  sie ist auf dem iPhone der einzige Weg dorthin.
- **Archivo ist entfallen.** Die Arbeitsflaeche spricht San Francisco, wie das Systemblatt es
  verlangt; damit kommen Dynamic Type, optische Groessen und die Sprachabdeckung ohne eigene Datei.
  Geliefert wird nur noch **Instrument Serif** (OFL-1.1) fuer das Ritual. Gewichte gehen nur noch
  bis 600 — die Hierarchie tragen Grad, Farbe und Flaeche.
- **Eine Regel des Entwurfs ist nicht erfuellbar und deshalb benannt:** „Ziffern immer
  tabellarisch" gilt fuer die Arbeitsflaeche ausnahmslos, aber Instrument Serif bringt keine
  `tnum`-Tabelle mit — das OpenType-Feature laeuft ins Leere (gemessen bei 20 pt: „1" 4,98 pt
  gegen „0" 9,20 pt, vor **und** nach dem Setzen des Features). Die Serif gewinnt, weil sie den
  Modus markiert; damit die Zahl beim Wochenschluss trotzdem nicht springt, steht der Zaehler in
  einem festen Kasten von 0,5 em. Ein Test misst, dass die breiteste Ziffer hineinpasst.
- Der Iconsatz wird **gezeichnet** statt skaliert. Der Grund steht im Entwurf: ab 40 px fallen die
  Tagesfugen weg und aus 4×7 Feldern werden vier Balken mit denselben Fuellstaenden — das laesst
  sich nicht herunterrechnen. `Scripts/make-app-icons.swift` haelt die Geometrie als Vorschrift und
  erzeugt dreizehn Dateien: drei Erscheinungsbilder fuer iOS (hell, dunkel und getoent, alle drei
  gezeichnet statt abgeleitet, damit die 26-%-Spuren der offenen Tage erhalten bleiben), sieben
  macOS-Groessen mit Big-Sur-Maske und drei Menueleisten-Templates. Fuer die Menueleiste zaehlt die
  **Punktgroesse** (immer 18), nicht die Pixelgroesse der Datei — sonst traegt ausgerechnet die
  @3x-Fassung sieben Fugen, die niemand aufloesen kann.
- Zwei Fallen beim Icon: eine selbst gebaute Bezier-Naeherung der fortlaufenden Ecke beult die
  Kante sichtbar aus. `RoundedRectangle(style: .continuous).path(in:)` liefert Apples Kurve ohne
  Renderer — dieselbe Quelle, aus der die App ihre Flaechen zieht.
- `Scripts/design-guard.swift` prueft jetzt 26 Schranken statt 18. Neu sind unter anderem: Serif
  und Ritualfarben nur in der Ritual-Datei, Glas nur in Chrome-Dateien (ueber eine Dateiliste, weil
  sich das nicht als Zeilenmuster fassen laesst), `faint` nie als Schriftfarbe, Rost nie als Knopf,
  keine dritte Schrift und keine gerechnete Kantenstaerke.
- **Datenverlust beim Erstimport behoben.** Das Zusammenfuehren doppelter Wochen lief bei
  *jeder* Fremdaenderung, also auch mitten im CloudKit-Erstimport. CloudKit liefert `Week`, `Day`,
  `Goal` und `AnkerTask` als getrennte Records in getrennten Batches; traf der Wochen-Record ein,
  bevor seine Kinder da waren, wog die echte Woche in diesem Moment 0 und verlor gegen die frisch
  angelegte Onboarding-Woche. Sie wurde geloescht — und weil es ein **synchronisierter** Record
  war, wanderte die Loeschung in die Cloud und auf alle anderen Geraete. Auf einem neu
  installierten iPhone blieb der Bestand dadurch leer, waehrend Mac und iPad die Woche verloren.
  Zwei Schranken dagegen: das Aufraeumen wartet jetzt drei ruhige Sekunden ab (`task(id:)` bricht
  bei jeder neuen Fremdaenderung ab, der Schlaf wird damit zum Wartefenster) und holt die Wochen
  danach frisch statt aus einer alten Momentaufnahme; und eine Gruppe, in der eine Woche leer und
  eine andere gefuellt ist, gilt als nicht entscheidungsreif und wird aufgeschoben statt
  zusammengefuehrt. Zwei Regressionstests halten beide Richtungen fest.
- Die Gewichtung nach Inhalt allein reichte nicht: sie unterstellt, dass beide Wochen zum
  Vergleichszeitpunkt vollstaendig vorliegen. `testMergingKeepsTheRicherWeekEvenWhenItsUUIDIsHigher`
  baut beide fertig bestueckt auf und konnte den Fall deshalb nicht fangen.
- Das iCloud-Diagnoseblatt zeigt jetzt **Fremdaenderungen** — wie oft dieses Geraet seit dem
  Start eine Aenderung von aussen empfangen hat. Das trennt Export- von Importseite, ohne dass
  jemand ein Geraetelog mitlesen muss: exportiert Geraet A, und Geraet B steht weiter bei 0, ist
  nicht der Export das Problem, sondern der Import auf B. Erreichbar ueber das Wolkensymbol in
  der Kopfzeile (iPhone) bzw. die Sync-Zeile im Sidebar-Fuss (Mac, iPad).
- Ein abgeschlossener Export mit Fehler sieht nicht mehr aus wie ein sauberer. `event.succeeded`
  sagt nur, dass die Aktivitaet durchgelaufen ist — einzelne Records koennen dabei abgewiesen
  worden sein, und der Fehler haengt dann trotzdem am Ereignis. Der Erfolgszweig hat `event.error`
  bisher verworfen und „iCloud-Export erfolgreich" geloggt, waehrend die Aenderung das andere
  Geraet nie erreichte. Jetzt laeuft der Fehler auch dort durch `CloudSyncErrorFormatter` und
  landet als Warnung im Log samt Hinweis auf den haeufigsten Grund (Schema nur in Development).
- Die Rolle `AnkerIcon.goal` traegt jetzt den **Wochenpuls** statt `lucide-target`. Eine
  Zielscheibe sagte nichts ueber die App; die Balken sind dieselbe Zeichnung wie das App-Icon in
  der vereinfachten Fassung, mit denselben Fuellstaenden. Damit traegt die Figur Icon, Menueleiste
  und Oberflaeche — „dieselbe Figur in jeder Groesse". `lucide-target` ist entfallen.
- `AnkerThemeTests` misst den Kontrast jeder Textstufe gegen **alle drei** Flaechen statt nur gegen
  den Grund, dazu die Ritual-Palette einzeln (sie kippt nicht mit) und das Glas als
  zusammengerechnete Flaeche. Die drei Korrekturen am Entwurf stehen als eigener Test mit ihrem
  Messwert daneben, damit sie niemand zurueckdreht.

- CloudKit-Schema-Upload repariert: `initializeCloudKitSchema` lief inline in `App.init` auf dem Main-Thread und scheiterte dort reproduzierbar nach rund 130 Sekunden mit „the requests timed out (a 30s wait failed)". Der Aufruf wartet synchron auf den Setup-Request des Mirroring-Delegate — und den blockierte er selbst, solange die Runloop noch nicht lief. Er laeuft jetzt drei Sekunden nach dem Start auf einem Hintergrund-Thread und ist nach rund elf Sekunden durch.
- Waehrend des Upload-Laufs oeffnet die App ihren eigenen Store ohne CloudKit. Zwei Stores, die im selben Prozess dieselbe Zone desselben Containers spiegeln, konkurrieren sonst um denselben Setup-Request; das Startargument macht den Lauf ohnehin zum Werkzeug und nicht zum normalen Start.
- Fehlschlaege des Uploads sind erstmals lesbar: statt `localizedDescription` („Ein Core Data-Fehler ist aufgetreten") laeuft der Fehler durch `CloudSyncErrorFormatter` und landet zusammen mit dem Erfolgsfall im System-Log. `print` allein war ausserhalb von Xcode unsichtbar, weil es in eine Pipe blockgepuffert schreibt.
- Damit sind `CD_reflection`, `CD_reviewedAt`, `CD_completedAt` und `CD_carryOverCount` erstmals im Development-Schema. Sie fehlten seit der Modellaenderung vom 4. August: CloudKit legt ein Feld faul an, naemlich erst beim Export eines Records mit Wert darin — ein durchgehend `nil` gebliebener Optional bleibt dem Schema deshalb unbekannt. `CD_order` war nur deshalb vorhanden, weil die Ordnungsnormalisierung jeden Goal-Record einmal neu geschrieben hat.
- ~~**Offen:** Deploy des Schemas nach Production.~~ **Erledigt** (in der Konsole geprueft, 2026-08-16): Production fuehrt dieselben Felder wie Development, Feldzahl je Record Type identisch (CD_AnkerTask 19, CD_Day 16, CD_Goal 16, CD_TimeBlock 17, CD_Week 17). `CD_completedAt`, `CD_carryOverCount`, `CD_reflection` und `CD_reviewedAt` sind vorhanden. Ein weiterhin ausbleibender Sync zwischen zwei TestFlight-Geraeten hat also eine andere Ursache.
- Drei Icons angeglichen, die fuer dieselbe Aktion je nach Flaeche verschieden aussahen: „Erledigt zuruecknehmen" ist im iPhone-Wisch jetzt `.open` statt `.undo` (wie im Mac-Hover — der Partner `.check` ist ein Zustand, kein Aktionsicon), „In die naechste Woche verschieben" im Mac-Hover `.nextMonth` statt `.week` (wie im Kontextmenue, gleiches Kuerzel ⌘⇧M), und der iPhone-Wisch „Verschieben" `.pickDate` statt `.week`, weil er dasselbe Blatt oeffnet wie „Datum waehlen …". Geprueft ist ausserdem: kein SF-Symbol und kein roher `Image("…")`-String im Code, alle 41 Imagesets `idiom: universal` ohne Plattformvarianten, jede referenzierte Glyphe vorhanden, kein verwaistes Asset.
- Die Rolle `AnkerIcon.undo` hat dadurch keine Aufrufstelle mehr. Sie bleibt vorerst stehen; das zugehoerige `lucide-undo-2` waere sonst ebenfalls verwaist.
- TestFlight-Uploads laufen ohne Rueckfrage durch: `ITSAppUsesNonExemptEncryption` steht als `false` in der Info.plist. Bisher blieb jeder Build in App Store Connect liegen, bis die Export-Compliance-Frage von Hand beantwortet war. Die App benutzt ausser HTTPS/CloudKit keine Verschluesselung und faellt damit unter die Ausnahme.

## 2026-08-04

### Entwurfsrunde 3 — Objekte werden rund, Struktur bleibt scharf

Grundlage ist `Daivento Apple-getunt.dc.html`, umgesetzt ist **3b** fuer iOS und Mac. Der Entwurf
weicht den Nullradius nicht auf, er trennt zwei Mengen: Apple rundet, was man **anfasst oder was
schwebt**; Modernist setzt Nullradius fuer **Struktur**.

- **Rund** sind jetzt Knoepfe und Felder (8pt), Karten (10pt), das Erledigt-Kaestchen (4pt) und Auswahlkacheln — immer `style: .continuous`, nie `.circular`. `AnkerRadius` benennt **Rollen**, keine Groessen: eine Rolle sagt, warum etwas rund ist.
- **Scharf** bleiben das 4x7-Raster, die Fortschrittsbalken, alle Sektionskanten und das Rueckblick-Plakat. Daten und Flaechen sind keine Objekte.
- **2px trennt Bereiche, 1px trennt Zeilen** (`AnkerRule.Weight`). Eine 2px-Kante an jeder Listenzeile liest sich wie ein Tabellengitter statt wie eine Liste. Auf dem Mac gehen damit auch Fenster- und Segmenttrenner auf Hairline.
- **Elevation statt Rahmen:** Listen sitzen in `.ankerCard()` mit zwei Schattenlagen. Das ist die einzige Stelle, an der „nichts schwebt" bewusst zurueckgenommen ist; `.shadow(` bleibt ausserhalb der Tokendateien verboten, damit es dabei bleibt.
- **Mac:** die Sidebar-Auswahl ist eine 8pt-Kachel im Akzent statt einer Kantenmarke. Die Kennzahlenreihe behaelt ihre 2px-Kanten — sie ist Struktur.
- **Die Schranken pruefen jetzt nicht mehr *ob*, sondern *wie*:** roher Radius, fehlendes `.continuous` und `.circular` sind Verstoesse; das pauschale Radius- und Kapselverbot ist weg. 15 Schranken bleiben es.
- **Zwei echte Fehler kamen dabei heraus**, beide im Dunkelmodus und beide durch den gekippten Akzent aufgedeckt:
  - `onAccent` war fest Weiss. Im Dunkelmodus stand der Haken damit weiss auf der hellen Kaestchenfuellung — unsichtbar. Jetzt kippt er mit der Fuellung auf Tinte; als Test festgehalten.
  - Die angebotenen Zielfarben sind Rampenstufen, wurden aber als rohe Hexwerte aufgeloest. Ein dunkles Ziel wie `#2D2B2B` war als Balken auf dunklem Grund nicht zu sehen (1,25:1). Sie laufen jetzt ueber die spiegelnde Rampe.
- Der Kontrasttest pruefte ausserdem eine Paarung, die es in der App nicht gibt (weisse Schrift auf Zielfarben). Er prueft jetzt, was wirklich vorkommt: Zielfarben als Marke gegen den Grund, 3:1 in beiden Modi.
- Vier neue Tests halten die Mengentrennung fest: Radiusrollen und ihre Ordnung, Sektions- gegen Zeilenlinie, Karte heller als ihr Grund in beiden Modi, Zeilentrenner schwaecher als ein Rahmen. 133 Tests gruen, beide Plattformen.

### iPhone: eigene Fensterrahmung statt der Systemleiste, Tableiste nach Vorlage

Nachgefragt wurde, ob 3b auf dem iPhone wirklich vollstaendig ist. War es nicht: der **Inhalt** lief
auf der neuen Sprache, die **System-Chrome** nicht — und auf iOS 26 ist sie Liquid Glass, also genau
das, was der Neuentwurf ersetzt hat. Gemessen am Simulator, nicht am Code gelesen.

- **Die Navigationsleiste ist weg.** Toolbar-Elemente sassen in schwebenden Glaskapseln, Titel und Knopfbeschriftungen in San Francisco, und der Titel war auf Heute zu „H…" gequetscht, auf Woche und Jahr unsichtbar. Neu: `toolbar(.hidden, for: .navigationBar)` plus die Bausteine in [Anchor/AnkerPhoneChrome.swift](Anchor/AnkerPhoneChrome.swift). Der Mac behaelt seine Systemleiste — dort ist sie nicht aus Glas und traegt die Fensterknoepfe.
- **Zwei Wege wurden gemessen, nicht geraten.** Variante A („Systemleiste stylen") ist gescheitert: `UINavigationBarAppearance` und `UIBarButtonItemAppearance` greifen auf die Kapseln nicht durch — kein sichtbarer Unterschied, dafuer verschwand der grosse Blatt-Titel ersatzlos. Variante B ist umgesetzt.
- **Die Kopfzeile eines obersten Bildschirms hat keinen Titel und keine eigene Kante.** So zeichnet es die Vorlage: oben steht die Datumszeile des Inhalts mit ihrer 2px-Kante, und wie der Bildschirm heisst, sagt die Tableiste. Ein Titel „Heute" ueber einer Tableiste, die „Heute" hervorhebt, waere dieselbe Aussage zweimal.
- **Sieben Blaetter und Bildschirme** laufen jetzt ueber **eine** Aufrufstelle je Blatt, `.ankerSheetChrome(_:cancel:confirm:)`. Die Plattformweiche steckt darin.
- **Die Tableiste folgt der Vorlage:** nur Text in Versalien, keine Umrandung, aktiv eine 8pt-Pille in der blassen Akzentstufe. Vorher stand ein Icon ueber jeder Beschriftung und ein 2px-Rahmen um die ganze Leiste. Sie heisst jetzt `AnkerTabBar` statt `GlassTabBar` — in einer App, deren Punkt es ist, dass nichts aus Glas ist, war der Name irrefuehrend.
- **Erfassungszeile und Tableiste sind ein Block:** eine 2px-Kante in Tinte an seinem Kopf, eine Haarlinie dazwischen, beide auf dem Grund. Vorher hatte jede Leiste eigene Kanten und eine eigene Flaeche.

**Drei Fehler, die dabei herauskamen:**

- **Die Tableiste verdeckte die Erfassungszeile.** Sie lag als Overlay in einem `ZStack`, und jede Ansicht musste sich selbst 96pt Freiraum lassen — drei taten es, die Heute-Ansicht nicht. Ausgerechnet dort, wo der Entwurf den Bildschirm auf die Erfassungszeile ausrichtet. Jetzt ist sie ein `safeAreaInset`; das Freiraum-Token ist damit ueberfluessig und entfernt.
- **Die Ankerdetailansicht wurde eine Sackgasse.** `GoalDetailView` hat keine eigene Schliessen-Schaltflaeche, sie hing komplett am Zurueck-Knopf der Systemleiste. Die Kopfzeile traegt den Weg jetzt selbst.
- **Der erste Zurueck-Knopf tat sichtbar nichts.** Der Baustein von `navigationDestination` ist escapend und fing eine Momentaufnahme der Wurzelansicht ein — `navigation.popToTopLevel()` schrieb in die Kopie. Laeuft jetzt ueber `@Environment(\.dismiss)`. Gefunden hat es ein Test, der wirklich zurueck navigiert; die bloesse Existenz des Knopfes haette bestanden.

Dazu behoben: auf der Wochenuebersicht stand bei null Ankern ein leeres Band mit einer Sektionskante
darunter, und die Hinweiszeile der Erfassung zaehlte die Ziele der ungeordneten Beziehung statt der
vier Anker. Neu sind zwei iOS-UI-Tests in
[AnchorUITests/PhoneChromeTests.swift](AnchorUITests/PhoneChromeTests.swift) — sie laufen gegen einen
iOS-Simulator, nicht gegen `platform=macOS`.

### Entwurfsrunde 3b auf alle Flaechen gezogen

Runde 3 hatte die Mengentrennung eingefuehrt, aber nur dort angewandt, wo der Entwurf zeichnet.
Der Rest lief weiter auf dem alten Muster `background(surface)` + `Rectangle().stroke(divider, 2px)`
+ `clipShape(Rectangle())` — 29 Stellen ueber neun Dateien.

- **Vier Flaechen-Idiome statt eines handgebauten Musters.** `.ankerCard()` traegt Inhalt und schwebt, `.ankerCard(elevated: false)` ist eine getoente Hinweisflaeche, `.ankerField()` ein Eingabefeld, das neue `.ankerControl()` ein Knopf oder eine Auswahlkachel. `.ankerPanel()` bleibt der scharfen Struktur.
- **Neun Eingabefelder waren noch eckig** — Aufgabentitel in drei Blaettern, Tagesfokus, Notizen, Onboarding-Anker, Rueckblickantwort, das Inline-Titelfeld. Ebenso alle Schrittpfeile, Wochenanzeigen, Tagesauswahlen, Erfassungschips und Farbfelder.
- **Der Systemschalter hatte sein eigenes Kaestchen** (scharfes Quadrat mit Innenquadrat). Er benutzt jetzt dieselbe Form wie das Erledigt-Kaestchen an einer Aufgabe — zwei Formen fuer denselben Ja-Nein-Zustand waren zwei Aussagen ueber eine Sache.
- **Der Zeitplan im Tagesdetail war ein Tabellengitter:** jede Zeile mit eigener 2px-Kante. Jetzt eine Karte mit Haarlinien darin. Dasselbe fuer die iCloud-Diagnoseliste, deren `Divider()` durch `AnkerRule(weight: .row)` ersetzt sind.
- **Segmentleisten** (Ankerstreifen, Ansichtswechsel Heute/Woche/Jahr, Behalten/Streichen/Verankern) werden als ein gerundetes Objekt geklippt, damit die Auswahlfuellung nicht eckig an die runde Kante stoesst.
- **Zeilentrenner auf Haarlinie** in Archiv, Onboarding, Ankerliste, Uebertragsliste und Sidebar-Fuss. Die Kennzahlengitter behalten ihre 2px — sie sind Struktur.
- Undo-Hinweis, Mehrfachauswahl-Leiste und beide Ziehvorschauen sind Karten: sie schweben buchstaeblich ueber dem Inhalt.

**Drei Fehlerklassen kamen dabei heraus, alle mit Test oder Schranke abgesichert:**

- **`#9B9797` als Schrift, an sechs Stellen.** Genau der Wert, den das Projekt fuer die Mikrobeschriftung schon einmal als unlesbar verworfen hatte — auf der iCloud-Statuszeile gemessene 2,4:1. Alle sechs laufen jetzt ueber die Textrampe. Und `PriorityTag` benutzte `accentMark` als Flaeche mit einem Buchstaben darauf: das ist die 3:1-Markenfarbe, gemessen 4,20:1. Die drei Stufen kommen jetzt aus der Rampe.
- **Die Ankerreihenfolge kam siebenmal aus `week.goalList`.** Diese Beziehung ist nach einem CloudKit-Sync ungeordnet: „Anker 2" vor einem Titel war damit eine geraeteabhaengige Aussage, der Ankerstreifen auf Heute zeigte alle Ziele statt der vier, und der Tagesfokus fiel auf ein zufaelliges Ziel zurueck. Alles laeuft jetzt ueber `GoalOrdering`; eine neue Schranke faengt den Rueckfall.
- **Fuenf Ansichten ohne einen einzigen Aufrufer** (`AnchorGlyph`, `GoalBanner`, `WeekDot`, `AnkerPrimaryActionBar`, `TimeBlockRow`) sind entfernt statt mitgezogen — sonst waeren sie eine zweite Sprache fuer nichts.

Drei neue Schranken: rohes `.white`/`.black` (die bisherige Regel prueste nur `Color.white` und hat
die Dunkelmodusfehler durchgelassen), `clipShape(Rectangle())` und ungeordnete Ankerzugriffe. 18
Schranken, 128 Unit- plus 6 UI-Tests gruen, beide Plattformen. Ein neuer Test misst getoente
Hinweisflaechen **zusammengesetzt** statt im Aufruf — dort stirbt Kontrast unbemerkt, und genau er
hat die 2,4:1 gefunden.

### Datenfehler behoben: Onboarding auf einem neuen Gerät

Gemeldet als „das Onboarding laesst sich nach dem iCloud-Sync nicht abbrechen, dadurch werden die
Staende der anderen Geraete mit den Onboarding-Inhalten ueberschrieben". Dahinter steckten **drei**
getrennte Defekte. Jeder hat jetzt seinen Test.

- **Das Onboarding fragte nur die laufende Woche.** `WeekPlanning.needsOnboarding` prueft jetzt den ganzen Bestand: ein echtes Wochenziel oder eine Aufgabe irgendwo heisst, dass dieser Nutzer eingerichtet ist. Vorher entschied allein, ob die *laufende* Woche Anker hat — und die hat am Montagmorgen regelmaessig keine. Ein neu installiertes Geraet landete damit im Onboarding, obwohl der ganze iCloud-Bestand schon da war.
- **Es gab keinen Ausweg.** Sobald irgendeine Woche existierte, wurde `hasCompletedOnboarding` gar nicht mehr gelesen — ein Ueberspringen waere wirkungslos geblieben. Das Flag zaehlt jetzt wieder, und es gibt „Spaeter einrichten" in beiden Schritten. Die App ist auch leer benutzbar: Erfassungszeile und der Knopf fuer ein neues Wochenziel sind da.
- **Beim Zusammenfuehren doppelter Wochen entschied die UUID, welche vier Anker sichtbar bleiben.** Legt ein neues Geraet eine Woche an, waehrend der Erstimport dieselbe Woche noch bringt, entstehen zwei Datensaetze fuer denselben Montag. Beide numerieren ihre Anker ab 0; nach dem Zusammenfuehren standen zwei Ziele auf Platz 0, und der Gleichstand ging nach UUID. Gewann die Onboarding-Woche, belegten ihre vier frischen Anker die sichtbaren Plaetze und die echten rutschten in den Ueberschuss — von aussen nicht von „ueberschrieben" zu unterscheiden. Jetzt ueberlebt die **inhaltsreichere** Woche (Ziele, Aufgaben, Rueckblick), bei echtem Gleichstand weiter die kleinere UUID, damit zwei Geraete nicht auseinanderlaufen. Die Ziele der ueberlebenden Woche behalten ihre Plaetze, die der doppelten kommen dahinter.
- **Zwei Sicherheitsnetze fuer das Rennen:** `createOnboardingAnchors` legt nichts an, wenn die Woche schon echte Anker hat, und `completeOnboarding` springt in diesem Fall direkt in die App. Kam der Import also zwischen Anzeige und Tippen an, entstehen keine acht Anker aus vier Eingaben.
- **Waehrend der Erstimport laufen kann, wird nicht nach Ankern gefragt.** Stattdessen ein ehrlicher Zwischenschritt („iCloud holt deine Wochen") mit zwei Auswegen. Nach acht Sekunden geht es von selbst weiter, damit ein wirklich neuer Nutzer nicht auf einen Spinner starrt, der nie endet.
- Ein Bestandstest hielt das alte Verhalten fest und ist mitgeaendert — samt Begruendung, warum der Vertrag sich aendert. Die Sorge dahinter (eine leere App haelt sich nach einer DSGVO-Loeschung fuer eingerichtet) traegt das Flag selbst: `DataPortability` entfernt es mit.
- Zusammen 129 Tests gruen, beide Plattformen, alle 15 Schranken.

### App-Icons Apple-konform

- **macOS bekommt die gerundete Form mitgeliefert.** macOS maskiert App-Icons nicht — ein randloses Quadrat stand im Dock als harte Kante neben allen anderen Apps. Die sieben macOS-Groessen folgen jetzt Apples Raster: Koerper 824 von 1024 zentriert (also 100 Punkte Rand), Eckenradius 185,4, Rand transparent. Nachgemessen: exakt 9,77 % Rand bei 1024.
- Die Ecke kommt aus SwiftUIs `RoundedRectangle(style: .continuous)`, nicht aus einem Kreisbogen. Apples Ecke ist eine fortlaufende Kurve; ein `CGPath(roundedRect:)` waere sichtbar kantiger.
- **iOS bleibt bewusst randlos und ohne Rundung.** Dort maskiert das System selbst mit demselben Quadrat — eine mitgelieferte Rundung ergaebe eine doppelte Kante. Gepruefte Frage dabei: schneidet Apples Maske Rasterzellen ab? Gemessen **null** von 310.960 Rasterpunkten, in beiden Erscheinungen.
- Damit sind die Dateien getrennt: `AppIcon-*` fuer iOS (randlos, RGB ohne Alpha), `AppIconMac-*` fuer macOS (gerundet, RGBA mit transparentem Rand). Vorher diente eine Datei beiden Zwecken, was sich ausschliesst.
- Neu [Scripts/make-app-icons.swift](Scripts/make-app-icons.swift): erzeugt den Satz aus `assets/icon/`. Die macOS-Varianten sind abgeleitet, und ihre Vorschrift soll nachlesbar sein statt in sieben Dateien zu stecken. Geprueft, dass ein zweiter Lauf byteidentische Dateien liefert.
- Das Menueleisten-Icon war schon konform und blieb unberuehrt: Form ueber Alpha, null farbige Punkte — nachgemessen, nicht angenommen.

### Neues App-Icon

- App-Icon ist die **4 mal 7 Matrix** — vier Anker, sieben Tage, das Datenmodell als Marke. Quelle sind die Vorlagen in `assets/icon/`. Alle macOS-Groessen von 16 bis 1024 sind echte Vorlagen statt hochskalierter Kopien; vorher diente eine 1024er Datei fuer 512@2x mit.
- iOS bekommt eine eigene **dunkle** Variante (dieselbe Marke auf dunklem Grund) statt dreimal derselben hellen. Die getoente Variante bleibt die helle, wie zuvor.
- **Der Alphakanal ist entfernt.** Der App Store lehnt iOS-App-Icons mit Alphakanal ab, auch einen vollstaendig deckenden — und die Vorlagen hatten einen. Gemessen war er ueberall deckend, das Abflachen also verlustfrei.
- Neuer Menueleisten-Glyph (`MenuBarTemplate`, 18pt und 36pt, als Template): die Matrix auf vier Balken reduziert. Der Statusleistenknopf zeigt jetzt darauf.
- Das alte Ringlogo ist weg: `FokusringB` und `FokusringBMenu` samt der Ansichten `DaiventoLogo` und `AnchorBadge`, die es benutzten — beide hatte niemand aufgerufen.
- Beim Einbau lief ein Abflachen ueber `NSImage.draw` in einen selbst gesetzten `NSGraphicsContext` still ins Leere: ohne `NSApplication` zeichnet das nichts, die Bitmap blieb genullt, und beide 1024er Dateien kamen byteidentisch heraus. Aufgefallen an gleichen Hashes; ersetzt durch reines CoreGraphics.

### Aufgaben bearbeiten — eine Regel statt drei Sonderfaelle

- **Das Kaestchen hakt ab, der Titel wird bearbeitet.** In der Matrix hakte vorher ein Klick auf die ganze Chipflaeche ab: jeder Versuch, eine Aufgabe anzusehen, aenderte ihren Zustand, und der Titel war per Klick gar nicht erreichbar. Der Chip hat jetzt ein eigenes 14pt-Kaestchen (statt 22pt — in einer schmalen Spalte bliebe sonst kein Platz fuer den Titel).
- **Titel an der Stelle bearbeiten** (`TaskTitleField`): Doppelklick oeffnet das Feld, Enter sichert, Escape verwirft, Fokusverlust sichert. Ein leerer Titel wird verworfen statt die Aufgabe zu loeschen — Text wegzuwischen darf keine Loeschung sein. Das passt zum Entwurf besser als ein Blatt: Modernist arbeitet mit Flaechen und Kanten, nicht mit Dialogen.
- **Das Blatt „Aufgabe bearbeiten" war in der Tagesliste toter Code.** `TaskCard` hielt den Zustand und das fertig verdrahtete Sheet, aber nichts setzte es je — im Kontextmenue fehlte der Eintrag. Damit war der Titel auf *Heute* und im *Tagesdetail* ueberhaupt nicht aenderbar. Jetzt stehen dort „Titel aendern" und „Bearbeiten …" (⌘E) im Menue, plus dieselben Vorlese-Aktionen.
- **Das Ankerdetail hatte gar kein Menue** — nur ein Kaestchen. Es benutzt jetzt dieselbe Aufgabenzeile wie die Tagesliste, mit dem **Tag** in der Metazeile statt dem Anker: dort haben alle Aufgaben denselben Anker, der Tag ist die Information. Damit gibt es dort auch Prioritaet, Verschieben, Duplizieren, Loeschen und den Undo-Hinweis.
- Umbenennen laeuft ueber `TaskActions.rename` und ist ruecknehmbar — `TaskSnapshot` fuehrte den Titel schon.
- Ein Fehler, der beim Bauen auffiel: bekam das Feld nie den Tastaturfokus, feuerte `onChange` nicht und das Feld blieb offen stehen. Der Fokus wird jetzt nach einem Durchlauf gesetzt und der Abschluss erst nach dem ersten Fokus ausgeloest.
- Drei Unit-Tests fuer das Umbenennen (Trimmen, Nulloperation, leerer Titel, Undo) und ein UI-Test, der beide Haelften der Regel festhaelt: Doppelklick bearbeitet **ohne** abzuhaken, das Kaestchen hakt ab. 122 Tests gruen, beide Plattformen, alle 15 Schranken.

### Entwurfsrunde 2 — die Sidebar kann nur eine Sache sein

Grundlage ist `Daivento Mac Sidebar.dc.html`. Die Datei legte **zwei** unvereinbare Sidebars vor;
umgesetzt ist **2a „Zeitschiene"** (Entscheidung des Nutzers). Die vier gemeinsam festgelegten
Punkte gelten unabhaengig von dieser Wahl und sind alle umgesetzt.

- **Die Sidebar beantwortet nur noch „wann".** Vorher machte sie vier Dinge gleichzeitig — Ansichtswechsel, Zeitnavigation, Zielliste, App-Utility — und drei davon beantworteten dieselbe Frage. Uebrig bleibt eine Schiene aus Wochenzeilen.
- Pro Woche **sieben Quadrate** statt einer aufklappbaren Tagesliste: gefuellt = erledigt, Rahmen in Tinte = offen, rot = heute, Rahmen in der Trennlinienfarbe = nichts geplant. Die vierte Stufe ist die eigentliche Aussage — nichts geplant ist nicht dasselbe wie nichts geschafft. Vergangene Wochen bleiben damit lesbar, ohne Platz zu kosten.
- **Ein** Zeitnavigator: Stepper plus „Heute". Weg sind der Kalenderknopf und die Monatspfeile in der Sidebar sowie das Wochentrio im Matrixkopf — drei Bedienelemente fuer dieselbe Frage.
- **Der Ansichtswechsel Heute/Woche/Jahr** ist ein Modus des Inhalts und sitzt in `AnkerContentHeader`, zusammen mit Woche und gewaehltem Tag. Bewusst eine Zeile im Inhalt und kein `ToolbarItem`: eine eigene Segmentleiste erscheint auf macOS in der Fensterleiste eines `NavigationSplitView` nicht verlaesslich — im Zugriffsbaum fehlte sie ganz.
- **Die Anker verlassen die Navigation** und stehen als Streifen ueber dem Inhalt (`AnchorStripView`), mit Nummer, Balken und Stand. In der Sidebar waren sie ein Link-Label; hier sind sie ein Zustand: „steht still", „noch nicht begonnen", „3 Tage aktiv".
- Das weiche Limit ist **sichtbar**: der fuenfte Anker steht blasser und sagt „ueber Empfehlung". `AnkerStatistics.allAnchors` liefert alle, `week()` weiter nur die vier — die Kennzahlen der Woche duerfen sich nicht verschieben, wenn zwei Geraete offline fuenf erzeugt haben.
- **Rueckblick scharf, nicht laut.** Erreichbar ist er immer, aber bis Sonntag bleibt die Zeile grau und ohne Zaehler („ab So"). Ab Sonntag wird sie rot und nennt den Uebertrag („3 offen"). Kein Modal.
- **Uebertrag pro Aufgabe** statt alles-oder-nichts: behalten, streichen oder an einen Anker der Folgewoche neu verankern. Der Abschlussknopf nennt das Ergebnis („Schliessen · 3 uebertragen, 1 streichen"); nachgefragt wird nur, wenn wirklich geloescht wird — ein Uebertrag ist umkehrbar, eine gestrichene Aufgabe nicht. Eine uebertragene Aufgabe behaelt ihren Wochentag: was fuer Freitag gedacht war, bleibt eine Freitagssache.
- **Archiv als Ort** (`daivento://archive`): abgeschlossene Wochen mit Ankern und Aufgaben, neueste zuerst. Als archiviert gilt eine Woche, die geschlossen **oder** vergangen ist — wer den Rueckblick ueberspringt, darf nicht den Zugang zu seinen eigenen Daten verlieren. Die Suche greift ausdruecklich mit ins Archiv; der Platzhalter sagt das.
- Marker und Bedienelemente bleiben Quadrate: das neue Archiv-Icon hat sein `rx="1"` verloren, es waere die einzige gerundete Ecke der App gewesen.
- 15 neue Unit-Tests fuer die vier Festlegungen — Tagesquadrate, Sieben-Felder-Raster auch bei fehlenden Tagen, Rueckblickreife vor und ab Sonntag, Entscheidung pro Aufgabe inklusive Neuverankerung, Archivzugehoerigkeit, Ueberschuss im Streifen, Stillstand erst nach zwei Tagen. Zusammen 113 Unit-Tests und 5 UI-Tests gruen, beide Plattformen bauen, alle 15 Schranken halten.
- Stringkatalog auf 119 Eintraege nachgezogen.

### Neuentwurf „Modernist"

- Die Oberflaeche folgt einem neuen Entwurf: **das Datenmodell ist die Oberflaeche**. Statt eines Kalenderabbilds zeigt die App 4 Anker mal 7 Tage als ein Raster. Flach statt Liquid Glass — Radius 0 an 118 Stellen, keine Verlaeufe, keine Materialien, keine Schatten, 2px-Regeln als einzige Kante.
- Neue Anker-Matrix auf Mac und iPad (`AnkerMatrixView`): Zeile = Anker, Spalte = Tag, plus eine Eingangskorb-Zeile „Ohne Anker". Eine Aufgabe an eine Zelle zu ziehen setzt Wochenziel **und** Tag in einer Bewegung.
- Erfassungszeile: tippen, Enter, fertig. `!a`/`!b`/`!c` fuer die Prioritaet, `#1`–`#4` fuer den Anker, `mo`–`so` fuer den Wochentag, in beliebiger Reihenfolge. Die Hinweiszeile zeigt den **aufgeloesten** Stand vor dem Anlegen — deshalb ist die Doppelbedeutung von „so" tragbar. Wochentagskuerzel greifen nur an Wortgrenzen, „Somit" und „Modul" bleiben Titel.
- Jahresuebersicht ist ein Band aus 52 Balken (einer pro ISO-Woche) statt zwoelf Monatskacheln. Die Luecken sind die Aussage: eine Woche ohne Datensatz ist eine Woche ohne Plan.
- Ankerdetail zeigt einen Tempo-Satz statt einer Prozentzahl — „Bei diesem Tempo schaffst du 6 von 7". Der Prozentwert bleibt als Balken und als Vorlesetext.
- Wochenrueckblick ist ein rotes Vollflaechen-Plakat: eine grosse Zahl, die Serie, der nicht gehaltene Anker mit **benanntem** Uebertrag, eine Frage. Die Antwort liegt jetzt in `Week.reflection` und ueberlebt den Bildschirmwechsel; vorher war sie `@State` und beim Verlassen weg. Neu „Woche schliessen", mit der Wahl, offene Aufgaben zu uebertragen oder nicht.
- Onboarding setzt bis zu vier Anker in einer numerierten Liste, statt das Konzept in vier Zeilen Prosa zu erklaeren. Dass die Liste bei vier aufhoert, erklaert es selbst. Die iCloud-Frage bleibt der erste Schritt.
- Der Ring ist ueberall weg (`ProgressRing` geloescht), ebenso `GlassTabBar` und `GlassFAB` — die Erfassungszeile ersetzt den FAB. Marker und Bedienelemente sind Quadrate; rund ist nur noch der Ring des Ankersymbols.

### Fundament

- **Archivo** als Variable Font gebuendelt (OFL-1.1), Gewichte 500–900 ueber die `wght`-Achse gepinnt. Statische Schnitte gibt es bei Google Fonts nicht. Ziffern laufen ueber ein Schriftmerkmal gleich breit — `monospacedDigit()` wirkt auf eigene Schriften nicht.
- **42 Lucide-Icons** als Vektor-Imagesets (ISC) ersetzen 74 SF-Symbol-Stellen.
- Neue Tokenschicht: `AnkerType` (20 Typo-Tokens) ersetzt 191 nackte `.font(.system(size:))`. `AnkerSpacing` ersetzt 218 rohe Abstandszahlen. `AnkerIcon`, `AnkerRule`, `AnkerProgressBar`, `AnkerButtonStyle`, `AnkerToggleStyle` dazu.
- **`Scripts/design-guard.swift`**: 15 Grep-Schranken gegen den Rueckfall — Radius, Kapsel, Material, Verlauf, Schatten, Weichzeichnung, rohe Schriftgroesse, Laufweite, Grossschreibung, SF-Symbole, Weiss/Schwarz, Ring, Rohhex, Kreis, roher Abstand. Ein begruendeter Ausnahmemarker ist moeglich, verlangt aber den Grund im Klartext daneben.
- Der Akzent ist dreigeteilt, weil eine Farbe nicht in allen drei Rollen 4,5:1 erreicht: `accentMark` fuer Marke und Marker (braucht 3:1), `accentFill` als Flaeche unter weisser Schrift (4,74:1), `accentInk` als Schrift auf Grund (6,41:1 hell, 5,56:1 dunkel). Neun Theme-Tests rechnen die Kontraste in beiden Farbmodi nach.
- Die Mikro-Beschriftung des Entwurfs (`#9b9797`, 2,59:1) waere unlesbar und nutzt `inkSecond`; die Hierarchie kommt aus Groesse, Gewicht und Laufweite. Bewusste Abweichung, im Test festgehalten.
- `AccentColor.colorset` war **leer** — die App hatte gar keine definierte Akzentfarbe und benutzte das OS-Blau.

### Modell und Kennzahlen

- `Goal.order` gibt der Ankernummer 1–4 einen stabilen Halt. Vorher war sie die Position in `week.goalList`, und die kommt nach einem CloudKit-Sync ungeordnet zurueck: die Nummern wechselten nach jeder Synchronisierung. `StoreMaintenance` sortiert Ziele beim Zusammenfuehren jetzt nach, wie es das fuer Tage schon tat.
- `AnkerTask.completedAt` haelt fest, **wann** etwas fertig wurde — Voraussetzung fuer stuerkster Tag und Tempo. `carryOverCount` zaehlt Uebertragungen ueber die Wochengrenze, aber nur fuer offene Aufgaben: Erledigtes verschieben ist keine Uebertragung.
- `Week.reviewedAt` als optionales Datum statt `Bool`: nil/nicht-nil konvergiert beim Sync ohne Konflikt.
- Neu `AnkerStatistics` mit allen Aussagen der App. „Gehalten" heisst: jeder benutzerangelegte Anker hat mindestens eine erledigte Aufgabe — mitten in der Woche waere „vollstaendig erledigt" fast immer 0 und damit unbrauchbar. Eine Woche ohne Datensatz unterbricht die Serie nicht.
- Die 4-Anker-Grenze war **pro Geraet** geprueft: zwei Geraete offline konnten fuenf Ziele erzeugen, und `prefix(4)` versteckte auf jedem Geraet ein anderes. Die Matrix zeigt die vier nach `(order, id)` und **benennt** einen Ueberschuss sichtbar.

### Fehler, die dabei aufgefallen sind

- `NSColor(calibratedRed:)` statt `srgbRed:`: **jede** Farbe der App war gegenueber ihrem Hexwert verschoben. `#DD2B0F` erreichte 4,09:1 statt 4,74:1. Gefunden durch die neuen Kontrasttests.
- Die Wischgesten waren toter Code: `swipeActions` wirkt nur in einer `List`, und die App hatte keine einzige. Die iPhone-Listen sind jetzt echte `List`s — damit funktioniert das Interaktionskonzept erstmals.
- Der Tagesheader der Matrix stand **ausserhalb** der Scrollansicht. Er zog die Ansicht auf seine eigene Breite und schob die Erfassungszeile aus dem Fenster: der Knopf „Sichern" war auf schmalen Fenstern nicht erreichbar. Beim Querscrollen liefen ausserdem Header und Spalten auseinander.
- Zeilen in der Seitenleiste hatten keine Trefferflaeche ueber die ganze Breite — ein Klick in die Zeilenmitte ging ins Leere. Dasselbe galt fuer das Erledigt-Kaestchen.
- `#1` in der Erfassungszeile griff auf `week.goalList` zu, also ungeordnet und ohne Ankerfilter: auf jedem Geraet haette es auf ein anderes Ziel zeigen koennen.
- `GoalDetailView` beobachtete seine Woche nicht (`let` statt `@Bindable`): ein Haken blieb im Kennzahlenblock ohne sichtbare Wirkung, bis die Ansicht neu aufgebaut wurde.
- `WeeklyReviewView` behauptete `max(reachedGoals, 3)` erreichte Ziele — bei weniger als drei eine Falschaussage.
- Zwei Stellen schrieben `isDone` direkt statt ueber `TaskActions` und haetten damit `completedAt` stillschweigend uebersprungen; drei Ansichten legten `AnkerTask` von Hand an.

### Tests und Doku

- 98 Unit-Tests (vorher 34) und 5 UI-Tests laufen, beide Plattformen bauen, alle 15 Schranken halten. Neu: Erfassungssyntax (16 Faelle), Kennzahlen und Ankerordnung, Matrixaufbau, Schrift- und Farbtokens.
- Die UI-Tests pruefen jetzt den Verankerungsfluss und die Erfassungszeile. Sie ersetzen einen Test, der an „Mein Wochenziel", „Erstes Wochenziel setzen" und „0 Prozent" hing — alle drei gibt es nicht mehr.
- Drei sichtbare Texte schrieben „fuer" statt „für", darunter zwei Fehlermeldungen (N2 im Analysebericht war als eine Stelle notiert).
- Stringkatalog von 141 auf 104 Eintraege bereinigt; `CLAUDE.md` auf den neuen Stand gebracht. Der Neuentwurf ist die verbindliche visuelle Referenz, `Anker_Design_System_v2.html` nur noch Historie.
- Archivo und Lucide sind gebuendelt. Die Regel „keine Custom-Fonts, keine Drittanbieter-Dependencies" ist damit ausdruecklich aufgehoben; weitere Abhaengigkeiten bleiben ausgeschlossen. Kein Tracking, keine Netzwerkaufrufe ausser CloudKit.
- **Offen und nicht aus dem Repo machbar:** das CloudKit-Schema muss in der CloudKit-Konsole von Development nach Production deployt werden. Bis dahin gilt: laeuft in Xcode, tot in TestFlight.

- `AnkerRootView` entflochten: Navigation und Deep Links liegen jetzt in `AnkerNavigationState`, das Aufloesen von Wochen und Tagen sowie der Onboarding-Zustand in `WeekPlanning` — beides ohne View-Bezug und direkt testbar. Die acht Navigationsmethoden bestanden aus derselben Dreierfolge und sind zu einer zusammengefasst.
- Navigationszustand ueberlebt den Neustart (`@SceneStorage`): die App startet wieder in der Woche und auf dem Tag, an denen zuletzt gearbeitet wurde.
- Deep Links ergaenzt: `daivento://today`, `//week/2026-08-03`, `//day/2026-08-05`, `//goal/<UUID>`, `//year`, `//review`. Datumsangaben in ISO, damit ein Link unabhaengig von der Regionseinstellung des Empfaengers funktioniert; eine unverstaendliche URL laesst den Zustand unangetastet.
- Auf dem iPhone liegen Tages- und Zieldetail auf einem echten `NavigationStack` — die Zurueck-Gestik funktioniert, wo es vorher nur einen Schliessen-Knopf gab.
- Grosse Sammeldateien aufgeteilt: `OverviewViews.swift` (1483 Zeilen) und `DetailAndCaptureViews.swift` (994) sind weg, `TaskEditing.swift` in `TaskActions.swift` und `TaskEditorSheets.swift` getrennt. Keine Datei ueber 1000 Zeilen mehr.
- `CloudSyncStatusCenter` entkoppelt: der Initialisierer ist nebenwirkungsfrei, die Beobachter melden an ihre eigene Instanz statt an `.shared`, und `StoreMaintenance` berichtet ueber das Protokoll `StoreMaintenanceReporting`. In Views ist die Statuszentrale ein injizierbarer Parameter.
- Duplikatpruefung aus dem View-`body` geholt: sie haengt jetzt an einem Zaehler eingegangener CloudKit-Importe statt an einer Signatur, die bei jeder Neuberechnung alle Wochen und Tage gruppierte.
- Alle 19 hartkodierten Hex-Farben sind Tokens in `Theme.swift`. Das Rot `#E0392E` stand in keinem Referenzdokument und ist auf das kontrastkorrigierte `#D93327` des Designsystems zusammengefuehrt.
- Datumsformatierung zentralisiert (`AnkerDateFormat`): zwoelf Formate an einer Stelle, 50 Aufrufstellen und acht lokale Wrapper umgestellt. `AnkerCalendar.iso` ist `static let` statt bei jedem Zugriff ein neues `Calendar`.
- Beispieldaten-Erkennung aus dem Auslieferungspfad entfernt: sie lief bei jedem Start und haette eine echte Woche mit vier gleichnamigen Zielen in KW 1/2026 geloescht.
- UI-Test fuer den Kernfluss ergaenzt: Onboarding, Aufgabe anlegen, an das Wochenziel verankern, erledigen, Fortschritt von 0 auf 100 Prozent. Dafuer `UITestMode` (`-DaiventoUITest`) mit leerem Store und abgeschaltetem iCloud — vorher haetten UI-Tests gegen die echten Daten des Nutzers gelaufen.
- Neun weitere Unit-Tests fuer Navigationszustand, Deep Links und Wochenplanung; 34 Unit-Tests und der UI-Test laufen, beide Plattformen bauen.
- Das Paket `AnkerKit` (A5) bleibt bewusst aus: sein Nutzen sind Widgets und Watch, die nicht anstehen. Modell und Logik liegen aber schon in eigenen Dateien ohne View-Bezug, damit das spaeter ein Umzug bleibt.

- Neuer Einstellungen-Bildschirm (`SettingsView`) mit Erscheinungsbild, iCloud-Sync und dem Weg zu Daten und Datenschutz. Erreichbar aus der Sidebar (Mac, iPad), aus dem Tab Mehr (iPhone) und auf dem Mac zusaetzlich ueber Command-Komma.
- Farbmodus einstellbar: System, Hell oder Dunkel. Auf macOS wird zusaetzlich `NSApp.appearance` gesetzt, sonst blieben die Farbtokens und das Statusbar-Popover im Systemmodus stehen.
- iCloud-Sync abschaltbar. Ohne Sync laeuft dieselbe Store-Datei ohne Mirroring weiter — vorhandene Daten bleiben, sie werden nur nicht mehr uebertragen. Der Wechsel greift beim naechsten Start, weil derselbe Store nicht zur Laufzeit erneut mit CloudKit verbunden werden kann (Core Data 134422); auf dem Mac gibt es dafuer einen Neustart-Knopf. Der Sync-Status hat dafuer eine eigene Phase "Sync aus" statt einer Fehlermeldung.
- Onboarding fragt die Sync-Entscheidung im ersten Schritt ab, das erste Wochenziel im zweiten.
- Suche ueber Aufgaben, Wochenziele, Tagesnotizen, Tagesfokus und Zeitbloecke (`AnkerSearch`). Das Suchfeld in der Sidebar war bisher eine Attrappe und funktioniert jetzt; auf dem iPhone fuehrt eine Lupe in der Navigationsleiste zum Suchblatt. Gross-/Kleinschreibung und Umlaute werden ignoriert, Notiztreffer auf die Fundstelle gekuerzt, und ein Klick springt zum Tag oder zum Wochenziel.
- Sieben Unit-Tests fuer Suche und Einstellungen ergaenzt; alle 26 Unit-Tests und beide Plattform-Builds laufen.

- Speicherfehler werden nicht mehr verschluckt: die 26 verbliebenen `try? modelContext.save()` laufen jetzt ueber `ModelContext.saveChanges()`, das den Fehler protokolliert und ueber `PersistenceFailureCenter` als Dialog anzeigt — mit der Moeglichkeit, erneut zu sichern. Vorher verschwand eine nicht gespeicherte Aenderung beim naechsten Start unbemerkt.
- Datenexport ergaenzt: alle Wochen, Ziele, Aufgaben, Zeitbloecke und Notizen lassen sich als JSON sichern, inklusive Datensaetzen ohne Woche oder Tag (Art. 15 und 20 DSGVO).
- Vollstaendige Loeschung ergaenzt: entfernt jeden Datensatz einzeln, damit die Loeschung auch nach iCloud exportiert wird und nicht bei der naechsten Installation zurueckkommt (Art. 17 DSGVO). Der Bestaetigungsdialog nennt die betroffenen Anzahlen; der Onboarding-Zustand wird mit zurueckgesetzt.
- Neuer Bildschirm "Daten und Datenschutz" mit Bestand, Export und Loeschung, erreichbar aus der Sidebar (Mac, iPad) und aus dem Tab Mehr (iPhone). Der macOS-Sandbox-Zugriff auf vom Nutzer gewaehlte Dateien ist dafuer von `readonly` auf `readwrite` gesetzt.
- `PrivacyInfo.xcprivacy` angelegt: kein Tracking, "Other User Content" zur App-Funktionalitaet, `UserDefaults`-Zugriff mit Grund `CA92.1`. Ohne dieses Manifest lehnt der App Store die Einreichung ab.
- Lokalisierung eingerichtet: `Localizable.xcstrings` mit Deutsch als Quellsprache und 115 extrahierten Texten, Projektsprache von `en` auf `de` umgestellt. Die 28 hartkodierten `Locale(identifier: "de_DE")` sind entfernt — Datumsangaben folgen jetzt der Regionseinstellung des Nutzers statt sie zu ueberschreiben.
- Automatische Zusammenfuehrung doppelter Datensaetze protokolliert jetzt jeden Eingriff (betroffene Kalenderwoche, Gewinner-ID, Anzahl Kinder) und weist das Ergebnis im Sync-Status und in der Sidebar aus. Vorher loeschte `StoreMaintenance` still und ohne Spur.
- Sieben Unit-Tests fuer Export, Loeschung, zentrales Speichern und das Zusammenfuehrungsprotokoll ergaenzt; alle 20 Unit-Tests und beide Plattform-Builds laufen.

## 2026-08-03

- `CLAUDE.md` mit Projektueberblick, Dateikarte, Referenzdokumenten und Konventionen ergaenzt.
- Projekt-Skills unter `.claude/skills/` angelegt: `daivento-build`, `daivento-swiftdata`, `daivento-design-system`, `daivento-task-interactions`.
- iCloud-Sync-Ursache behoben: die sandboxed macOS-App hatte keine Netzwerk-Client-Berechtigung (`ENABLE_OUTGOING_NETWORK_CONNECTIONS` war `NO`), CloudKit kam damit nicht ins Netz und der Export blieb dauerhaft aus.
- Falsche Sync-Warnung beseitigt: Saves aus den CloudKit-Import-Kontexten galten als neue lokale Aenderung und liessen den Status nach jedem Import auf "Export ausstehend" und dann auf "Sync pruefen" fallen.
- Watchdog fuer ausstehende Exporte von 45 auf 120 Sekunden angehoben und Hinweistext um fehlende Netzwerkverbindung erweitert.
- `initializeCloudKitSchema` laeuft nicht mehr bei jedem Debug-Start, sondern nur mit dem Startargument `-DaiventoInitializeCloudKitSchema`; der dabei geoeffnete zweite Store wird jetzt wieder freigegeben.
- Zusammenfuehrung doppelter Datensaetze aus dem Sync ergaenzt (`StoreMaintenance`): legen zwei Geraete dieselbe Kalenderwoche an, werden Wochen, Tage, Aufgaben, Zeitbloecke und Notizen verlustfrei vereinigt, mit geraeteunabhaengig gleichem Gewinner.
- Store-Erzeugung abgehaertet: ein nicht oeffenbarer CloudKit-Store fuehrt nicht mehr zu `fatalError`, sondern zum lokalen Fallback mit sichtbarem Sync-Hinweis. Der Testhost startet ohne CloudKit.
- Neue Tagesdetailansicht (`DayDetailView`): Klick auf einen Tag oeffnet ihn jetzt vollstaendig, mit Kennzahlen, bearbeitbarem Tagesfokus, verankerten Wochenzielen, Zeitplan, Aufgaben nach Prioritaet und freien Notizen. `focusNote` und `notes` waren bisher nirgends bearbeitbar.
- Drag-and-Drop von Aufgaben auf einzelne Tage ergaenzt: Sidebar-Tage, iPhone-Wochenstreifen und die Tagesdetailansicht sind Drop-Ziele, jeweils mit Highlight.
- Drop-Behandlung in `TaskDropHandling` zusammengefasst, statt sie an jedem Ziel erneut zu implementieren; Undo-Toast-Mechanik in `TaskUndoCoordinator` ausgelagert.
- Sidebar-Tage zeigen die Anzahl offener Aufgaben.
- Unit-Tests fuer die Zusammenfuehrung doppelter Wochen und Tage, den geraeteunabhaengigen Gewinner und die leere Duplikat-Signatur ergaenzt.
- macOS- und iPhone-Simulator-Builds sowie alle 11 Unit-Tests erfolgreich geprueft.
- Push- und CloudKit-Umgebung in den Entitlements nicht mehr festgeschrieben: Debug und Release teilen dieselbe Datei, die bisher `development` erzwang. Werte kommen jetzt aus `APS_ENVIRONMENT` und `ICLOUD_CONTAINER_ENVIRONMENT` je Konfiguration, in Release also `production` bzw. `Production` — passend zu TestFlight und App Store.
- Fehlendes `com.apple.developer.icloud-container-environment` fuer Distribution-Builds ergaenzt.
- iCloud-Status auf dem iPhone ueberhaupt erst sichtbar gemacht: die Anzeige steckte ausschliesslich im Sidebar-Fuss, den es im iPhone-Zweig nicht gibt. Jetzt Badge in der Navigationsleiste, Antippen zeigt Phase, Detail und Fehlermeldung.
- Statuszeile aus `OverviewViews` nach `CloudSyncStatus` verschoben und in `CloudSyncStatusRow` (Sidebar) sowie `CloudSyncStatusBadge` (iPhone) aufgeteilt.
- CloudKit-Beobachter registrieren sich jetzt vor dem Erzeugen des `ModelContainer`. Vorher entstanden sie erst beim ersten Zugriff einer View, wodurch `setup` und meist der erste Import verpasst wurden und der Status auf "iCloud startet" haengen blieb.
- Erkennung lokaler Aenderungen abgesichert: statt nur auf den undokumentierten Kontextnamen zu pruefen, zaehlt zusaetzlich die Queue (Oberflaeche = Main Queue, CloudKit-Import = Private Queue).
- CloudKit-Fehler werden lesbar aufbereitet (`CloudSyncErrorFormatter`): Fehlercode mit Klartextnamen, Teilfehler aus `partialErrorsByItemID` und verschachtelte Ursachen. Vorher stand dort nur `localizedDescription`, bei CKError meist ohne Aussage.
- Haeufige Ursachen werden benannt, statt nur einen Code zu zeigen — etwa der Hinweis auf ein nur in Development vorhandenes Schema bei `unknownItem`, `invalidArguments` und `serverRejectedRequest`.
- Sync-Ereignisse landen im System-Log (Subsystem = Bundle-ID, Kategorie `CloudSync`, Level `notice`/`error`), damit TestFlight-Builds ohne Debugger in Console.app diagnostizierbar sind.
- Fehler beim Schema-Upload liessen den Hilfscontainer geladen zurueck, weil die Freigabe hinter dem werfenden Aufruf stand. SwiftData oeffnete denselben Store danach ein zweites Mal und CloudKit brach mit 134422 ab. Freigabe laeuft jetzt ueber `defer`.
- `cloudKitDatabase` wird ueberall explizit gesetzt. Der Standard ist `.automatic`, wodurch der lokale Fallback-Store und die In-Memory-Container fuer Tests und Previews CloudKit ungewollt wieder aktiviert haetten.
- CoreData+CloudKit-Fehler werden erkannt: sie kommen als `NSCocoaErrorDomain` (134400, 134406, 134422 …) statt als `CKError`, und die Aussage steckt in `NSLocalizedFailureReason` und `encounteredErrors` — beides wurde vorher verworfen.
- iCloud-Accountstatus wird beim Start und bei `CKAccountChanged` direkt abgefragt. Fehlt der Account, steht das jetzt als "Kein iCloud-Account" da, statt sich hinter einem Core-Data-Fehler zu verstecken.
- Wochenziele koennen geloescht werden (`GoalActions`), erreichbar aus Sidebar-Kontextmenue, Wochenuebersicht und Zieldetail. Zugeordnete Aufgaben bleiben erhalten und verlieren nur ihre Zielzuordnung; der Bestaetigungsdialog nennt die betroffene Anzahl.
- Unit-Tests fuer das Loeschen von Wochenzielen ergaenzt: Aufgaben ueberleben, Verknuepfung wird geloest, andere Ziele bleiben unberuehrt.
- Analyse zu Security, DSGVO, Architektur und Code samt Massnahmenplan in `Analyse_und_Massnahmenplan.md` abgelegt.
- iCloud-Sync auf beiden Plattformen verifiziert lauffaehig.
- Sync-Details zeigen zusaetzlich Accountzustand, CloudKit-Umgebung, Container-Identifier und App-Version. Damit ist am Gerät ablesbar, ob Development oder Production laeuft und welcher Build getestet wird — bei TestFlight-Builds sonst nicht feststellbar.

## 2026-08-01

- App-Branding von Anchor/Anker auf Daivento umgestellt.
- `PRODUCT_NAME`, Bundle-Anzeigename und Bundle-Name auf `Daivento` gesetzt.
- App-Bundle wird als `Daivento.app` gebaut; Test-Host-Pfade wurden darauf angepasst.
- Sichtbare Navigation, Menubar-Beschriftung und Onboarding-Texte auf Daivento bzw. neutrale Formulierungen umgestellt.
- Bundle-ID `com.marcomeisen.Anchor` und iCloud-Container `iCloud.com.marcomeisen.Anchor` bewusst beibehalten, damit bestehende Installationen, Provisioning und CloudKit-Sync stabil bleiben.
- iCloud/CloudKit-Konfiguration in SwiftData aktiviert und Entitlements/Background-Remote-Notification-Konfiguration abgesichert.
- Onboarding auf die laufende Woche ausgerichtet.
- Wochenziel-Erstellung und Aufgabenanlage repariert.
- Wochen- und Monatsnavigation korrigiert, inklusive sauberer Zuordnung von Tagen zu Monaten und Navigation in Folgemonate.
- Schnell-Erfassung aus der App-Oberflaeche in die echte macOS-Systemmenubar verlagert.
- Fehlendes SF-Symbol `anchor` durch eine eigene Glyph-Implementierung ersetzt.
- AppIcon-Set zuerst auf `AppIcon-B-Light` umgestellt.
- AppIcon-Set jetzt vollstaendig aus `Fokusring-B` generiert.
- `FokusringB` als Runtime-Asset angelegt und fuer Systemmenubar sowie sichtbare Logo-Glyphen genutzt.
- Separates `FokusringBMenu`-Template-Asset fuer die macOS-Systemmenubar erstellt, mit transparentem Hintergrund und fuehrenden weissen Ringsegmenten.
- Nicht ausgelieferte Design-/Prompt-Dokumente aus dem App-Bundle ausgeschlossen.
- AppIcon-Warnung durch Entfernen einer unreferenzierten Datei im AppIcon-Set behoben.
- Aufgaben-Bearbeitungsmodus eingefuehrt: Erledigt-Status, Bearbeiten, Verschieben in andere Wochen, Verschieben auf morgen und Loeschen direkt aus Task-Karten, Mini-Tasks und Detailansichten.
- Redundante Erstellungsaktionen fuer Wochenziele und Aufgaben entfernt; Erstellung laeuft jetzt einheitlich ueber Icon-Buttons in der Toolbar mit Hover-Hilfen.
- Mac-Task-Flow gemaess `Daivento_Task_Flow_Mac_Visuals.html` umgesetzt: Hover-Reveal-Aktionen, erweitertes Kontextmenue mit Shortcuts/Untermenues, Shortcut-Hinweisleiste und Drag-and-Drop auf Sidebar-Wochen.
- iPhone-Task-Interaktion gemaess `Daivento_Task_Interaktionskonzept.md` umgesetzt: Leading-Swipe fuer Erledigt/Offen, Trailing-Swipe fuer Verschieben/Loeschen, Long-Press-Kontextmenue mit Preview und Untermenues, Mehrfachauswahl per Toolbar/Checkbox-Long-Press und Glas-Aktionsleiste.
- Rueckgaengig-Toast fuer iPhone-Task-Aktionen mit 4-Sekunden-Fortschritt und exakter Wiederherstellung der urspruenglichen Aufgabenposition ergaenzt.
- Undo-Logik erweitert, damit Duplizieren rueckgaengig die erstellte Kopie entfernt statt sie nur neu zu speichern.
- Erledigte Aufgaben wandern nach dem Abhaken ans Ende der Tagesreihenfolge, passend zur iPhone-Swipe-Spezifikation.
- Task-Aktionen um iPhone-Haptik, Accessibility-Actions, klare destruktive Labels und reduzierte Bewegung bei aktivierter Bedienungshilfe ergaenzt.
- Unit-Tests fuer exakte Task-Undo-Positionierung und Undo von Duplikaten ergaenzt.
- Mac-Task-Flow gemaess Screenshots nachgezogen: Start in der Heute-/Prio-Liste, custom Sidebar-Reihenfolge nach Monat/Woche/Tag, echte Wochen-Navigation aus Sidebar-Zielen, Drop-Ziel mit `← Ziel`-Highlight, Drag-Preview und transparente Ursprungszeile.
- Mac-Schnellverschieben auf Sheet-freien Flow umgestellt: Hover-/Shortcut-Aktion verschiebt direkt in die naechste Woche, weitere Verschiebeziele bleiben im Kontext-Untermenue.
- Mac-Heute-Titel auf `Daivento — Heute` angepasst, passend zu den Task-Flow-Screenshots.
- Neuanlage von Aufgaben und Wochenzielen fuer Folgewochen und Folgemonate ermoeglicht: Erstell-Sheets enthalten jetzt Wochen-/Monatsspruenge, legen fehlende Wochen beim Sichern an und springen danach zur geplanten Woche.
- Wochenanlage zentralisiert und um einen SwiftData-Fetch ergaenzt, damit geplante Folgewochen nicht doppelt entstehen, wenn Query-Updates verzoegert eintreffen.
- Unit-Test fuer Wiederverwendung bereits gespeicherter Wochen bei verzoegerten Query-Listen ergaenzt.
- Tagesauswahl fuer direkte Aufgabenanlage ergaenzt: Klick auf Wochentage in Sidebar, Wochenuebersicht oder Heute-Leiste setzt den Zieltag fuer die naechste neue Aufgabe.
- Drag-and-Drop in der Wochenuebersicht ergaenzt: Mini-Aufgaben koennen direkt zwischen Tageszeilen verschoben werden, inklusive Drop-Highlight und Zieltag-Auswahl.
- iCloud-Sync abgesichert: Debug-Start initialisiert das SwiftData/CloudKit-Schema explizit, die App registriert sich fuer Remote Notifications und die Push-Entitlements fuer macOS/iOS wurden vollstaendig gehalten.
- iCloud-Sync-Status unten in der Sidebar ergaenzt, inklusive CloudKit-Event-Beobachtung, Import-/Export-Status, Fehlerzustand und Hover-Details.
- Jahresuebersicht durch ein cleanes, datenbasiertes Monatsraster fuer iPhone und macOS ersetzt; iPhone-Menubar/Tabbar optisch beruhigt.
- Appname auf Daivento umgestellt: Produktname, Bundle-Anzeigename, Test-Host, sichtbare UI-Texte, Menubar-Accessibility, iCloud-Tooltip, Logo-Komponente und Konzeptdateien aktualisiert.
- Jahresuebersicht auf macOS erreichbar gemacht: Sidebar-Navigation um Heute/Woche/Jahr mit direktem Jahr-Einstieg ergaenzt.
- iCloud-Sync-Status erweitert: lokale SwiftData/CoreData-Saves werden als ausstehender Export angezeigt und nach Timeout als pruefbarer Sync-Hinweis markiert, statt weiter nur auf Aenderungen zu warten.
- macOS- und iPhone-Simulator-Builds erfolgreich geprueft.
- macOS-Unit-Tests erfolgreich geprueft.
- iOS-Unit-Testlauf scheiterte einmal an einem CoreSimulator-Klonfehler fuer `iPhone 17`, nicht an einem Codefehler.
