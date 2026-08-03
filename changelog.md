# Changelog

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
