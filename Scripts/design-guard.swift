#!/usr/bin/env swift

// Schranken des Lot-Designsystems.
//
// Jede Regel des Systemblatts, die sich mechanisch pruefen laesst, steht hier. Aufruf:
//
//     swift Scripts/design-guard.swift
//
// Exitcode 1, sobald eine Regel verletzt ist — damit taugt es als Build- oder CI-Schritt.
// Die Tokendateien selbst sind ausgenommen: dort *entstehen* Schrift, Farbe, Glas und Hoehe.
//
// Lot dreht zwei Verbote des Modernist-Systems ausdruecklich um. **Material und Schatten sind
// jetzt erlaubt** — „Naehe entsteht durch Material und Hoehe, nicht durch Rahmen". Was bleibt,
// ist die Bedingung: beides nur ueber ein Idiom, nie roh an der Aufrufstelle. Deshalb pruefen
// die Regeln hier nicht mehr *ob*, sondern *woher*.

import Foundation

struct Rule {
    let label: String
    let pattern: String
    /// Warum die Regel besteht — der Text steht im Fehlerfall daneben.
    let reason: String
    /// Dateien, in denen das Muster vorkommen **darf**. Leer heisst: nirgends.
    var allowedIn: Set<String> = []
}

/// Der Ritual-Modus ist der zweite Modus des Systems und lebt in genau einer Datei.
let ritualFiles: Set<String> = ["WeeklyReviewView.swift"]

/// Chrome, das ueber Inhalt schweben darf: Kopfzeilen, Erfassung, Tab- und Seitenleisten.
let chromeFiles: Set<String> = [
    "AnkerPhoneChrome.swift", "AnkerComponents.swift", "CaptureBarView.swift",
    "SidebarView.swift", "AnchorStripView.swift", "AnkerMatrixView.swift",
]

