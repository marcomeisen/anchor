# CloudKit-Schema nach Production bringen

Diese Anleitung ist für jede Modelländerung gedacht. Der aktuelle Anlass ist „Blatt"
(2026-11-23), das zwei Felder neu einführt.

**Warum das nötig ist:** Xcode-Builds (Debug) schreiben in die CloudKit-Umgebung **Development**.
TestFlight- und App-Store-Builds (Release) schreiben in **Production**. In Development legt CloudKit
fehlende Felder selbst an. In Production ist das Schema **schreibgeschützt**: Was dort nicht
deployt ist, existiert nicht, und der Sync des TestFlight-Builds scheitert. Das ist das bekannte
Bild „läuft in Xcode, tot in TestFlight".

## Was sich diesmal ändert

| Record-Typ | Neues Feld | Typ | Herkunft |
|---|---|---|---|
| `CD_Goal` | `CD_why` | String | `Goal.why`: der Warum-Satz eines Ankers |
| `CD_Goal` | `CD_verdictRaw` | String | `Goal.verdictRaw`: gehalten / teilweise / nicht |

- Beide Felder sind optional und additiv. Ältere App-Versionen ignorieren sie.
- Die geänderten Löschregeln (`.cascade` → `.nullify`) sind **kein** Teil des CloudKit-Schemas. Sie
  wirken nur lokal und brauchen keinen Deploy.
- `NSPersistentCloudKitContainer` stellt jedem Namen `CD_` voran. In der Konsole heißen die Felder
  also `CD_why` und `CD_verdictRaw`.

## Voraussetzungen

- [ ] Der Mac ist in **Systemeinstellungen → Apple-Account** mit einer Apple-ID angemeldet, und
      iCloud Drive ist eingeschaltet.
- [ ] Xcode kann signieren: **Xcode → Settings → Accounts** mit dem Team `877KJ7CGCU`.
      Erscheint beim Bauen `errSecInternalComponent`, ist der Anmeldeschlüsselbund gesperrt.
      Entsperren in der Schlüsselbundverwaltung oder einmal in Xcode bauen und den Zugriff auf
      den Schlüssel mit „Immer erlauben" bestätigen.
