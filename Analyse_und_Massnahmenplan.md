# Daivento — Analyse und Maßnahmenplan

**Stand:** 2026-08-04 · **Grundlage:** Arbeitsstand im Working Tree (nicht committet) ·
**Umfang:** Security, DSGVO, Architektur, Code

> **Umsetzungsstand 2026-08-04:** Behoben sind G1, G2, G3, A1, S2, A2, A3, A4, A7, A8, C2, C3,
> C4, C5, C6, N1, N2 sowie C1 soweit ohne Übersetzung möglich. Details je Befund unten unter
> *Behoben*.
>
> Der Neuentwurf *Modernist* (siehe [changelog.md](changelog.md)) hat C2 und N1 nachträglich
> verschärft und dann erledigt: die Tokenschicht ist nicht mehr nur Farbe, sondern auch Schrift,
> Abstand und Icon, und sie wird durch 15 Grep-Schranken in
> [Scripts/design-guard.swift](Scripts/design-guard.swift) gehalten statt durch Disziplin.
>
> Bewusst offen: **A5** (Paket `AnkerKit`) — Entscheidung vom 2026-08-04, siehe dort. **A6**
> (Widgets, Watch, EventKit) ist ausgeklammert. **S1** und **S4** sind nicht angefasst.
> Nicht-Code-Arbeit bleibt: die Datenschutzerklärung (G4) und die Nutrition Labels in
> App Store Connect (G1).

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
| A2 | Architektur | Geschäftslogik in Views | Mittel | **behoben** |
| A3 | Architektur | `OverviewViews.swift` mit 1483 Zeilen | Mittel | **behoben** |
| A4 | Architektur | Navigation ohne `NavigationPath` | Mittel | **behoben** |
| A5 | Architektur | Kein Modul-Schnitt, Widgets/Watch nicht anbindbar | Mittel | bewusst offen |
| A6 | Architektur | Spec-Features fehlen (Widgets, Watch, EventKit) | Mittel | ausgeklammert |
| C2 | Code | 19 hartkodierte Hex-Farben außerhalb `Theme.swift`; keine Tokens für Schrift, Abstand, Icon | Mittel | **behoben** |
| C3 | Code | UI-Tests sind leere Template-Rümpfe | Mittel | **behoben** |
| S3 | Security | `print` mit Fehlerobjekt im Release-Pfad | Niedrig | offen |
| S4 | Security | `privacy: .public` auf freien Fehlertexten | Niedrig | offen |
| G5 | DSGVO | Usage Descriptions fehlen (relevant, sobald EventKit kommt) | Niedrig | offen |
| A7 | Architektur | `CloudSyncStatusCenter` als globaler Singleton | Niedrig | **behoben** |
| A8 | Architektur | Duplikat-Signatur bei jeder `body`-Auswertung | Niedrig | **behoben** |
| C4 | Code | `AnkerCalendar.iso` erzeugt bei jedem Zugriff ein `Calendar` | Niedrig | **behoben** |
| C5 | Code | Datumsformatierung mehrfach dupliziert | Niedrig | **behoben** |
| C6 | Code | Beispieldaten-Logik im Auslieferungspfad | Niedrig | **behoben** |

**Positiv und ausdrücklich festzuhalten:** keine Drittanbieter-Abhängigkeiten, kein Tracking,
kein eigener Netzwerkcode außer CloudKit, App Sandbox und Hardened Runtime aktiv,
Kern-Geschäftslogik (`TaskActions`, `GoalActions`, `StoreMaintenance`, `AnkerCalendar`) ist von
der UI getrennt und durch 34 Unit-Tests plus einen UI-Test des Kernflusses abgedeckt.

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

`AnkerRootView` (damals in `OverviewViews.swift`) verantwortete Navigation, Onboarding-Zustand,
Wochen- und Monatssprünge, Wochenanlage, Beispieldaten-Bereinigung und Zielverwaltung in einem Typ.
Das machte die Logik nur über die UI testbar — und die UI-Tests waren leer (C3).