let rules = [
    // MARK: - Form

    Rule(label: "Roher Radius", pattern: #"cornerRadius: (?!AnkerRadius)"#,
         reason: "Radius kommt aus AnkerRadius (check/control/card/group/glass) — eine Rolle, keine Zahl."),
    Rule(label: "Eckenform", pattern: #"cornerRadius:(?!.*continuous)"#,
         reason: "Immer style: .continuous. Ein Kreisbogen ist auf Apple-Flaechen sichtbar kantiger."),
    Rule(label: "Kreisbogenecke", pattern: #"style: \.circular"#,
         reason: "Nie .circular — der Entwurf verlangt ausdruecklich .continuous."),
    Rule(label: "Kreis", pattern: #"(?:Circle|Ellipse)\("#,
         reason: "Lot kennt Rechteck, gerundetes Rechteck und Pille. Eine Pille kommt aus ankerPill()."),
    Rule(label: "Rohe Pille", pattern: #"Capsule\("#,
         reason: "Eine Pille kommt aus ankerPill() — sonst hat sie keine Rolle."),

    // MARK: - Material und Hoehe
    //
    // Lot erlaubt beides — aber nur ueber ein Idiom. Roh an der Aufrufstelle waere genau der
    // Rueckfall, den das System vermeiden will: Glas hinter Fliesstext und ein vierter Schatten
    // ohne Bedeutung.

    Rule(label: "Rohes Material", pattern: #"\.(?:ultraThin|thin|regular|thick|ultraThick)Material|Material\)"#,
         reason: "Glas nur ueber ankerGlass() — und nur fuer Chrome, das ueber Inhalt schwebt, nie hinter Fliesstext."),
    Rule(label: "Roher Schatten", pattern: #"\.shadow\("#,
         reason: "Hoehe kommt aus ankerElevation(_:) bzw. ankerCard() — vier Stufen, jede mit Zweck."),
    Rule(label: "blur", pattern: #"\.blur\("#,
         reason: "Weichzeichnung gehoert ins Glas, nicht auf den Inhalt."),
    Rule(label: "Gradient", pattern: "Gradient",
         reason: "Kein Verlauf als Flaeche. Flache Fuellung aus den Tokens benutzen."),

    // MARK: - Schrift

    Rule(label: "font(.system", pattern: #"font\(\.system\("#,
         reason: "Schrift kommt aus AnkerType, nicht aus einer Zahl an der Aufrufstelle."),
    Rule(label: "Dritte Schrift", pattern: #"Font\.custom\(|\.custom\(""#,
         reason: "Keine dritte Schrift. San Francisco fuer die Arbeitsflaeche, Instrument Serif fuer das Ritual."),
    Rule(label: "tracking", pattern: #"\.tracking\("#,
         reason: "Die Laufweite gehoert zum Typo-Token."),
    Rule(label: "textCase", pattern: #"\.textCase\("#,
         reason: "Grossschreibung gehoert zum Typo-Token (overline, eyebrow, microLabel)."),
    // „Serif nur im Ritual und nie unter 28 px." Der Grad steckt im Token und wird im Test
    // geprueft; hier zaehlt der Ort.
    Rule(label: "Serif ausserhalb des Rituals",
         pattern: #"AnkerType\.(?:poster|display|ritualTitle|ritualQuestion)\b"#,
         reason: "Die Serif markiert den Ritual-Modus. Auf der Arbeitsflaeche ist sie eine Zierde.",
         allowedIn: ritualFiles),

    // MARK: - Farbe

    Rule(label: "Rohhex", pattern: #"Color\((?:hex|light): ""#,
         reason: "Hexwerte stehen nur in Theme.swift."),
    // Bewusst auch das blosse `? .white :` — genau in dieser Form standen die Faelle, die im
    // Dunkelmodus weisse Schrift auf helle Flaeche gesetzt haben.
    Rule(label: "Weiss/Schwarz", pattern: #"(?<![A-Za-z0-9_])\.(?:white|black)\b"#,
         reason: "AnkerColor.onAccent bzw. ein Flaechentoken benutzen — Weiss kippt im Dunkelmodus nicht mit."),
    // `LotTextFaint` ist der Wert, den der Entwurf fuer Mikro-Beschriftung vorsieht und der
    // gemessen 2,10:1 auf dem Grund haelt. Als Flaeche richtig, als Schrift unlesbar.
    Rule(label: "faint als Schrift",
         pattern: #"foregroundStyle\(AnkerColor\.faint|foregroundColor\(AnkerColor\.faint"#,
         reason: "AnkerColor.faint ist eine Flaechenfarbe (2,10:1). Text nimmt inkTertiary."),
    // „Rost erscheint hoechstens zweimal pro Bildschirm" und nie als Marke oder Knopf.
    Rule(label: "Rost als Aktion",
         pattern: #"(?:buttonStyle|accentColor|tint)\([^)]*AnkerColor\.rust"#,
         reason: "Rost ist ausschliesslich Rueckstand und Uebertrag — nie Marke, nie Zustand aktiv, nie ein Knopf."),
    Rule(label: "Ritualfarben ausserhalb des Rituals", pattern: #"AnkerColor\.Ritual\b"#,
         reason: "Die Ritualfarben kippen nicht mit dem Erscheinungsbild — auf der Arbeitsflaeche waeren sie fest verdrahtet.",
         allowedIn: ritualFiles),

    // MARK: - Mass

    // Groessen (frame, width, height) bleiben Zahlen — ein 22pt-Kaestchen ist kein Abstand.
    // Negative Werte auch: `.padding(-4)` ist ein Ueberstand, kein Raster.
    Rule(label: "Roher Abstand",
         pattern: #"(?:spacing: |Spacer\(minLength: |\.padding\((?:\.(?:horizontal|vertical|top|bottom|leading|trailing), )?)(?!0\b)\d"#,
         reason: "Abstaende kommen aus AnkerSpacing (4/8/12/16/20/24/32/44/56)."),
    // In Lot ist eine Regel eine Haarlinie. `AnkerBorder.rule * 3` war im Modernist-System die
    // Balkenstaerke — mit rule = 1 rechnet das jetzt still etwas anderes aus.
    Rule(label: "Gerechnete Kantenstaerke", pattern: #"AnkerBorder\.\w+ *[*+]"#,
         reason: "Eine Kantenstaerke ist eine Rolle, kein Faktor. Balkenstaerke steht als Zahl an AnkerProgressBar."),

    // MARK: - Struktur

    Rule(label: "SF Symbols", pattern: "systemName:|systemImage:",
         reason: "Icons kommen aus AnkerIcon (Lucide)."),
    Rule(label: "ProgressRing", pattern: "ProgressRing",
         reason: "Keine Fortschrittsringe. AnkerProgressBar benutzen."),
    // Ein `clipShape(Rectangle())` ist auf einer scharfen Flaeche wirkungslos und auf einer
    // runden falsch.
    Rule(label: "Rechteck geklippt", pattern: #"clipShape\(Rectangle\(\)\)"#,
         reason: "Ohne Wirkung auf scharfen Flaechen. Runde Flaechen kommen aus ankerCard/ankerField/ankerControl/ankerPill."),
    // Die Ordnung der Anker. `week.goalList` ist nach einem CloudKit-Sync ungeordnet: jede
    // Reihenfolgeentscheidung darauf faellt auf zwei Geraeten anders aus.
    Rule(label: "Ungeordnete Anker",
         pattern: #"goalList(?:\s*\?\?\s*\[\])?\.(?:first\?|firstIndex|prefix|enumerated|last\?|dropFirst)"#,
         reason: "Reihenfolge und Nummer kommen aus GoalOrdering, nie aus der Beziehung."),
]

