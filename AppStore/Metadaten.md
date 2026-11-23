# App Store Connect: Angaben für Anchorit 1.0

Alle Felder in der Reihenfolge, in der App Store Connect sie abfragt. Zeichenbegrenzungen in
Klammern; die Texte halten sie ein. Primärsprache: **Deutsch**.

## App-Informationen

| Feld | Wert |
|---|---|
| Name (30) | `Anchorit` |
| Untertitel (30) | `Ein Blatt pro Woche` |
| Bundle-ID | `com.marcomeisen.Anchor` (absichtlich unverändert) |
| SKU | `anchorit-1` |
| Primäre Kategorie | Produktivität |
| Sekundäre Kategorie | Lifestyle |
| Inhaltsrechte | Enthält keine Inhalte Dritter (Lucide-Icons sind ISC-lizenziert und mitgeliefert) |
| Altersfreigabe | Alle Fragen mit „Nein“ bzw. „Keine“ → **4+** |
| Preis | festlegen (z. B. kostenlos), Verfügbarkeit: alle Länder oder DACH |

## Version 1.0 — Texte

**Werbetext (170)**

```
Höchstens vier Dinge, die diese Woche zählen — jedes mit einem Satz, warum. Aufgaben hängen daran. Am Sonntag sagst du ehrlich, was gehalten hat.
```

**Beschreibung (4000)**

```
Anchorit ist ein Wochenplaner, der weniger will. Ein Blatt pro Woche, höchstens vier Anker — die Dinge, die diese Woche wirklich zählen. Jeder Anker bekommt einen Satz, warum. Jede Aufgabe gehört zu einem Anker oder steht ausdrücklich ohne.

SETZEN
Am Montag fragt Anchorit: Was zählt diese Woche? Du setzt bis zu vier Anker und übernimmst auf Wunsch, was letzte Woche offen blieb.

ERLEDIGEN
Heute zeigt die Aufgaben des Tages und darüber deine Anker. Jeder Haken füllt einen Punkt beim passenden Anker — so siehst du, worauf dein Tag einzahlt. Neue Aufgaben schreibst du einfach in die Erfassungszeile: „#2“ hängt sie an Anker 2, „fr“ legt sie auf Freitag.

DIE WOCHE IM BLICK
Die Woche gibt es in zwei Ansichten mit denselben Daten: nach Tag oder nach Anker. Auf Mac und iPad als Raster, in das du Aufgaben ziehst — auf einen Tag, an einen Anker oder in eine andere Woche.

PRÜFEN
Am Sonntag beantwortest du pro Anker: gehalten, teilweise oder nicht. Anchorit rechnet das nicht aus — du sagst es. Offene Aufgaben nimmst du mit in die nächste Woche oder lässt sie los.

ABLEGEN
Das Archiv zeigt dein Jahr als Raster aus Wochen, deine längste Serie und den Anker, der immer wieder liegen bleibt.

RUHIG GESTALTET
Tinte auf hellem Grau, weiße Karten, eine einzige Farbe für „erledigt“ und „heute“. Hell und dunkel, mit Dynamic Type und VoiceOver.

DEINE DATEN GEHÖREN DIR
Keine Anmeldung, keine Werbung, kein Tracking, keine Analyse. Deine Daten liegen auf deinem Gerät und, wenn du willst, in deiner privaten iCloud — so bleiben iPhone, iPad und Mac gleich. Du kannst jederzeit alles als Datei exportieren oder vollständig löschen.

Für iPhone, iPad und Mac.
```

**Schlüsselwörter (100, kommagetrennt, ohne Leerzeichen)**

```
wochenplaner,wochenziele,ziele,fokus,aufgaben,todo,planer,wochenrückblick,produktivität,gewohnheit
```

**Neuerungen (nur ab Version 1.1 nötig)**

```
Erste Version.
```

| Feld | Wert |
|---|---|
| Support-URL | https://marcomeisen.github.io/anchor/support.html |
| Marketing-URL | https://marcomeisen.github.io/anchor/ (optional) |
| Datenschutz-URL | https://marcomeisen.github.io/anchor/datenschutz.html |
| Copyright | `2026 [Vor- und Nachname]` |

## App-Datenschutz („Nutrition Label")

Muss zu `Anchor/PrivacyInfo.xcprivacy` passen.