- [ ] Zugang zur [CloudKit Console](https://icloud.developer.apple.com) mit einer Rolle, die
      Schemas deployen darf (Admin oder App Manager).

## Schritt 1: Das Schema nach Development schreiben

Das Initialisieren läuft nur auf Anforderung, nur im Debug-Build und nur bei eingeschaltetem
iCloud-Sync (nicht im UI-Testmodus).

**In Xcode:**

1. Scheme `Anchor` auswählen, Ziel **My Mac**.
2. **Product → Scheme → Edit Scheme… → Run → Arguments → Arguments Passed On Launch.**
3. Den Eintrag `-AnchoritInitializeCloudKitSchema` **anhaken**. Er steht schon im geteilten Scheme,
   ist aber standardmäßig aus. Der **Bindestrich am Anfang gehört dazu**: ohne ihn erkennt die App
   das Argument nicht, und es passiert stillschweigend nichts.
4. **Run** (⌘R). Der Start dauert etwas länger, weil für jede Entität Beispieldatensätze
   angelegt und wieder gelöscht werden.
5. In der Xcode-Konsole muss `CloudKit schema initialized.` erscheinen.
   Steht dort `CloudKit schema initialization failed: …`, siehe Fehlerbilder unten.
6. App beenden und das Argument **wieder abhaken**. Sonst läuft die Initialisierung bei jedem
   Start, und das Scheme reicht es auch an die Tests weiter.

**Alternativ im Terminal** (signierter Debug-Build):

```bash
xcodebuild -project Anchor.xcodeproj -scheme Anchor -destination 'platform=macOS' build
APP="$(xcodebuild -project Anchor.xcodeproj -scheme Anchor -destination 'platform=macOS' \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2; exit}')/Anchorit.app"
"$APP/Contents/MacOS/Anchorit" -AnchoritInitializeCloudKitSchema
```

## Schritt 2: In Development nachsehen

1. [CloudKit Console](https://icloud.developer.apple.com) → **CloudKit Database** → Container
   `iCloud.com.marcomeisen.Anchor`.
2. Oben die Umgebung **Development** wählen.
3. **Schema → Record Types → `CD_Goal`.**
4. Prüfen, dass `CD_why` und `CD_verdictRaw` mit dem Typ **String** dastehen.

Fehlen sie, hat Schritt 1 nicht gegriffen. Meist war der Build nicht signiert, oder das Argument
fehlte.

## Schritt 3: Nach Production deployen

1. In der Console, weiter in **Development**: **Deploy Schema Changes…** (Schaltfläche oben
   rechts im Schema-Bereich).
2. Die Übersicht zeigt, was sich gegenüber Production ändert. **Erwartet sind genau die zwei
   neuen Felder an `CD_Goal`.** Steht dort mehr, zum Beispiel ein Record-Typ aus einem Experiment,
   jetzt abbrechen: Was einmal in Production ist, lässt sich nicht mehr entfernen.
3. **Deploy** bestätigen.

## Schritt 4: In Production prüfen

1. Umgebung auf **Production** umschalten.
2. **Schema → Record Types → `CD_Goal`**: Beide Felder sind da.
3. Erst danach den TestFlight-Build hochladen bzw. freigeben.

## Reihenfolge, die nicht vertauscht werden darf

```
Schema initialisieren (Dev) → prüfen (Dev) → deployen → prüfen (Prod) → TestFlight-Build freigeben
```

Kommt ein Release-Build vor dem Deploy auf ein Gerät, scheitern dort Exporte von Ankern mit
Warum-Satz oder Rückblickantwort. Die App arbeitet lokal weiter, und die Sync-Anzeige meldet nach
etwa zwei Minuten „Sync prüfen". Nach dem Deploy holt CloudKit den Export von selbst nach. Es geht
nichts verloren, aber bis dahin sind die Geräte nicht abgeglichen.

## Fehlerbilder

| Symptom | Ursache und Abhilfe |
|---|---|
| `CloudKit schema initialization failed` mit `CKErrorDomain` 9 (*not authenticated*) | Am Mac ist kein iCloud-Account angemeldet, oder iCloud Drive ist aus. |
| `… failed` mit 134422 (*another instance … actively syncing*) | Eine zweite Anchorit-Instanz läuft, etwa die TestFlight-App. Alle beenden, neu starten. |
| Absturz kurz nach dem Start ohne Swift-Stack | Unsignierter Build ohne iCloud-Entitlements. Mit Team signieren (siehe Voraussetzungen). |
| `errSecInternalComponent` beim Bauen | Der Schlüsselbund ist gesperrt bzw. Xcode darf den Signaturschlüssel nicht lesen, siehe Voraussetzungen. |
| TestFlight synct nicht, Xcode-Build schon | Schema nicht deployt, oder du vergleichst einen Debug-Build (Development) mit einem TestFlight-Build (Production). Diese beiden sehen sich **nie**. |
| Felder in Development da, in Production nicht | Schritt 3 wurde nicht bestätigt, oder es wurde in der falschen Umgebung geschaut. |

Diagnose im TestFlight-Build: **Console.app** → Gerät wählen → nach Subsystem
`com.marcomeisen.Anchor`, Kategorie `CloudSync` filtern. Fehler stehen dort aufgelöst mit
CloudKit-Code und Teilfehlern.

## Checkliste zum Abhaken

- [ ] Mac mit iCloud angemeldet, Xcode signiert
- [ ] Debug-Build mit `-AnchoritInitializeCloudKitSchema` gestartet, `CloudKit schema initialized.` gesehen
- [ ] Argument wieder abgehakt
- [ ] Development: `CD_Goal.CD_why` und `CD_Goal.CD_verdictRaw` vorhanden (String)
- [ ] Deploy-Übersicht zeigt nur diese zwei Felder, deployt
- [ ] Production: beide Felder vorhanden
- [ ] Erst jetzt den TestFlight-Build freigegeben
- [ ] Auf zwei Geräten mit dem TestFlight-Build: Warum-Satz auf einem setzen, auf dem anderen nach dem nächsten Abgleich sehen
