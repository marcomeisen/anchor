---
name: daivento-design-system
description: Designsystem "Lot" von Daivento — AnkerColor/AnkerType/AnkerRadius/AnkerSpacing-Tokens, warme Neutralen, Bernstein und Rost, die vier Flächen-Idiome, Glas nur für Chrome, Höhe statt Rahmen, Arbeitsfläche gegen Ritual, WCAG-korrigierte Farbwerte und deutsche UI-Texte. Nutzen bei jeder UI-Arbeit: neue View oder Komponente, Farben, Abstände, Radien, Dark Mode, Glas/Material, Schatten, Kontrast, Icons, Beschriftungen.
---

# Lot

Verbindliche visuelle Referenz: Claude-Design-Projekt *New Daivento direction*
(`d96eecb8-cc9f-407d-aadd-80ad4697cf6a`), Dateien **Lot Designsystem.dc.html** (das System) und
**Daivento in Lot.dc.html** (die Screens, Tokentabelle, Zustände, Bewegung). Nicht im Repo — die
Umsetzung ist in [Scripts/design-guard.swift](../../../Scripts/design-guard.swift) und
[AnchorTests/AnkerThemeTests.swift](../../../AnchorTests/AnkerThemeTests.swift) festgehalten.

Bei Unsicherheit über einen Wert: dort nachsehen, nicht schätzen.

> Ein Lot misst Tiefe. Das System auch: Nähe entsteht durch **Material und Höhe**, nicht durch
> Rahmen. Warm statt klinisch, zwei Modi, eine Sprache.

## Zwei Modi

| | Arbeitsfläche | Ritual |
|---|---|---|
| Wann | sechs Tage die Woche | Wochenrückblick |
| Schrift | San Francisco | Instrument Serif |
| Dichte | 1,0 | 1,4 (`AnkerSpacing.ritual(_:)`) |
| Chrome | Glas | keins |
| Modus | hell **und** dunkel | immer dunkel (`AnkerColor.Ritual`) |

Der Ritual-Modus lebt in genau einer Datei ([WeeklyReviewView.swift](../../../Anchor/WeeklyReviewView.swift));
`design-guard` hält Serif-Tokens und `AnkerColor.Ritual` dort fest.

## Farbe — drei Rollen, kein Ampelsystem

**Bernstein** ist jetzt/aktiv/primär und nie Warnung. **Rost** ist ausschließlich Rückstand und
Übertrag — nie Marke, nie „aktiv", nie ein Knopf, höchstens zweimal pro Bildschirm. Sonst tragen
warme Neutralen alles. Kein Grün, kein Gelb, kein Blau.

```swift
AnkerColor.ink / .inkSecond / .inkMuted / .inkTertiary   // Schrift, absteigend
AnkerColor.faint            // KEINE Schriftfarbe — Platzhalter, leeres Feld
AnkerColor.ground / .surface / .card                     // Grund → eingelassen → Karte
AnkerColor.cardDivider / .divider                        // Haarlinie in Karte / Abschnitt
AnkerColor.accentFill       // Bernsteinfläche: Knopf, heute, Drop-Ziel
AnkerColor.accentMark       // Bernstein als Linie/Icon (3:1)
AnkerColor.accentInk        // Bernstein als Schrift (4,5:1)
AnkerColor.accentTint       // getönte Fläche: Tempo-Karte, Chip, Filterpille
AnkerColor.onAccent         // Schrift auf accentFill — Tinte, statisch
AnkerColor.rust / .rustInk  // NUR Rückstand
```

**Zustand kommt aus Füllung, nicht aus Farbton:** erledigt = volle Tinte, offen = Kontur,
heute = Bernstein, im Rückstand = Rost-Kontur. So bleibt es ohne Legende und ohne Farbsehen lesbar.

### Drei gemessene Abweichungen vom Entwurf

Sie sind Korrekturen, keine Vorschläge — jede ist in `AnkerThemeTests` als Messwert festgehalten:

| Entwurf | Gemessen | Stattdessen |
|---|---|---|
| `LotTextFaint` `#A09889` als Mikro-Beschriftung | 2,10:1 auf Grund | `inkTertiary` (= `LotTextMuted`) |
| `LotAmber` `#D9820F` als Marke | 2,15:1 auf Grund | `accentMark` = `LotAmberDeep` (3,21:1) |
| Papierweiß auf Bernstein (primärer Knopf) | 2,89:1 | `onAccent` = Tinte (5,92:1 / 8,09:1) |

Jede **neu** eingeführte Kombination selbst prüfen: 4,5:1 für Text, 3:1 für Icons, Linien und
große Schrift. Der Test misst gegen alle drei Flächen (Grund, eingelassen, Karte).

