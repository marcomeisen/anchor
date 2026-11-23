---
name: daivento-build
description: Daivento/Anchor bauen, testen und im Simulator starten — xcodebuild-Kommandos für macOS und iOS, Scheme/Destination, Testlauf, typische Fehler (Xcode-Pfad, CoreSimulator-Klonfehler, CloudKit-Entitlements). Nutzen, sobald "bauen", "build", "kompilieren", "testen", "Simulator", "läuft das noch", "Xcode" o. ä. im Spiel ist oder nach einer Codeänderung verifiziert werden soll.
---

# Bauen & Testen

Xcode-Projekt (kein SPM). `swift build` funktioniert **nicht** — es gibt kein `Package.swift`.

- Projekt: `Anchor.xcodeproj`
- Scheme: `Anchor` (einziges Scheme; auto-generiert, liegt nicht im Repo)
- Produkt: `Daivento.app`
- Targets: `Anchor`, `AnchorTests`, `AnchorUITests`
- Deployment: iOS 26.5 / macOS 26.5, Swift 5, `DEVELOPMENT_TEAM = 877KJ7CGCU`

## Voraussetzung prüfen

```bash
xcode-select -p
```

Zeigt das `/Library/Developer/CommandLineTools`, ist **kein** vollständiges Xcode aktiv und jedes
`xcodebuild` scheitert mit `tool 'xcodebuild' requires Xcode`. Dann:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Liegt in `/Applications` nur `Xcode.appdownload`, läuft der Download noch — dann nicht bauen,
sondern das dem Nutzer melden und die Änderung stattdessen durch Lesen/Tests-am-Papier begründen.

## Kommandos

macOS bauen (schnellster Smoke-Test, da kein Simulator nötig):

```bash
xcodebuild -project Anchor.xcodeproj -scheme Anchor \
  -destination 'platform=macOS' build 2>&1 | tail -40
```

iPhone-Simulator bauen:

```bash
xcodebuild -project Anchor.xcodeproj -scheme Anchor \
  -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | tail -40
```

Verfügbare Ziele auflisten, wenn ein Gerätename nicht passt:

```bash
xcrun simctl list devices available
xcodebuild -project Anchor.xcodeproj -scheme Anchor -showdestinations
```

Unit-Tests (macOS ist die verlässlichere Variante):

```bash
xcodebuild -project Anchor.xcodeproj -scheme Anchor -destination 'platform=macOS' \
  -only-testing:AnchorTests test 2>&1 | grep -E "error:|Test case|TEST "
```

**Der Testlauf braucht eine gültige Signatur.** Der Testhost ist die echte App, und die öffnet
beim Start einen CloudKit-Store. Fehlen die iCloud-Entitlements, bricht CloudKit den Prozess
asynchron ab und der Lauf endet mit `The test runner crashed before establishing connection`.
Ad-hoc-Signieren, Entitlements-Strippen oder Sandbox-Abschalten helfen **nicht** — das ist
ausprobiert. Ohne Apple-ID in Xcode → Settings → Accounts scheitert der Lauf schon am Build
(`No signing certificate "Mac Development" found`).

`CloudSyncConfiguration.isRunningTests` hält CloudKit aus dem Testhost heraus, greift aber erst,
wenn `XCTestConfigurationFilePath` gesetzt ist — verlass dich nicht darauf, dass das einen
unsignierten Lauf rettet.

Einzelnen Test laufen lassen:

```bash
xcodebuild -project Anchor.xcodeproj -scheme Anchor -destination 'platform=macOS' \
  -only-testing:AnchorTests/AnchorTests/testCompletingTaskMovesItToEndOfDayOrder test
```

App auf dem Mac starten:

```bash
open "$(xcodebuild -project Anchor.xcodeproj -scheme Anchor -destination 'platform=macOS' \
  -showBuildSettings 2>/dev/null | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')/Daivento.app"
```

## Regeln

- Nach jeder nicht-trivialen Codeänderung **mindestens macOS bauen**. Die Codebasis ist voller
  `#if os(...)`-Zweige; ein macOS-Build übersieht iOS-Fehler und umgekehrt. Bei Änderungen an
  Dateien mit `#if os(iOS)` zusätzlich den Simulator-Build fahren.
