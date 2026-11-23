---
name: anchorit-design-system
description: Designsystem „Blatt" von Anchorit — Tinte auf Hellgrau, weiße Karten mit Haarlinie, Systemschrift, genau eine Farbe (tiefes Blau für erledigt/heute), Anker als Nummern statt Farben, AnkerColor/AnkerType/AnkerRadius/AnkerSpacing-Tokens, Flächen-Idiome, Kontrast in Hell und Dunkel, design-guard. Nutzen bei jeder UI-Arbeit: neue View oder Komponente, Farben, Abstände, Radien, Dark Mode, Kontrast, Icons, Beschriftungen, App-Icon.
---

# Designsystem „Blatt"

Verbindliche Referenz: die Claude-Design-Leinwand **Anchorit Blatt**
(`https://claude.ai/artifact/Jui7Q1ESaZ1Fb5EidHDGeN`). Bei Unsicherheit über einen Wert dort
nachsehen, nicht schätzen. Die Werte stehen in [Anchor/Theme.swift](../../../Anchor/Theme.swift),
[Anchor/ThemeType.swift](../../../Anchor/ThemeType.swift) und
[Anchor/ThemeSurfaces.swift](../../../Anchor/ThemeSurfaces.swift); Views benutzen nur die Tokens.

## Die Idee in einem Satz

Ein Blatt pro Woche: bis zu vier Anker, jeder eine **Nummer**, jede Aufgabe ein **Punkt** bei ihrem
Anker — und nur eine Farbe, die „erledigt" oder „heute" heißt.

## Farbe

| Token | Hell | Dunkel | Wofür |
|---|---|---|---|
| `ground` | `#EEEFF1` | `#111317` | Grund jedes Bildschirms |
| `card` | `#FFFFFF` | `#1A1D22` | Fläche, auf der Inhalt steht |
| `surface` | `#F4F5F7` | `#1E2127` | Segmentschiene, „ohne Tag", ruhende Chips |
| `divider` / `cardDivider` | `#D9DBDF` / `#ECEDEF` | `#2E3239` / `#262A31` | Haarlinie um Karten / zwischen Zeilen |
| `ink` / `inkSecond` / `inkTertiary` | `#14161A` / `#4A4F57` / `#646973` | `#F2F3F5` / `#B4B8BF` / `#8E939B` | Schrift und Icons |
| `accentMark` = `accentFill` | `#23338A` | `#8C9BFF` | **die** Farbe: Haken, Fortschritt, heute |
| `accentInk` | `#23338A` | `#A9B4FF` | Blau als Schrift |
| `accentTint` / `todayTint` | `#E6E9F5` / `#F3F5FB` | `#1D2547` / `#171C2E` | ausgewählt / Heute-Spalte |
| `onInk` / `onAccent` | Weiß | `#111317` | Schrift auf Tinte bzw. Blau |

Regeln:
- **Blau ist kein „hier tippen".** Der Hauptknopf ist Tinte (`AnkerButtonStyle.primary`).
  `AnkerButtonStyle.accent` nur für einen Schritt, der direkt „einplanen" oder „auswählen" heißt.
- **Anker haben keine Farbe.** `goalTint(_:)` gibt für Altbestand überall `accentMark` zurück; neue
  Ziele bekommen `goalTintOptions[0]`, der Wert wird nicht angezeigt.
- **Die Rampen (`neutral[…]`, `accent[…]`) sind keine Textfarbe.** Schrift nur aus `ink*` bzw.
  `accentInk` — die Kontrasttests in `AnkerThemeTests` sichern genau diese Paarungen in beiden Modi.
- Dunkelmodus läuft über `Color(light:dark:)` im Token, nie über `@Environment(\.colorScheme)` in
  der View.

## Schrift

Systemschrift (SF Pro) über `AnkerType`, auf iOS über `UIFontMetrics` mit Dynamic Type skaliert.
Schwere, eng gesetzte Schlagzeilen (`title1`–`title3`, `display`, `poster`), ruhiger Text
(`taskTitle` 16/mittel, `body` 15/mittel), Beschriftungen in **normaler Schreibung** (`overline`
13/halbfett, `inkSecond`). Zahlen tabellarisch (`numeric`, `anchorNumber`, `statValue`).
`.font(.system(…))`, `.tracking` und `.textCase` gehören nicht in Views.

## Flächen — welche Frage beantwortet sie?

| Idiom | Was es ist |
|---|---|
| `.ankerCard()` | Inhalt: weiß, Haarlinie, `AnkerRadius.card` (14). Schwebt **nicht**. |
| `.ankerCard(fill:elevated: false)` | getönte Hinweisfläche ohne Rahmen |
| `.ankerLooseArea()` | gestrichelt: alles ohne festen Platz — „ohne Anker", „noch ohne Tag" |
| `.ankerField()` | Eingabefeld |
| `.ankerControl()` | Knopf, Kachel, Schrittschalter |
| `.ankerPanel()` | Leiste über die ganze Breite |
| `.ankerLifted()` | **nur** was man gerade zieht — der einzige Schatten |

Bausteine: `AnkerPips` (ein Punkt pro Aufgabe, ab 13 ein Balken), `AnkerProgressBar`,
`AnkerSegmented` (graue Schiene, weiße Auswahl), `BlattHeading`, `BlattAnchorStrip`, `TaskChip`,
`TaskCard`. **Erst wiederverwenden, dann erweitern, zuletzt neu bauen.**

## Maße

- Abstände aus `AnkerSpacing`: 2 · 4 · 6 · 8 · 12 · 16 · 24 · 32; Bildschirmrand
  `screenPadding` (20 iPhone, 24 Mac).
- Radien nur als Rolle: `check` (6, mit `check(size:)` für kleine Kästchen), `chip` (7), `cell`
  (6), `mark` (2), `inlineButton` (9), `control` (10), `bar` (12), `card` (14). Immer
  `style: .continuous`.
- Jede Linie ist eine Haarlinie (`AnkerBorder.hairline`); Bereiche trennt der Abstand.

## Verboten (prüft `swift Scripts/design-guard.swift`)

Materialien, Verläufe, Weichzeichnung, Schatten außerhalb der Tokens, Kreise, Ringe, SF Symbols
(Icons kommen aus `AnkerIcon`, Lucide), `.white`/`.black`, Hexwerte außerhalb `Theme.swift`, rohe
Radien und Abstände, Versalien in Views, Ankerreihenfolge über `week.goalList`.

## App-Icon

Das Blatt als Motiv: vier Reihen zu fünf gerundeten Quadraten, Erledigtes blau gefüllt, Offenes nur
Kante. Varianten hell, dunkel, getönt (iOS) und macOS. Nie von Hand ändern:

```bash
swift Scripts/make-icon-sources.swift   # zeichnet assets/icon/ und das Menüleisten-Glyph
swift Scripts/make-app-icons.swift      # leitet AppIcon.appiconset ab
```

## Texte & Accessibility

- Alle sichtbaren Strings auf Deutsch, Datumsformate über `AnkerDateFormat`.
- Fortschritt spricht in Sätzen: „Anker 1, Launch, 2 von 5 erledigt" — nicht nur die Zahl.
- Icon-Knöpfe haben `accessibilityLabel`, auf dem Mac zusätzlich `.help(…)`.
- Mindestens 44pt Tippfläche auf dem iPhone.
