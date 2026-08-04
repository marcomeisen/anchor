# Daivento — Analyse und Maßnahmenplan

**Stand:** 2026-08-04 · **Grundlage:** Arbeitsstand im Working Tree (nicht committet) ·
**Umfang:** Security, DSGVO, Architektur, Code

> **Umsetzungsstand 2026-08-04:** Die fünf schwersten Befunde sind behoben — G1, G2, G3, A1, S2
> und, soweit ohne Übersetzung möglich, C1. Details je Befund unten unter *Behoben*. Offen sind
> alle übrigen Befunde sowie bei C1 die eigentlichen Übersetzungen und bei G1 die Nutrition
> Labels in App Store Connect.

---

## Methodik und Grenzen

Geprüft wurde der Quellstand unter [Anchor/](Anchor/), die Projektkonfiguration in
`Anchor.xcodeproj/project.pbxproj`, [Anchor/Anchor.entitlements](Anchor/Anchor.entitlements) sowie
die Testziele. Befunde sind mit Datei und Zeile belegt; Zählungen stammen aus dem Repository.

**Nicht prüfbar und daher nicht bewertet:**

- App-Store-Connect-Einstellungen, insbesondere die Privacy Nutrition Labels
- Vorhandensein und Inhalt einer veröffentlichten Datenschutzerklärung
- Apples Verarbeitung in iCloud (Auftragsverarbeitung, Rechenzentrumsstandorte)
- Laufzeitverhalten auf echten Geräten außerhalb der hier ausgeführten Builds und Tests

Wo eine Bewertung von diesen Punkten abhängt, ist das ausdrücklich vermerkt.

---

## Zusammenfassung

| ID | Bereich | Befund | Schwere | Status |
|---|---|---|---|---|
| G1 | DSGVO | `PrivacyInfo.xcprivacy` fehlt vollständig | **Hoch** | **behoben** |
| G2 | DSGVO | Keine Datenexport-Funktion (Art. 15, 20) | **Hoch** | **behoben** |
| G3 | DSGVO | Keine Funktion zum vollständigen Löschen (Art. 17) | **Hoch** | **behoben** |
| A1 | Architektur | 27× `try? save()` — Speicherfehler werden verschluckt | **Hoch** | **behoben** |
| C1 | Code | Keine Lokalisierung, 28× hartkodiertes `de_DE` | **Hoch** | **teilweise** |
| S1 | Security | Keine Zugriffssperre für Inhalte, keine erhöhte Data Protection | Mittel | offen |
| S2 | Security | Automatische Datensatzlöschung ohne Protokoll | Mittel | **behoben** |
| G4 | DSGVO | Keine Datenschutzerklärung im Projekt, kein Link in der App | Mittel | offen |
| A2 | Architektur | Geschäftslogik in Views | Mittel | offen |
| A3 | Architektur | `OverviewViews.swift` mit 1483 Zeilen | Mittel | offen |
| A4 | Architektur | Navigation ohne `NavigationPath` | Mittel | offen |
| A5 | Architektur | Kein Modul-Schnitt, Widgets/Watch nicht anbindbar | Mittel | offen |
| A6 | Architektur | Spec-Features fehlen (Widgets, Watch, EventKit) | Mittel | offen |
| C2 | Code | 19 hartkodierte Hex-Farben außerhalb `Theme.swift` | Mittel | offen |
| C3 | Code | UI-Tests sind leere Template-Rümpfe | Mittel | offen |
| S3 | Security | `print` mit Fehlerobjekt im Release-Pfad | Niedrig | offen |
| S4 | Security | `privacy: .public` auf freien Fehlertexten | Niedrig | offen |
| G5 | DSGVO | Usage Descriptions fehlen (relevant, sobald EventKit kommt) | Niedrig | offen |
| A7 | Architektur | `CloudSyncStatusCenter` als globaler Singleton | Niedrig | offen |
| A8 | Architektur | Duplikat-Signatur bei jeder `body`-Auswertung | Niedrig | offen |
| C4 | Code | `AnkerCalendar.iso` erzeugt bei jedem Zugriff ein `Calendar` | Niedrig | offen |
| C5 | Code | Datumsformatierung mehrfach dupliziert | Niedrig | offen |
| C6 | Code | Beispieldaten-Logik im Auslieferungspfad | Niedrig | offen |