- Änderungen an `TaskActions`, `AnkerCalendar` oder den Modellen → Unit-Tests laufen lassen.
- `xcodebuild`-Output ist sehr lang; immer durch `| tail -N` oder `| grep -E "error:|warning:|Test Case.*failed|BUILD"` filtern.
- Build-Fehler nie "wegkommentieren" oder mit `try?`/`as!` überdecken — die Codebasis benutzt
  bewusst `try?` nur bei SwiftData-Saves.

## Signieren, Archivieren, TestFlight

- Die macOS-Sandbox- und Netzwerk-Berechtigungen kommen aus **Build-Settings**
  (`ENABLE_APP_SANDBOX`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, `ENABLE_USER_SELECTED_FILES`),
  nicht aus [Anchor/Anchor.entitlements](../../../Anchor/Anchor.entitlements). Beide Quellen
  werden beim Signieren zusammengeführt.
- Push- und CloudKit-Umgebung dürfen **nicht** in der Entitlements-Datei festgeschrieben werden:
  Debug und Release teilen sich die Datei. Sie stehen auf `$(APS_ENVIRONMENT)` bzw.
  `$(ICLOUD_CONTAINER_ENVIRONMENT)`, die pro Konfiguration gesetzt sind
  (`development`/`Development` in Debug, `production`/`Production` in Release). TestFlight und
  App Store laufen gegen die Produktions-APNs; ein festes `development` passt dort nicht zum
  Distribution-Profil.
- `aps-environment` ist der iOS-Key, `com.apple.developer.aps-environment` der macOS-Key. Das
  Multiplattform-Target braucht beide.
- Nach Änderungen an Entitlements oder Signing-Settings prüfen:

```bash
xcodebuild -project Anchor.xcodeproj -target Anchor -configuration Release -showBuildSettings \
  | grep -E "APS_ENVIRONMENT|ICLOUD_CONTAINER_ENVIRONMENT|ENABLE_"
plutil -lint Anchor/Anchor.entitlements
```

- Bei Upload-Fehlern die Signatur im Archiv selbst befragen, nicht raten:

```bash
APP="<Archiv>.xcarchive/Products/Applications/Daivento.app"
codesign -dvvv --entitlements :- "$APP"     # Identität, Team, Entitlements
codesign -d -r- "$APP"                      # Designated Requirement
codesign --verify --deep --strict --verbose=2 "$APP"
```

| Symptom | Ursache / Vorgehen |
|---|---|
| `tool 'xcodebuild' requires Xcode` | Command Line Tools aktiv, s. o. `xcode-select -s` |
| `Unable to boot the Simulator` / CoreSimulator-Klonfehler für `iPhone 17` | Umgebungsproblem, **kein** Codefehler. Anderes Gerät wählen oder `xcrun simctl shutdown all && xcrun simctl erase all`. Ist im Changelog schon einmal so aufgetreten. |
| Host-App stürzt beim Testlauf sofort ab (`test runner crashed before establishing connection`) | Ohne iCloud-Entitlements trappt CloudKit **asynchron** in `NSCloudKitMirroringDelegate` und reißt den Prozess mit. Deshalb startet der Testhost über `CloudSyncConfiguration.isRunningTests` ohne CloudKit; tritt es trotzdem auf, `~/Library/Logs/DiagnosticReports/Daivento*.ips` ansehen. |
| Signing-/Provisioning-Fehler | Bundle-ID und iCloud-Container nicht ändern (s. `CLAUDE.md`). Für reine Compile-Checks `CODE_SIGNING_ALLOWED=NO` anhängen. |
| macOS-Sandbox-Berechtigungen | Werden aus Build-Settings generiert, **nicht** aus `Anchor.entitlements` — `ENABLE_APP_SANDBOX`, `ENABLE_OUTGOING_NETWORK_CONNECTIONS`, `ENABLE_USER_SELECTED_FILES`. Fehlt Netzwerk, kommt CloudKit nicht ins Netz. Mit `xcodebuild -showBuildSettings \| grep ENABLE_` prüfen. |
| Warnung zu AppIcon-Set | Assets in `Anchor/Assets.xcassets` prüfen — unreferenzierte Dateien im Set entfernen. |