**Behoben (2026-08-04).** Zwei neue Typen ohne View-Bezug:
[AppNavigation.swift](Anchor/AppNavigation.swift) mit `AnkerNavigationState` (Sprünge,
Suchtreffer, Wiederherstellung, Deep Links) und [WeekPlanning.swift](Anchor/WeekPlanning.swift)
(Wochen und Tage auflösen, Onboarding-Zustand, erstes Wochenziel).
[AnkerRootView.swift](Anchor/AnkerRootView.swift) ist auf Verdrahtung reduziert.

Nebeneffekt, der die Absicht belegt: die acht Navigationsmethoden bestanden alle aus derselben
Dreierfolge *Zustand ändern, Zielwoche anlegen, speichern*. Das ist jetzt eine Methode `move(_:)`,
und die eigentlichen Sprünge sind reine Mutationen auf einem Wertetyp — neun Unit-Tests prüfen sie
direkt, darunter der Sonntagsrand von `contains` und der Platzhalter im Onboarding.

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

**Behoben (2026-08-04).** Aufgeteilt entlang der Views, private Hilfs-Views bei ihrem Nutzer:

| vorher | nachher |
|---|---|
| `OverviewViews.swift` (1483) | `AnkerRootView.swift` (388), `SidebarView.swift` (615), `WeekOverviewView.swift` (315), `YearOverviewView.swift` (222) |
| `DetailAndCaptureViews.swift` (994) | `TaskCaptureSheets.swift` (568), `GoalDetailView.swift` (158), `WeeklyReviewView.swift` (110), `OnboardingView.swift` (173) |
| `TaskEditing.swift` (768) | `TaskActions.swift` (355), `TaskEditorSheets.swift` (418) |

Die Trennung von `TaskEditing.swift` stand nicht im Plan, ist aber derselbe Fall: die
Mutationsschicht und zwei Blätter hatten nichts miteinander zu tun. `AnkerComponents.swift` (978)
bleibt bewusst zusammen — das ist eine Komponentenbibliothek, keine Sammeldatei.

### A4 — Navigation ohne `NavigationPath` · Mittel

Die Navigation läuft über das Enum `AppDestination` plus separate `@State`-Variablen für Woche und
Tag. Folgen: kein Deep-Linking, keine State-Restoration, kein Zurück-Stack. Zusätzlich ist das Enum
inkonsistent — `.goal(UUID)` trägt eine Nutzlast, `.day` bewusst nicht, weil der Tag aus
`selectedDayDate` folgt.

**Behoben (2026-08-04),** allerdings nicht wörtlich wie im Plan formuliert. Die drei genannten
Folgen sind weg:

- **State-Restoration:** `AnkerNavigationState` ist `Codable` und liegt in `@SceneStorage`. Die App
  startet wieder in der Woche und auf dem Tag, an denen zuletzt gearbeitet wurde; auf dem Mac je
  Fenster.
- **Deep-Linking:** `daivento://today`, `//week/2026-08-03`, `//day/2026-08-05`, `//goal/<UUID>`,
  `//year`, `//review`, registriert über `CFBundleURLTypes`. Datumsangaben bewusst in ISO — ein
  Link muss unabhängig von der Regionseinstellung des Empfängers funktionieren. Eine nicht
  verstandene URL lässt den Zustand unangetastet, statt den Nutzer irgendwohin zu befördern.
- **Zurück-Stack:** auf dem iPhone liegen `.day` und `.goal` jetzt auf einem echten
  `NavigationStack(path:)`; die Zurück-Gestik funktioniert, wo es vorher nur einen
  Schließen-Knopf gab.

**Was ich nicht gemacht habe:** die Split-Ansicht auf einen `NavigationPath` umstellen. Die
Detailspalte einer `NavigationSplitView` ist auswahl- und nicht stapelgetrieben; ein Pfad wäre dort
kein Gewinn, sondern ein Fremdkörper. Der Stapel wird stattdessen aus demselben Zustand abgeleitet
(`isPushed`), sodass Tab-Auswahl, Zurück und Wiederherstellung eine Quelle haben. Die genannte
Inkonsistenz des Enums bleibt bestehen und ist dokumentiert — `.day` ohne Nutzlast ist Absicht,
damit das Zusammenführen doppelter Tage die Navigation nicht ins Leere laufen lässt.