**Positiv und ausdrücklich festzuhalten:** keine Drittanbieter-Abhängigkeiten, kein Tracking,
kein eigener Netzwerkcode außer CloudKit, App Sandbox und Hardened Runtime aktiv,
Kern-Geschäftslogik (`TaskActions`, `GoalActions`, `StoreMaintenance`, `AnkerCalendar`) ist von
der UI getrennt und durch 20 Unit-Tests abgedeckt.

---

## 1. Security

### S1 — Keine Zugriffssperre, Standard-Data-Protection · Mittel

Aufgabentitel, Tagesnotizen und Zielnamen sind Freitextfelder, in denen Nutzer erfahrungsgemäß
Persönliches ablegen. Die App setzt keine erhöhte Data-Protection-Klasse und bietet keine Sperre
per Face ID / Touch ID.

Auf iOS gilt damit der Standard `NSFileProtectionCompleteUntilFirstUserAuthentication`: Nach dem
ersten Entsperren nach einem Neustart ist der Store lesbar, auch wenn das Gerät danach gesperrt
wird. Auf macOS schützt nur FileVault.

**Empfehlung:** `NSFileProtectionComplete` für den Store prüfen (Achtung: verhindert Zugriff im
gesperrten Zustand und damit Hintergrund-Sync — Abwägung nötig) und eine optionale
App-Sperre über `LocalAuthentication` anbieten.

### S2 — Automatische Datensatzlöschung ohne Protokoll · Mittel

[Anchor/StoreMaintenance.swift](Anchor/StoreMaintenance.swift) löscht nach jedem iCloud-Import
selbstständig doppelte `Week`- und `Day`-Datensätze und hängt deren Kinder um. Das ist fachlich
richtig und getestet, läuft aber vollautomatisch, ohne Protokoll und ohne Rückholmöglichkeit. Ein
Fehler in der Zusammenführungslogik bedeutet stillen Datenverlust.

**Empfehlung:** Jede Zusammenführung über `cloudSyncLog` protokollieren (Anzahl, betroffene
Kalenderwochen, Gewinner-ID) und die Anzahl entfernter Datensätze im Sync-Status sichtbar machen.

**Behoben (2026-08-04).** `StoreMaintenance.merge(weeks:modelContext:)` liefert jetzt einen
`MergeReport` mit entfernten Wochen, entfernten Tagen und betroffenen Kalenderwochen. Vor jeder
Löschung wird protokolliert, welcher Datensatz mit wie vielen Kindern in welchen Gewinner aufgeht;
zum Abschluss steht die Gesamtzahl im Log. `CloudSyncStatusCenter.noteMaintenance` summiert das
über die Sitzung, die Sidebar zeigt eine zusätzliche Zeile und die Sync-Details eine Zeile
*Aufgeräumt*. `normalize` bleibt als schmale Hülle erhalten. Zwei Tests decken Protokoll und
Leerfall ab.

### S3 — `print` mit Fehlerobjekt im Release-Pfad · Niedrig