/// Hier entstehen die Tokens — die Grundbausteine muessen darin vorkommen.
let exemptFiles: Set<String> = [
    "Theme.swift", "ThemeType.swift", "ThemeFont.swift", "ThemeIcon.swift", "ThemeSurfaces.swift",
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Anchor")

guard let entries = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
    print("design-guard: Anchor/ nicht gefunden — aus der Repowurzel aufrufen.")
    exit(2)
}

let sources = entries
    .filter { $0.hasSuffix(".swift") && !exemptFiles.contains($0) }
    .sorted()

var violations = 0

for rule in rules {
    guard let regex = try? NSRegularExpression(pattern: rule.pattern) else {
        print("design-guard: Muster fehlerhaft — \(rule.label)")
        exit(2)
    }

    var hits: [String] = []
    for name in sources where !rule.allowedIn.contains(name) {
        guard let text = try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8) else {
            continue
        }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, rawLine) in lines.enumerated() {
            // `goal.colorHex` ist gespeicherte Nutzereingabe, kein Token.
            if rawLine.contains("colorHex") { continue }
            // Ausnahmemarker in der Zeile selbst oder darueber. Bewusst eng: er verlangt eine
            // Begruendung im Klartext daneben, sonst waere es ein Schalter zum Abschalten.
            let marker = "design-guard: erlaubt"
            if rawLine.contains(marker) { continue }
            if index > 0, lines[index - 1].contains(marker) { continue }
            // Der Bezugsstring muss derselbe sein, aus dem die Indizes stammen — sonst
            // trifft NSRange(_:in:) auf fremde Indizes und bricht ab.
            let line = String(rawLine)
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if regex.firstMatch(in: line, range: range) != nil {
                hits.append("\(name):\(index + 1)")
            }
        }
    }

    if hits.isEmpty {
        print("  ✓ \(rule.label)")
    } else {
        violations += hits.count
        print("  ✗ \(rule.label) — \(hits.count)")
        print("      \(rule.reason)")
        for hit in hits.prefix(8) { print("      \(hit)") }
        if hits.count > 8 { print("      … und \(hits.count - 8) weitere") }
    }
}

// MARK: - „Glas nur fuer Chrome"
//
// Die eine Regel, die sich nicht als Zeilenmuster fassen laesst: sie fragt nicht, wie etwas
// geschrieben ist, sondern in welcher Datei es steht.

var glassOutsideChrome: [String] = []
for name in sources where !chromeFiles.contains(name) {
    guard let text = try? String(contentsOf: root.appendingPathComponent(name), encoding: .utf8) else {
        continue
    }
    for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated()
    where line.contains(".ankerGlass(") {
        glassOutsideChrome.append("\(name):\(index + 1)")
    }
}

if glassOutsideChrome.isEmpty {
    print("  ✓ Glas nur fuer Chrome")
} else {
    violations += glassOutsideChrome.count
    print("  ✗ Glas nur fuer Chrome — \(glassOutsideChrome.count)")
    print("      Glas traegt nur Chrome ueber Inhalt. Inhalt selbst ist immer deckend und ruhig.")
    for hit in glassOutsideChrome.prefix(8) { print("      \(hit)") }
}

if violations == 0 {
    print("\ndesign-guard: alle Schranken halten.")
    exit(0)
}
print("\ndesign-guard: \(violations) Verstoesse.")
exit(1)
