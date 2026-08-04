# Changelog

## 2026-08-04

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
