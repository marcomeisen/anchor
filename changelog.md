# Changelog

## 2026-08-01

- App-Branding von Anchor/Anker auf Fyndara umgestellt.
- `PRODUCT_NAME`, Bundle-Anzeigename und Bundle-Name auf `Fyndara` gesetzt.
- App-Bundle wird als `Fyndara.app` gebaut; Test-Host-Pfade wurden darauf angepasst.
- Sichtbare Navigation, Menubar-Beschriftung und Onboarding-Texte auf Fyndara bzw. neutrale Formulierungen umgestellt.
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
- Mac-Task-Flow gemaess `Fyndara_Task_Flow_Mac_Visuals.html` umgesetzt: Hover-Reveal-Aktionen, erweitertes Kontextmenue mit Shortcuts/Untermenues, Shortcut-Hinweisleiste und Drag-and-Drop auf Sidebar-Wochen.
- iPhone-Task-Interaktion gemaess `Fyndara_Task_Interaktionskonzept.md` umgesetzt: Leading-Swipe fuer Erledigt/Offen, Trailing-Swipe fuer Verschieben/Loeschen, Long-Press-Kontextmenue mit Preview und Untermenues, Mehrfachauswahl per Toolbar/Checkbox-Long-Press und Glas-Aktionsleiste.
- Rueckgaengig-Toast fuer iPhone-Task-Aktionen mit 4-Sekunden-Fortschritt und exakter Wiederherstellung der urspruenglichen Aufgabenposition ergaenzt.
- Undo-Logik erweitert, damit Duplizieren rueckgaengig die erstellte Kopie entfernt statt sie nur neu zu speichern.
- Erledigte Aufgaben wandern nach dem Abhaken ans Ende der Tagesreihenfolge, passend zur iPhone-Swipe-Spezifikation.
- Task-Aktionen um iPhone-Haptik, Accessibility-Actions, klare destruktive Labels und reduzierte Bewegung bei aktivierter Bedienungshilfe ergaenzt.
- Unit-Tests fuer exakte Task-Undo-Positionierung und Undo von Duplikaten ergaenzt.
- macOS- und iPhone-Simulator-Builds erfolgreich geprueft.
- macOS-Unit-Tests erfolgreich geprueft.
- iOS-Unit-Testlauf scheiterte einmal an einem CoreSimulator-Klonfehler fuer `iPhone 17`, nicht an einem Codefehler.
