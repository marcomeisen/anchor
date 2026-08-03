---
name: daivento-design-system
description: Designsystem v2 von Daivento — AnkerColor/AnkerRadius/AnkerSpacing-Tokens, Light/Dark, die Liquid-Glass-Regel (Material nur auf Chrome, nie auf Inhalt), WCAG-korrigierte Farbwerte, Typografie-Skala und deutsche UI-Texte. Nutzen bei jeder UI-Arbeit: neue View oder Komponente, Farben, Abstände, Radien, Dark Mode, Glas/Material, Kontrast, Icons, Beschriftungen.
---

# Designsystem v2

Verbindliche visuelle Referenz: [Anchor/Anker_Design_System_v2.html](../../../Anchor/Anker_Design_System_v2.html)
(alle 9 Screens, Light/Dark-Umschalter oben rechts). Migrationsregeln:
[Anchor/Anker_Coding_Prompt_v2_Migration.md](../../../Anchor/Anker_Coding_Prompt_v2_Migration.md).
Mac-Task-Flow: [Daivento_Task_Flow_Mac_Visuals.html](../../../Daivento_Task_Flow_Mac_Visuals.html).

Bei Unsicherheit über einen konkreten Wert: in der HTML-Referenz nachsehen, nicht schätzen.

## Kernregel: Glas nur auf Chrome

Liquid Glass gehört **ausschließlich** auf die Navigationsebene — Sidebar, Toolbars, Popover,
Tab-Leiste, schwebende Buttons. Die Inhaltsebene bleibt matt und opak: Aufgabenkarten, Zielkarten,
Wochenraster, Monatskacheln nutzen `AnkerColor.card` + `AnkerColor.line`, **niemals** ein Material.

Für Chrome native Materialien (`.ultraThinMaterial`, `.thinMaterial`, `.regularMaterial`) verwenden —
kein selbstgebauter Blur, keine eigenen Glas-Farbtokens. Materialien passen sich automatisch an
Light/Dark und Hintergrund an; genau das ist ihr Zweck.

## Tokens

Alles aus [Anchor/Theme.swift](../../../Anchor/Theme.swift), nie Rohwerte in Views.
Ausnahme, die im Bestand vorkommt: `Color(hex: goal.colorHex)` für nutzerdefinierte Zielfarben.

```swift
AnkerColor.appBackground / .paper     // #F7F7FA · #111219
AnkerColor.surface / .card            // #FFFFFF · #1C1D24
AnkerColor.surfaceRaised              // #FFFFFF · #23242D
AnkerColor.line                       // #E4E5EA · weiß 12 %
AnkerColor.lineSoft                   // #EDEEF2 · weiß 7 %
AnkerColor.textStrong / .ink          // #1C1E27 · #F2F2F7
AnkerColor.textSoft / .muted          // #8A8D98 · #A6A9B5

AnkerColor.indigo        // #5B6EE8  dekorativ (Ringe, Punkte) — NICHT für Text
AnkerColor.indigoBadge   // #4D61E6  Hintergrund für weißen Text
AnkerColor.indigoText    // #3F4FBF · #90A0F5  Text/Links auf Fläche
AnkerColor.brass         // #C9974B · #E0BC85
AnkerColor.successIcon / .success  // #2A9F47
AnkerColor.prioA         // #D93327
AnkerColor.prioC         // #6E7180
AnkerColor.month[0...11] // 12 Monatsfarben

AnkerRadius.card = 11 · .pill = 14 · .sheet = 13
AnkerSpacing.screenPadding = 20 · .stack = 10
```

`ink`, `paper`, `card`, `muted`, `indigoDark`, `success` sind Aliase auf die v2-Namen und im Bestand
weit verbreitet — beide Schreibweisen sind okay, innerhalb einer Datei konsistent bleiben.

## Dark Mode

Über `Color(light:dark:)` in `Theme.swift`, das intern einen dynamischen `NSColor`/`UIColor` baut.
**Nicht** über `#if` oder `@Environment(\.colorScheme)` verzweigen — das System soll live umschalten.
Neue Farben also im Token-Enum ergänzen, nicht in der View entscheiden.

## Kontrast — diese vier Werte sind Korrekturen, nicht Vorschläge

| Verwendung | Falsch (v1) | Richtig (v2) |
|---|---|---|
| Weißer Text auf Prio-B-Badge | `#5B6EE8` (4,34) | `#4D61E6` (5,04) |
| Weißes Häkchen auf Erfolgsgrün | `#34C759` (2,22) | `#2A9F47` (3,42) |
| Weißer Text auf Prio-A-Badge | `#E0574D` (3,72) | `#D93327` (4,72) |
| `indigoText` im Dark Mode | `#3F4FBF` (2,46) | `#90A0F5` (6,82) |

Jede **neu** eingeführte Farbkombination selbst gegen 4,5:1 (Text) bzw. 3:1 (Icons, große Schrift)
prüfen. Monatskachel-Sekundärtext nutzt Ink-Farbe mit ~72 % Deckkraft, keinen helleren Grauton —
der fiel bei mehreren Monatsfarben durch den Kontrast-Check.

## Typografie

Nur System-Font, keine Custom-Fonts. Skala aus der Referenz:

| Rolle | Wert |
|---|---|
| Screen-Titel | 22 pt / `.bold` |
| Sektionslabel | 10,5–11 pt / `.bold`, `.uppercased()`, `AnkerColor.muted` |
| Kartentitel | 13 pt / `.semibold` |
| Fließtext, Meta | 10–12,5 pt / `.medium`–`.semibold` |
| Datum/Zahlen | zusätzlich `design: .monospaced` |

## Verfügbare Komponenten zuerst prüfen

In [Anchor/AnkerComponents.swift](../../../Anchor/AnkerComponents.swift) existieren bereits:
`AnchorGlyph`, `DaiventoLogo`, `AnchorBadge`, `SectionLabel`, `ProgressRing`, `GoalBanner`,
`PriorityTag`, `TaskCheckmark`, `TaskCard`, `WeekDot`, `ChipButton`, `GlassTabBar`, `GlassFAB`;
dazu `CaptureChip` in `DetailAndCaptureViews.swift` und `FlowLayout` für umbrechende Chip-Reihen.
Erst wiederverwenden, dann erweitern, zuletzt neu bauen.

Kartenrezept im Bestand:

```swift
.background(AnkerColor.card)
.overlay(RoundedRectangle(cornerRadius: AnkerRadius.card).stroke(AnkerColor.line, lineWidth: 1))
.clipShape(RoundedRectangle(cornerRadius: AnkerRadius.card))
```

## Texte & Accessibility

- Alle sichtbaren Strings auf Deutsch, Datumsformate mit `Locale(identifier: "de_DE")`.
- Ringe und Fortschritte brauchen ein sprechendes `accessibilityLabel`
  („Jahresplanung 2026, 70 Prozent erreicht"), nicht nur die Zahl.
- Auf macOS zusätzlich `.help(...)` mit Shortcut-Hinweis für Icon-Buttons — im Bestand durchgehend so.