1. **Erheben Sie oder Drittanbieter Daten?** → Ja
2. Datentyp: **Benutzerinhalte → Sonstige Benutzerinhalte**
   - Verwendung: **App-Funktionalität**
   - Mit der Identität verknüpft: **Nein**
   - Für Tracking verwendet: **Nein**
3. Alle anderen Datentypen: nicht erhoben.
4. Tracking: **Nein** (kein ATT-Dialog).

Ergebnis im Store: „Nicht mit dir verknüpfte Daten: Benutzerinhalte".

## App-Prüfung (Review-Informationen)

| Feld | Wert |
|---|---|
| Anmeldung erforderlich | Nein (Haken bei „Anmeldung erforderlich“ entfernen) |
| Kontakt | Vorname, Nachname, Telefon, E-Mail |

**Notizen für die Prüfung**

```
Anchorit needs no account. On first launch the app asks whether to sync via the user's private iCloud database (CloudKit) or keep data on this device only; both paths work. To try the main flow: choose either option, enter up to four weekly anchors, then type a task into the capture bar at the bottom ("#1" links it to anchor 1, "fr" schedules it for Friday). The weekly review is available from the Week tab ("Rückblick"). Settings → "Daten und Datenschutz" offers a full JSON export and a complete deletion (device and iCloud). The app makes no network requests other than CloudKit.
```

## Export-Compliance

Beantwortet über `ITSAppUsesNonExemptEncryption = false` in der Info.plist. Keine Rückfrage.

## Bildschirmfotos

Pflichtgrößen (je 3 bis 10 Bilder, PNG oder JPEG, ohne Alphakanal):

| Gerät | Größe (Hochformat) | Hinweis |
|---|---|---|
| iPhone 6,9" | 1320 × 2868 | genügt für alle iPhones |
| iPad 13" | 2064 × 2752 | genügt für alle iPads |
| Mac | 2880 × 1800 | 16:10, auch 1440 × 900 erlaubt |

iPhone und iPad sind erzeugt (je 6 Bilder, JPEG ohne Alphakanal) und liegen unter
[AppStore/Screenshots/](Screenshots/). Demodaten über `-AnchoritUITest -AnchoritDemoData`, siehe
Skill `anchorit-build`.

**Mac selbst aufnehmen** (das Fenster ließ sich hier nicht skalieren):

1. Debug-Build mit Demodaten starten:
   `open -n <Anchorit.app> --args -AnchoritUITest -AnchoritDemoData -AnchoritTab week`
2. Fenster auf den **eingebauten** Retina-Bildschirm ziehen und auf 1440 × 900 Punkte bringen
   (ergibt 2880 × 1800 Pixel).
3. ⇧⌘5 → „Ausgewähltes Fenster aufnehmen“, in den Optionen „Schatten“ ausschalten
   (oder ⇧⌘4, Leertaste, ⌥ beim Klicken halten).
4. Bereiche: Raster, Nach Anker, Heute, Archiv; `-AnchoritTab review` zeigt den Rückblick.

Vorgeschlagene Reihenfolge und Bildunterschriften:

1. **Heute** — „Was du heute tust, zahlt auf etwas ein.“
2. **Woche nach Tag** — „Die ganze Woche auf einem Blatt.“
3. **Woche nach Anker** — „Vier Anker. Jede Aufgabe hat ihren Platz.“
4. **Setzen** — „Montag: Was zählt diese Woche?“
5. **Rückblick** — „Sonntag: ehrlich sagen, was gehalten hat.“
6. **Archiv** — „Dein Jahr in Wochen.“

## Vor dem Einreichen

- [ ] CloudKit-Schema nach Production deployt ([CloudKit_Schema_Anleitung.md](../CloudKit_Schema_Anleitung.md))
- [ ] Platzhalter in `docs/datenschutz.html` und `docs/support.html` ausgefüllt (Name, Anschrift, E-Mail)
- [ ] GitHub Pages aktiviert: Repo → Settings → Pages → Branch `main`, Ordner `/docs`
- [ ] Beide URLs im Browser geprüft
- [ ] `MARKETING_VERSION` 1.0, Build-Nummer höher als der letzte TestFlight-Build (zuletzt 15)
- [ ] Archiv für iOS **und** macOS hochgeladen (eine App, zwei Plattformen)
- [ ] TestFlight-Build auf zwei Geräten: Anker auf einem anlegen, auf dem anderen sehen
- [ ] App-Name in App Store Connect von „Daivento“ auf „Anchorit“ geändert