### A5 — Kein Modul-Schnitt · Mittel

Alles liegt in einem Multiplattform-Target. Der ursprüngliche Spec
([Anchor_prompt.md](Anchor_prompt.md), Abschnitt 4) sah ein lokales Paket `AnkerKit` für
Datenmodell, Logik und Theme vor. Ohne dieses Paket lassen sich Widget- und Watch-Extensions später
nicht anbinden, ohne Code zu duplizieren.

**Bewusst offen (Entscheidung 2026-08-04).** Der Nutzen des Pakets ist die Anbindung von Widgets
und Watch — also A6, und A6 ist ausgeklammert. Übrig blieben die Kosten: rund 15 Dateien umziehen,
jede in Logik- und View-Teil trennen, etwa 250 `public`-Annotationen, `project.pbxproj` von Hand um
die Paketreferenz erweitern. Dazu ein Restrisiko am Datenbestand: die `@Model`-Klassen hießen danach
`AnkerKit.Goal` statt `Daivento.Goal`. Entity-Name und CloudKit-Recordtyp (`CD_Goal`) bleiben zwar
gleich, aber ein Paket mit genau einem Abnehmer rechtfertigt diesen Eingriff nicht.

Die Vorbereitung ist trotzdem erledigt: Modell und Logik liegen nach A2 und A3 in eigenen Dateien
ohne View-Bezug (`Models`, `TaskActions`, `GoalEditing`, `WeekPlanning`, `AppNavigation`,
`StoreMaintenance`, `DataPortability`, `AppSettings`, `Persistence`, `CalendarLogic`, `Theme`).
Damit ist A5 später ein Umzug und keine Entflechtung.

*Falls es doch ansteht:* eine Store-Datei mit dem heutigen Modulschnitt sichern und nach dem Umzug
öffnen. Nur so ist belegt statt angenommen, dass bestehende Daten weiter gelesen werden.

### A6 — Fehlende Spec-Features · Mittel

Gegen die Abnahmekriterien in [Anchor_prompt.md](Anchor_prompt.md) und
[Anker_Coding_Prompt_v2_Migration.md](Anchor/Anker_Coding_Prompt_v2_Migration.md) fehlen: Home- und
Lock-Screen-Widgets, Watch-App, EventKit-Anbindung für die Zeitplanspalte, Lokalisierung. Das ist
bekannter Restumfang, keine Regression — hier nur zur Vollständigkeit erfasst.

**Ausgeklammert (Entscheidung 2026-08-04).** Die Lokalisierungsinfrastruktur ist über C1 inzwischen
vorhanden; Widgets, Watch und EventKit bleiben Restumfang und setzen A5 voraus.

### A7 — Globaler Singleton · Niedrig

`CloudSyncStatusCenter.shared` hält globalen, `@MainActor`-isolierten Zustand und registriert im
Initialisierer Notification-Beobachter. Für Tests nicht ersetzbar.

**Behoben (2026-08-04).** Drei Änderungen: Der Initialisierer ist nebenwirkungsfrei, die Beobachter
entstehen erst in `startObserving()` (mehrfach aufrufbar). Die Beobachter melden über `[weak self]`
an ihre eigene Instanz statt an `.shared` — vorher hätte eine eingesetzte Ersatzinstanz weiter das
Singleton bedient. Und `StoreMaintenance` berichtet über das Protokoll `StoreMaintenanceReporting`
statt direkt an `.shared`, sodass ein Test einen stillen Empfänger übergeben kann. In den Views ist
die Statuszentrale ein injizierbarer Parameter mit `.shared` als Vorbelegung.

Der Singleton selbst bleibt — er ist die Klammer um vier prozessweite Notification-Beobachter, und
ihn aufzulösen hieße, dieselbe Klammer an anderer Stelle neu zu bauen.

### A8 — Rechenaufwand im View-Body · Niedrig

`StoreMaintenance.duplicateSignature(for: weeks)` wird als `.task(id:)`-Schlüssel bei **jeder**
Auswertung von `AnkerRootView.body` berechnet und gruppiert dabei alle Wochen und Tage. Bei einem
Jahr Nutzung sind das rund 364 Tage pro Durchlauf. Aktuell unkritisch, wächst aber linear.