## Material und Höhe — erlaubt, aber nur über ein Idiom

Lot dreht das Modernist-Verbot um. Bedingung: nie roh an der Aufrufstelle.

```swift
.ankerCard()          // Inhalt, deckend, Höhe 1 · elevated: false = getönte Hinweisfläche
.ankerGlass(.top)     // NUR Chrome über Inhalt: Kopf, Erfassung, Tabs, Sheets
.ankerField()         // Eingabefeld: eingelassen, Haarlinie
.ankerControl()       // Knopf, Auswahlkachel
.ankerPill()          // Filter, Zähler, Marke
.ankerElevation(_:)   // flat · card · lifted · sheet
```

**Text nur auf deckendem Grund.** Glas hinter Fließtext ist beim Scrollen nicht verlässlich
lesbar — `design-guard` prüft, dass `.ankerGlass(` nur in Chrome-Dateien steht.

## Radius & Maß

`AnkerRadius`: check 8 · control 12 · card 16 · group 20 · glass 28 — 4pt-Basis, immer
`.continuous`, nie `.circular`.

**Ohne Radius bleiben genau zwei Dinge:** der Wochenpuls (die sieben Felder müssen als Raster
lesbar bleiben) und der Fortschrittsbalken (ein rundes Ende lügt über den Wert).

`AnkerSpacing`: 4 · 8 · 12 · 16 · 20 · 24 · 32 · `touchTarget` 44 · `section` 56.
In Lot ist die Abschnittsgrenze eine **Haarlinie** — was zwei Bereiche trennt, ist die Farbe der
Linie (`AnkerRule.Weight.section` gegen `.row`), nicht mehr ihre Stärke.

## Typografie

San Francisco für die Arbeitsfläche (Dynamic Type gratis), **Instrument Serif** nur im Ritual —
nie unter 28 pt, nie für Fließtext. Gewichte nur 400/500/600; die Hierarchie tragen Grad, Farbe
und Fläche. Alles über `AnkerType` und `.ankerType(_:)`, nie `.font(.system(...))`.

Ziffern tabellarisch, ausnahmslos — sonst springt „3/5" gegen „1/2". **Ausnahme mit Grund:**
Instrument Serif hat keine `tnum`-Tabelle (gemessen: „1" ist knapp halb so breit wie „0"). Die
Ritual-Tokens sind deshalb nicht tabellarisch, und die eine große Zahl steht in einem festen
Kasten von 0,5 em.

## Bewegung und Haptik

Federn, `response 0.30–0.42 / damping 0.72–0.86`. Bewegung erklärt Ursache und Wirkung, sonst
nichts: alles unter 0,16 s wirkt als Sprung, alles über 0,5 s als Verzögerung. Haptik **nur**,
wenn der Nutzer etwas verändert — abhaken, ablegen, erfassen, Woche schließen. Kein Feedback beim
Lesen, Scrollen oder Filtern. Der Wochenschluss ist der einzige Moment mit `.success`.

## Nie

Kein Verlauf als Fläche. Kein Grün, Gelb oder Blau. Keine Fortschrittsringe. Kein Rost außer für
Rückstand. Keine dritte Schrift. Kein Glas hinter Fließtext. Kein gerundetes Balkenende. Keine
Kennzahl ohne Konsequenz. Keine vier Hierarchieebenen in einer Sidebar.

## Vorhandene Komponenten zuerst prüfen

In [Anchor/AnkerComponents.swift](../../../Anchor/AnkerComponents.swift): `TaskCard`,
`TaskTitleField`, `TaskCheckmark`, `SectionLabel`, `AnchorRow`, `PriorityTag`, `AnkerTabBar`.
In [Anchor/ThemeSurfaces.swift](../../../Anchor/ThemeSurfaces.swift): `AnkerRule`,
`AnkerProgressBar`, `AnkerButtonStyle`, `AnkerToggleStyle`, die sechs Flächen-Idiome.
Erst wiederverwenden, dann erweitern, zuletzt neu bauen.

## Texte & Accessibility

- Alle sichtbaren Strings auf Deutsch, Datumsformate über `AnkerDateFormat`.
- Fortschritte brauchen ein sprechendes `accessibilityLabel` („3 von 4 Ankern"), nicht nur die Zahl.
- Jedes Fingerziel mindestens `AnkerSpacing.touchTarget` (44 pt).
- Auf macOS zusätzlich `.help(...)` mit Shortcut-Hinweis für Icon-Buttons.

Vor dem Abschluss einer Änderung `swift Scripts/design-guard.swift` laufen lassen.
