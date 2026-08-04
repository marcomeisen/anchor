# Changelog

## 2026-08-04

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