**Behoben (2026-08-04),** und zwar nicht durch Zwischenspeichern, sondern durch den richtigen
Schlüssel: `CloudSyncStatusCenter` zählt jetzt eingegangene CloudKit-Importe, und `.task(id:)` hängt
an diesem Zähler. Das ist nicht nur billiger, es trifft die Absicht genauer — Duplikate entstehen
ausschließlich dadurch, dass ein Import eine Woche einspielt, die lokal schon existiert. Die
Signatur ist damit entbehrlich und entfernt; `duplicateWeekKeys` und `duplicateDayKeys` bleiben und
sind weiter getestet.

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

**Behoben (2026-08-04).** Alle 19 Vorkommen sind Tokens in `Theme.swift`: `destructive`,
`indigoGradientLight/Soft/Deep`, `selectedRow`, `bannerIndigo/Brass/Success`,
`textBody/Chip/Task`. Außerhalb von `Theme.swift` gibt es keinen Hex-Wert mehr.

**Nachtrag zum Neuentwurf (2026-08-04).** Der Befund war zu eng gefasst: nicht nur Farben liefen am
Token-System vorbei, sondern auch 191 rohe `.font(.system(size:))`, 218 rohe Abstandszahlen und 74
SF-Symbol-Namen — es gab für Schrift, Abstand und Icon gar keine Tokenschicht, an der etwas hätte
vorbeilaufen können. Alle drei gibt es jetzt (`AnkerType`, `AnkerSpacing`, `AnkerIcon`), und
`Scripts/design-guard.swift` prüft sie. Dabei kam ein Fehler heraus, den der Befund nicht sah:
`NSColor(calibratedRed:)` statt `srgbRed:` verschob **jede** Farbe der App gegenüber ihrem Hexwert.

Ein Wert ist dabei bewusst *geändert* und nicht nur umbenannt: `#E0392E` (Papierkorb im
Hover-Reveal, Mehrfachauswahl-Löschen) steht in keinem Referenzdokument. Das Designsystem definiert
genau ein Rot — `--prio-a:#D93327`, ausdrücklich kontrastkorrigiert. Der Ausreißer ist darauf
zusammengeführt. Die übrigen Werte sind unverändert übernommen; wo eine Dunkelvariante fehlt, fehlt
sie weiterhin, weil ich sie nicht aus dem Referenzdokument belegen kann und nicht erfinden wollte.

### C3 — UI-Tests ohne Inhalt · Mittel

`AnchorUITests` enthält drei Funktionen, davon zwei generierte Rümpfe und einen Launch-Test. Der im
Spec geforderte Flow „Aufgabe erstellen → an Ziel verankern → Fortschritt aktualisiert sich" ist
nicht abgedeckt. Die 13 Unit-Tests decken die Logikschicht gut ab, aber keinen einzigen UI-Pfad.

**Behoben (2026-08-04).** `testCreateTaskAnchorToGoalAndSeeProgress` läuft den geforderten Flow
vollständig: Onboarding mit erstem Wochenziel, Aufgabe über das Erfassungsblatt anlegen und dabei
an das Ziel verankern, über die Sidebar zurück zum Ziel, Aufgabe erledigen, Zähler und
Fortschrittsring prüfen (0 → 100 Prozent).

Dafür war Infrastruktur nötig, die vorher fehlte: `UITestMode` (`-DaiventoUITest`) startet mit
leerem In-Memory-Store, abgeschaltetem iCloud und zurückgesetzten Einstellungen. **Ohne das liefen
UI-Tests gegen den echten Store und den echten iCloud-Account** — `XCTestConfigurationFilePath` ist
im App-Prozess eines UI-Tests nicht gesetzt, und `@AppStorage` überlebt Läufe. Dazu kamen
Accessibility-Kennungen für Kennzahlen, Zielpille und Aufgabenkarte; die Kennzahlen sind dabei
über `accessibilityElement(children: .ignore)` zusammengefasst, was VoiceOver ohnehin verbessert
(vorher „1" und „AUFGABEN" als zwei getrennte Elemente).