[Anchor/AnchorApp.swift:174](Anchor/AnchorApp.swift#L174) schreibt beim Store-Fallback
`print("CloudKit store unavailable, falling back to local store: \(error)")`. Diese Zeile liegt
**außerhalb** des `#if DEBUG`-Blocks und geht damit in Auslieferungsbuilds nach stdout — inklusive
Store-Pfaden. Die beiden übrigen `print`-Aufrufe (Zeilen 163, 165) sind korrekt DEBUG-gebunden.

**Empfehlung:** Durch `cloudSyncLog.error` ersetzen, damit die Ausgabe der Redaktionslogik des
Unified Log unterliegt.

### S4 — `privacy: .public` auf freien Fehlertexten · Niedrig

An sieben Stellen wird mit `privacy: .public` geloggt. Bei Aufzählungswerten und Statusnamen ist
das richtig und beabsichtigt. Bei `CloudSyncErrorFormatter.describe(error)`
([CloudSyncStatus.swift:183, 238, 624](Anchor/CloudSyncStatus.swift)) handelt es sich jedoch um
freien Text, der aus `NSLocalizedFailureReason` und CloudKit-Teilfehlern zusammengesetzt wird. Dort
können Record- und Zonennamen auftauchen.

Das Risiko ist gering — CoreData-Recordnamen sind `CD_`-Präfixe plus UUIDs, keine Nutzerinhalte —
aber die Zusicherung ist nicht garantiert.

**Empfehlung:** Fehlercodes weiter `.public`, freien Text auf die Standardredaktion umstellen.

### Nicht beanstandet

- Keine Drittanbieter-Abhängigkeiten, kein Paketmanager → keine Supply-Chain-Fläche
- Kein eigener Netzwerkcode; Transport ausschließlich über CloudKit
- App Sandbox, Hardened Runtime und seit Kurzem korrekt gesetzte Netzwerkberechtigung
- `ENABLE_USER_SELECTED_FILES` seit dem Datenexport `readwrite` statt `readonly` — nötig, damit
  der Speichern-Dialog auf dem Mac in die gewählte Datei schreiben darf. Powerbox begrenzt den
  Zugriff auf genau diese Datei; ein Vollzugriff auf das Dateisystem ist das nicht.
- Keine Secrets, Keys oder Tokens im Repository

---

## 2. DSGVO

Verarbeitet werden Aufgabentitel, Wochenzielnamen, Tagesnotizen, Fokusnotizen, Zeitblöcke und
Kalender-Referenzen. Das sind personenbezogene Daten im Sinne von Art. 4 Nr. 1. Rechtsgrundlage ist
die Vertragserfüllung gegenüber dem Nutzer (Art. 6 Abs. 1 lit. b); ein Consent-Banner ist mangels
Tracking nicht erforderlich. Empfänger ist ausschließlich Apple als Auftragsverarbeiter über die
private CloudKit-Datenbank.

### G1 — `PrivacyInfo.xcprivacy` fehlt · Hoch

Im gesamten Repository existiert kein Privacy Manifest. Apple verlangt es seit Frühjahr 2024 für
App-Store-Einreichungen; es deklariert erhobene Datentypen und die Verwendungsgründe für
Required-Reason-APIs. **Das ist ein Einreichungsblocker**, unabhängig von der DSGVO-Bewertung.

**Umsetzung:** `Anchor/PrivacyInfo.xcprivacy` anlegen mit
`NSPrivacyTracking = false`, leerer `NSPrivacyTrackingDomains`, den Datentypen
„Other User Content" (Zweck: App-Funktionalität, nicht mit Identität verknüpft, kein Tracking) und
den tatsächlich genutzten Required-Reason-APIs — hier mindestens `NSPrivacyAccessedAPICategoryUserDefaults`
wegen `@AppStorage` in [OverviewViews.swift](Anchor/OverviewViews.swift), Grund `CA92.1`.

**Behoben (2026-08-04).** [Anchor/PrivacyInfo.xcprivacy](Anchor/PrivacyInfo.xcprivacy) angelegt,
genau mit dem oben beschriebenen Inhalt. Im gebauten Bundle unter `Contents/Resources/` verifiziert.
*Weiter offen:* die Privacy Nutrition Labels in App Store Connect — die liegen außerhalb des
Repositorys und sind von hier aus weder setzbar noch prüfbar.

### G2 — Keine Datenexport-Funktion · Hoch

Es gibt keinen Weg, die eigenen Daten aus der App zu exportieren. Damit sind Auskunft (Art. 15) und
Datenübertragbarkeit (Art. 20) nicht bedienbar.

**Umsetzung:** Export aller Wochen, Ziele, Aufgaben, Zeitblöcke und Notizen als JSON über
`ShareLink` bzw. `NSSavePanel`. Der Aufwand ist gering, weil das Datenmodell klein und vollständig
über `AnkerSchema.models` beschrieben ist.

**Behoben (2026-08-04).** [Anchor/DataPortability.swift](Anchor/DataPortability.swift) baut ein
vollständiges Abbild, [Anchor/DataPrivacyView.swift](Anchor/DataPrivacyView.swift) sichert es über
`fileExporter` — ein Codepfad für beide Plattformen statt `ShareLink` und `NSSavePanel` getrennt.

Zwei Entscheidungen sind erwähnenswert: Der Export enthält einen Abschnitt `unassigned` mit
Datensätzen ohne Woche oder Tag. Die sind über die Oberfläche nicht erreichbar, gehören dem Nutzer
aber trotzdem und müssen in einer Auskunft nach Art. 15 auftauchen. Und die JSON-Ausgabe ist
`prettyPrinted` mit ISO-8601-Datumsangaben, damit sie ohne Zusatzsoftware lesbar bleibt — Art. 20
verlangt ein gängiges, maschinenlesbares Format, nicht das kompakteste.

### G3 — Kein vollständiges Löschen · Hoch

Art. 17 verlangt eine Löschmöglichkeit. Das Löschen der App entfernt den lokalen Store, **nicht
aber die Daten in der privaten CloudKit-Datenbank** — die bleiben und werden bei Neuinstallation
zurückgespielt. Ein Nutzer hat damit keine erreichbare Löschfunktion.

**Umsetzung:** „Alle Daten löschen" in den Einstellungen: alle Objekte aus dem `ModelContext`
löschen, speichern, den Export der Löschung durch CloudKit abwarten und den Abschluss im
Sync-Status anzeigen. Zwingend mit Bestätigungsdialog und klarer Konsequenzbenennung.

**Behoben (2026-08-04).** `DataPortability.deleteAllData(in:)` löscht jedes Objekt einzeln statt den
Store wegzuwerfen — nur so entsteht pro Datensatz eine Löschung, die CloudKit in die private
Datenbank exportiert. Der Bestätigungsdialog nennt die betroffenen Anzahlen, und der Bildschirm sagt
ausdrücklich, dass das Löschen der App dafür nicht reicht. `resetStoredPreferences` räumt den
Onboarding-Zustand mit ab, sonst landete der Nutzer in einer leeren App, die sich für eingerichtet
hält.

### G4 — Keine Datenschutzerklärung · Mittel

Im Projekt liegt kein Datenschutztext, und die App verlinkt keinen. Für die App-Store-Einreichung
ist eine URL verpflichtend; Art. 13 verlangt die Information zum Zeitpunkt der Erhebung.

**Umsetzung:** Kurze Erklärung verfassen (Verantwortlicher, Datenarten, Zweck, Rechtsgrundlage,
Apple als Auftragsverarbeiter, Speicherdauer, Betroffenenrechte, Kontakt), veröffentlichen und in
der App unter „Mehr" verlinken. *Hinweis: Rechtsverbindlichkeit ist anwaltlich zu prüfen; die
technische Beschreibung kann aus dieser Analyse übernommen werden.*

### G5 — Usage Descriptions fehlen · Niedrig

Es ist keine einzige `NS...UsageDescription` gesetzt. Aktuell ist das korrekt, weil EventKit nicht
verwendet wird — der einzige Treffer ist das Modellfeld `TimeBlock.linkedEventIdentifier`
([Models.swift:151](Anchor/Models.swift#L151)), das auf eine geplante Anbindung hindeutet. Sobald
Kalenderzugriff dazukommt, ist `NSCalendarsUsageDescription` Pflicht, sonst beendet das System die
App beim ersten Zugriff.

### G7 — Keine Aussage zur Speicherdauer · Niedrig

Daten werden unbegrenzt aufbewahrt. Für eine persönliche Planungs-App ist das vertretbar und vom
Nutzer gewollt, gehört aber in die Datenschutzerklärung.

### Positiv

Datenminimierung ist gewahrt — es werden keine Geräte-IDs, Standorte, Kontakte oder Nutzungsstatistiken
erhoben. Es gibt keine Analytics, keine Werbe-SDKs und keine Drittempfänger. Das ist eine
ungewöhnlich saubere Ausgangslage.

---

## 3. Architektur

### A1 — Speicherfehler werden systematisch verschluckt · Hoch

27 Vorkommen von `try? modelContext.save()` bzw. `try? context.save()` im Produktivcode. Schlägt ein
Speichervorgang fehl — Speicherplatz, Migrationskonflikt, beschädigter Store —, bemerkt weder App
noch Nutzer etwas. Die Aufgabe verschwindet beim nächsten Start.

Das ist der schwerwiegendste architektonische Befund, weil er direkt Datenverlust bedeutet und
über den gesamten Code verteilt ist.

**Umsetzung:** Zentrale Hilfsfunktion, die den Fehler protokolliert und an eine
`ErrorPresenter`-Instanz meldet, die ihn in der Oberfläche anzeigt. Danach die 27 Aufrufe
umstellen. `TaskActions` und `GoalActions` sind die richtigen Angriffspunkte, weil dort die meisten
Speichervorgänge zusammenlaufen.

**Behoben (2026-08-04).** [Anchor/Persistence.swift](Anchor/Persistence.swift) bringt
`ModelContext.saveChanges()`, das protokolliert, an `PersistenceFailureCenter` meldet und
zurückgibt, ob gespeichert wurde. Alle 27 Aufrufe sind umgestellt (26 in den Views und Aktionen,
einer in `StoreMaintenance`). `ContentView` zeigt den Fehler genau einmal an der Wurzel, mit der
Möglichkeit, erneut zu sichern.

Im Log sind nur Operation und Fehlercode `.public`; der freie Text kann Feldinhalte enthalten und
unterliegt der Standardredaktion — dieselbe Trennung, die S4 für den Sync-Pfad noch offen hat.

### A2 — Geschäftslogik in Views · Mittel

`AnkerRootView` ([OverviewViews.swift](Anchor/OverviewViews.swift)) verantwortet Navigation,
Onboarding-Zustand, Wochen- und Monatssprünge, Wochenanlage, Beispieldaten-Bereinigung und
Zielverwaltung in einem Typ. Das macht die Logik nur über die UI testbar — und die UI-Tests sind
leer (C3).

### A3 — Dateizuschnitt · Mittel

| Datei | Zeilen |
|---|---|
| `OverviewViews.swift` | 1483 |
| `AnkerComponents.swift` | 977 |
| `DetailAndCaptureViews.swift` | 875 |
| `TaskEditing.swift` | 774 |
| `CloudSyncStatus.swift` | 672 |

`OverviewViews.swift` enthält vier Top-Level-Views plus acht private Hilfs-Views. Sammeldateien wie
`DetailAndCaptureViews.swift` bündeln fachlich Unverwandtes.

### A4 — Navigation ohne `NavigationPath` · Mittel

Die Navigation läuft über das Enum `AppDestination` plus separate `@State`-Variablen für Woche und
Tag. Folgen: kein Deep-Linking, keine State-Restoration, kein Zurück-Stack. Zusätzlich ist das Enum
inkonsistent — `.goal(UUID)` trägt eine Nutzlast, `.day` bewusst nicht, weil der Tag aus
`selectedDayDate` folgt.

### A5 — Kein Modul-Schnitt · Mittel

Alles liegt in einem Multiplattform-Target. Der ursprüngliche Spec
([Anchor_prompt.md](Anchor_prompt.md), Abschnitt 4) sah ein lokales Paket `AnkerKit` für
Datenmodell, Logik und Theme vor. Ohne dieses Paket lassen sich Widget- und Watch-Extensions später
nicht anbinden, ohne Code zu duplizieren.

### A6 — Fehlende Spec-Features · Mittel

Gegen die Abnahmekriterien in [Anchor_prompt.md](Anchor_prompt.md) und
[Anker_Coding_Prompt_v2_Migration.md](Anchor/Anker_Coding_Prompt_v2_Migration.md) fehlen: Home- und
Lock-Screen-Widgets, Watch-App, EventKit-Anbindung für die Zeitplanspalte, Lokalisierung. Das ist
bekannter Restumfang, keine Regression — hier nur zur Vollständigkeit erfasst.

### A7 — Globaler Singleton · Niedrig

`CloudSyncStatusCenter.shared` hält globalen, `@MainActor`-isolierten Zustand und registriert im
Initialisierer Notification-Beobachter. Für Tests nicht ersetzbar.

### A8 — Rechenaufwand im View-Body · Niedrig

`StoreMaintenance.duplicateSignature(for: weeks)` wird als `.task(id:)`-Schlüssel bei **jeder**
Auswertung von `AnkerRootView.body` berechnet und gruppiert dabei alle Wochen und Tage. Bei einem
Jahr Nutzung sind das rund 364 Tage pro Durchlauf. Aktuell unkritisch, wächst aber linear.

---

## 4. Code

### C1 — Keine Lokalisierung · Hoch

Kein String Catalog (`.xcstrings`), keine `.strings`-Dateien. Alle sichtbaren Texte stehen inline
im Code, und `Locale(identifier: "de_DE")` ist **28-mal** hartkodiert. Damit ignoriert die App die
Systemsprache und die regionalen Datumseinstellungen des Nutzers — auch für deutschsprachige Nutzer
mit abweichender Region ein Fehlverhalten, nicht nur ein fehlendes Feature.

Der Spec verlangt einen String Catalog „von Anfang an" ([Anchor_prompt.md](Anchor_prompt.md),
Abschnitt 6).

**Teilweise behoben (2026-08-04).** Das eigentliche Fehlverhalten ist weg: alle 28 hartkodierten
`Locale(identifier: "de_DE")` sind entfernt, Datumsangaben folgen jetzt `Locale.current`. Dazu ist
[Anchor/Localizable.xcstrings](Anchor/Localizable.xcstrings) angelegt (Quellsprache Deutsch, 115
extrahierte Texte) und die Projektsprache von `en` auf `de` umgestellt — im gebauten Bundle als
`CFBundleDevelopmentRegion = de` verifiziert. Erst dadurch löst `Locale.current` zu Deutsch mit der
Region des Nutzers auf statt zur vollen Systemsprache.

Die zwei `de_DE` in [AnchorTests/AnchorTests.swift](AnchorTests/AnchorTests.swift) bleiben absichtlich
stehen: ein Test, der das erwartete Format prüft, muss die Locale festnageln, sonst hängt sein
Ergebnis an der Maschine.

*Weiter offen:* die Übersetzungen selbst. Der Katalog hat Deutsch als Quellsprache und keine zweite
Sprache — das ist bewusst so, weil die Projektvorgabe deutsche UI-Texte verlangt. Solange keine
weitere Sprache dazukommt, erzeugt der Katalog keine `.lproj`-Tabellen, und die Texte kommen aus den
Schlüsseln. Die Infrastruktur steht damit, die Lokalisierung als Feature nicht.

### C2 — Farben am Token-System vorbei · Mittel

19 hartkodierte `Color(hex: "#…")` außerhalb von `Theme.swift` und außerhalb der legitimen
Verwendung für nutzerdefinierte Zielfarben (`goal.colorHex`). Betroffen sind unter anderem das
Rot destruktiver Aktionen (`#D93327`) und Verlaufsfarben. Das unterläuft die Dark-Mode- und
Kontraststrategie des Designsystems.

### C3 — UI-Tests ohne Inhalt · Mittel

`AnchorUITests` enthält drei Funktionen, davon zwei generierte Rümpfe und einen Launch-Test. Der im
Spec geforderte Flow „Aufgabe erstellen → an Ziel verankern → Fortschritt aktualisiert sich" ist
nicht abgedeckt. Die 13 Unit-Tests decken die Logikschicht gut ab, aber keinen einzigen UI-Pfad.

### C4 — `Calendar`-Erzeugung pro Zugriff · Niedrig

`AnkerCalendar.iso` ist eine berechnete `static var`
([CalendarLogic.swift:4](Anchor/CalendarLogic.swift#L4)) und erzeugt bei jedem Aufruf ein neues
`Calendar`-Objekt. Sie wird in Schleifen und Sortierprädikaten verwendet.

### C5 — Doppelte Datumsformatierung · Niedrig

`shortDate`, `dayLabel` und Varianten existieren mehrfach in `TaskEditing`, `OverviewViews`,
`DayDetailView` und `DetailAndCaptureViews` mit jeweils eigener, leicht abweichender Implementierung.

### C6 — Beispieldaten-Logik im Auslieferungspfad · Niedrig

`SampleData.isReferenceWeek` und `AnkerRootView.removeReferenceDataIfNeeded()` erkennen und löschen
Beispieldaten zur Laufzeit im Produktivcode. Das ist Migrationsbehelf aus der Entwicklung, der bei
jedem Start läuft und Nutzerdaten löschen kann, wenn die Erkennung je falsch greift.

---

## 5. Maßnahmenplan

Aufwände als grobe Einordnung: **S** ≈ unter einem halben Tag, **M** ≈ ein bis zwei Tage,
**L** ≈ mehr als zwei Tage.

### Phase 0 — Vor der nächsten App-Store-Einreichung

Ohne diese Punkte ist die Einreichung entweder blockiert oder rechtlich angreifbar.

| # | Maßnahme | Behebt | Aufwand |
|---|---|---|---|
| 0.1 | ~~`PrivacyInfo.xcprivacy` anlegen und Datentypen deklarieren~~ **erledigt** | G1 | S |
| 0.2 | Datenschutzerklärung verfassen, veröffentlichen, in der App verlinken | G4 | M |
| 0.3 | Privacy Nutrition Labels in App Store Connect ausfüllen | G1 | S |
| 0.4 | `print` im Release-Pfad durch `cloudSyncLog.error` ersetzen | S3 | S |

### Phase 1 — Datenintegrität und Betroffenenrechte

Höchste fachliche Priorität: A1 bedeutet unbemerkten Datenverlust, G2/G3 sind gesetzliche Pflichten.

| # | Maßnahme | Behebt | Aufwand |
|---|---|---|---|
| 1.1 | ~~Zentrales `save()` mit Fehlerbehandlung, 27 Aufrufe umstellen, Fehler in der UI anzeigen~~ **erledigt** | A1 | M |
| 1.2 | ~~Datenexport als JSON~~ **erledigt** (über `fileExporter` statt getrennter Pfade) | G2 | M |
| 1.3 | ~~„Alle Daten löschen" inklusive CloudKit-Abgleich und Bestätigung~~ **erledigt** | G3 | M |
| 1.4 | ~~Zusammenführungen in `StoreMaintenance` protokollieren und im Sync-Status ausweisen~~ **erledigt** | S2 | S |

**Reihenfolge:** 1.1 zuerst — Export und Löschung schreiben beide in den Store und profitieren
unmittelbar von belastbarer Fehlerbehandlung.

### Phase 2 — Sicherheitshärtung

| # | Maßnahme | Behebt | Aufwand |
|---|---|---|---|
| 2.1 | Optionale App-Sperre über `LocalAuthentication` | S1 | M |
| 2.2 | Data-Protection-Klasse bewerten und entscheiden (Zielkonflikt mit Hintergrund-Sync dokumentieren) | S1 | S |
| 2.3 | Logging-Redaktion: Codes `.public`, freie Fehlertexte privat | S4 | S |

### Phase 3 — Architektur

Kein Selbstzweck: 3.1 ist die Voraussetzung für Widgets und Watch aus dem ursprünglichen Spec.

| # | Maßnahme | Behebt | Aufwand |
|---|---|---|---|
| 3.1 | Lokales Paket `AnkerKit` für Modell, Logik und Theme | A5, A6 | L |
| 3.2 | `AnkerRootView` entflechten: Navigation, Onboarding und Wochenverwaltung trennen | A2 | M |
| 3.3 | `OverviewViews.swift` und `DetailAndCaptureViews.swift` nach Views aufteilen | A3 | M |
| 3.4 | Navigation auf `NavigationPath` umstellen, Deep-Linking und State-Restoration ermöglichen | A4 | L |
| 3.5 | `CloudSyncStatusCenter` hinter ein Protokoll legen | A7 | S |
| 3.6 | Duplikat-Signatur zwischenspeichern statt pro `body` berechnen | A8 | S |

### Phase 4 — Qualität und Vollständigkeit

| # | Maßnahme | Behebt | Aufwand |
|---|---|---|---|
| 4.1 | ~~String Catalog einführen, Texte extrahieren, hartkodiertes `de_DE` entfernen~~ **erledigt**; offen bleiben die Übersetzungen in weitere Sprachen | C1 | L |
| 4.2 | UI-Test für „Aufgabe erstellen → verankern → Fortschritt" | C3 | M |
| 4.3 | Hartkodierte Farben in `Theme.swift` überführen | C2 | S |
| 4.4 | Datumsformatierung zentralisieren | C5 | S |
| 4.5 | `AnkerCalendar.iso` als `static let` zwischenspeichern | C4 | S |
| 4.6 | Beispieldaten-Bereinigung nach einer Übergangsfrist entfernen | C6 | S |

### Phase 5 — Restumfang aus dem Spec

Widgets, Watch-App und EventKit-Anbindung (A6). Setzt Phase 3.1 voraus. Bei EventKit ist
`NSCalendarsUsageDescription` zwingend mitzuliefern (G5), und das Privacy Manifest aus 0.1 muss um
den Kalenderzugriff ergänzt werden.

---

## Empfohlene Reihenfolge

Phase 0 vor der nächsten Einreichung. Phase 1 direkt danach — A1 ist der einzige Befund, der
laufend Nutzerdaten gefährdet. Phase 2 ist unabhängig und kann parallel laufen. Phase 3 lohnt sich
erst, wenn Widgets oder Watch tatsächlich anstehen; ohne diesen Anlass ist 3.1 verfrühte
Verallgemeinerung. Phase 4.1 sollte vor jeder Veröffentlichung außerhalb des deutschsprachigen
Raums stehen.

**Nach der Umsetzung vom 2026-08-04** ist Phase 1 vollständig abgearbeitet und aus Phase 0 der
technische Teil. Was vor der nächsten Einreichung noch fehlt, ist ausschließlich Nicht-Code-Arbeit:
die Datenschutzerklärung (0.2, G4) und die Nutrition Labels in App Store Connect (0.3). Der
Bildschirm *Daten und Datenschutz* beschreibt bereits, was gespeichert wird und wer es empfängt —
dieser Text taugt als Grundlage für die Erklärung, ersetzt sie aber nicht.