Der Test läuft auf macOS. Das Erledigen geht über das Kontextmenü der Karte, weil die Karte für
VoiceOver ein zusammengefasstes Element ist und das innere Kästchen deshalb nicht einzeln
adressierbar — die Alternative wäre gewesen, die Accessibility-Struktur für die Testbarkeit zu
verschlechtern.

### C4 — `Calendar`-Erzeugung pro Zugriff · Niedrig

`AnkerCalendar.iso` ist eine berechnete `static var`
([CalendarLogic.swift:4](Anchor/CalendarLogic.swift#L4)) und erzeugt bei jedem Aufruf ein neues
`Calendar`-Objekt. Sie wird in Schleifen und Sortierprädikaten verwendet.

**Behoben (2026-08-04).** `static let`. Damit ist auch `TimeZone.current` einmal pro Prozess
festgeschrieben — gewollt, weil dieselbe Woche innerhalb einer Sitzung nicht ihre Grenzen wechseln
soll. Reist der Nutzer über eine Zeitzonengrenze, gilt die neue Zone ab dem nächsten Start;
`StoreMaintenance` rechnet ohnehin bewusst mit den ISO-Feldern statt mit `monday`.

### C5 — Doppelte Datumsformatierung · Niedrig

`shortDate`, `dayLabel` und Varianten existieren mehrfach in `TaskEditing`, `OverviewViews`,
`DayDetailView` und `DetailAndCaptureViews` mit jeweils eigener, leicht abweichender Implementierung.

**Behoben (2026-08-04).** `AnkerDateFormat` in [CalendarLogic.swift](Anchor/CalendarLogic.swift)
hält alle zwölf Formate; 50 Aufrufstellen und acht lokale Wrapper sind darauf umgestellt, `.formatted(.dateTime…)`
kommt außerhalb dieser Datei nicht mehr vor. Jede Ersetzung ist gegen das ursprüngliche Format
geprüft — eine Abweichung ist dabei aufgefallen und zurückgesetzt (das Datum im Zielkopf war
„Mo 03.08.", nicht „03.08.2026").

### C6 — Beispieldaten-Logik im Auslieferungspfad · Niedrig

`SampleData.isReferenceWeek` und `AnkerRootView.removeReferenceDataIfNeeded()` erkennen und löschen
Beispieldaten zur Laufzeit im Produktivcode. Das ist Migrationsbehelf aus der Entwicklung, der bei
jedem Start läuft und Nutzerdaten löschen kann, wenn die Erkennung je falsch greift.

**Behoben (2026-08-04).** Beide entfernt. `SampleData.insertReferenceWeek` bleibt und wird nur noch
von `PreviewContainer` und den Tests aufgerufen. Die Erkennung hätte eine echte Woche mit vier
gleichnamigen Zielen in Kalenderwoche 1/2026 getroffen — unwahrscheinlich, aber der Preis dafür
wäre gelöschte Nutzerarbeit gewesen.

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
| 3.1 | Lokales Paket `AnkerKit` für Modell, Logik und Theme | A5, A6 | L | **zurückgestellt** — Begründung unter A5 |
| 3.2 | ~~`AnkerRootView` entflechten~~ **erledigt** (`AnkerNavigationState`, `WeekPlanning`) | A2 | M |
| 3.3 | ~~`OverviewViews.swift` und `DetailAndCaptureViews.swift` aufteilen~~ **erledigt**, `TaskEditing.swift` mit | A3 | M |
| 3.4 | ~~Deep-Linking und State-Restoration~~ **erledigt**; `NavigationPath` nur auf dem iPhone, siehe A4 | A4 | L |
| 3.5 | ~~`CloudSyncStatusCenter` hinter ein Protokoll legen~~ **erledigt** | A7 | S |
| 3.6 | ~~Duplikat-Prüfung aus dem `body` holen~~ **erledigt** — über einen Import-Zähler statt Zwischenspeichern | A8 | S |

### Phase 4 — Qualität und Vollständigkeit

| # | Maßnahme | Behebt | Aufwand |
|---|---|---|---|
| 4.1 | ~~String Catalog einführen, Texte extrahieren, hartkodiertes `de_DE` entfernen~~ **erledigt**; offen bleiben die Übersetzungen in weitere Sprachen | C1 | L |
| 4.2 | ~~UI-Test für „Aufgabe erstellen → verankern → Fortschritt"~~ **erledigt** | C3 | M |
| 4.3 | ~~Hartkodierte Farben in `Theme.swift` überführen~~ **erledigt** | C2 | S |
| 4.4 | ~~Datumsformatierung zentralisieren~~ **erledigt** (`AnkerDateFormat`) | C5 | S |
| 4.5 | ~~`AnkerCalendar.iso` als `static let`~~ **erledigt** | C4 | S |
| 4.6 | ~~Beispieldaten-Bereinigung entfernen~~ **erledigt** | C6 | S |

### Phase 3 und 4 — Stand

Aus Phase 3 sind 3.2 bis 3.6 erledigt, 3.1 ist zurückgestellt. Aus Phase 4 sind 4.1 bis 4.6
erledigt, bei 4.1 ohne die Übersetzungen selbst. Offen aus Phase 2: 2.1 bis 2.3 (S1, S4).

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

**Nach der Umsetzung vom 2026-08-04** sind Phase 1 vollständig, aus Phase 0 der technische Teil und
aus den Phasen 3 und 4 alles außer dem Paket `AnkerKit` abgearbeitet. Was vor der nächsten
Einreichung noch fehlt, ist ausschließlich Nicht-Code-Arbeit: die Datenschutzerklärung (0.2, G4) und
die Nutrition Labels in App Store Connect (0.3). Der Bildschirm *Daten und Datenschutz* beschreibt
bereits, was gespeichert wird und wer es empfängt — dieser Text taugt als Grundlage für die
Erklärung, ersetzt sie aber nicht.

Sinnvoll als Nächstes: **Phase 2** (S1, S4) ist unabhängig und klein. `AnkerKit` erst, wenn Widgets
oder Watch anstehen.

---

## Nebenbefunde aus der Umsetzung

Beim Umbau aufgefallen, nicht Teil der ursprünglichen Analyse und **nicht behoben**:

### N1 — Die iPhone-Wischgesten laufen nie · Mittel

`TaskCard` definiert `.swipeActions` für Erledigen, Löschen und Verschieben
([AnkerComponents.swift](Anchor/AnkerComponents.swift)). `swipeActions` wirkt aber nur innerhalb
einer `List` oder `Form` — im Projekt gibt es **keine einzige** `List`, alle Aufgabenlisten sind
`VStack` in einem `ScrollView`. Die Gesten sind damit toter Code.

Das betrifft direkt das [Interaktionskonzept](Daivento_Task_Interaktionskonzept.md), das Swipe als
Kerninteraktion auf dem iPhone vorsieht. Behebung heißt entweder auf `List` umstellen (greift ins
Layout ein) oder die Gesten selbst implementieren.

**Behoben (2026-08-04)** im Rahmen des Neuentwurfs. Die iPhone-Aufgabenlisten sind echte `List`s mit
`.listStyle(.plain)` — der Eingriff ins Layout war ohnehin fällig, weil der neue Entwurf die
Kartenoptik durch Zeilen mit 1px-Trennlinie ersetzt. Swipe, Kontextmenü, Mehrfachauswahl und Undo
sind damit vollständig, ohne eigene Gestenimplementierung.

### N2 — Tippfehler in einem sichtbaren Text · Niedrig

„Wochenziele kannst du danach direkt **fuer** diese Woche erstellen" in
[TaskCaptureSheets.swift](Anchor/TaskCaptureSheets.swift). Nicht korrigiert, weil eine Änderung den
Schlüssel im String Catalog mitzieht.

**Behoben (2026-08-04).** Es waren drei Stellen, nicht eine: dazu „Das Datenmodell konnte nicht
fuer CloudKit aufgebaut werden" und „Store nicht fuer CloudKit konfiguriert" — beides sichtbare
Fehlermeldungen. Der String Catalog ist mitgezogen; Deutsch ist die Quellsprache, es gab keine
Übersetzung zu retten.
