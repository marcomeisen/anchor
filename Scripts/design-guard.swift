#!/usr/bin/env swift

// Schranken des Modernist-Designsystems.
//
// Jede Regel des Systemblatts, die sich mechanisch pruefen laesst, steht hier. Aufruf:
//
//     swift Scripts/design-guard.swift
//
// Exitcode 1, sobald eine Regel verletzt ist — damit taugt es als Build- oder CI-Schritt.
// Die Tokendateien selbst sind ausgenommen: dort *entstehen* Schrift, Farbe und Kante, dort
// muessen die Grundbausteine vorkommen.

import Foundation

struct Rule {
    let label: String
    let pattern: String
    /// Warum die Regel besteht — der Text steht im Fehlerfall daneben.
    let reason: String
}

let rules = [
    // Runde 3 hebt das Radiusverbot nicht auf, sie trennt zwei Mengen: rund ist, was man
    // anfasst oder was schwebt; scharf bleibt die Struktur. Deshalb prueft die Schranke jetzt
    // nicht mehr *ob*, sondern *wie*.
    Rule(label: "Roher Radius", pattern: #"cornerRadius: (?!AnkerRadius)"#,
         reason: "Radius kommt aus AnkerRadius (control/card/check/tile) — eine Rolle, keine Zahl."),
    Rule(label: "Eckenform", pattern: #"cornerRadius:(?!.*continuous)"#,
         reason: "Immer style: .continuous. Ein Kreisbogen ist auf Apple-Flaechen sichtbar kantiger."),
    Rule(label: "Kreisbogenecke", pattern: #"style: \.circular"#,
         reason: "Nie .circular — der Entwurf verlangt ausdruecklich .continuous."),
    Rule(label: "Material", pattern: "Material",
         reason: "Nichts schwebt. AnkerColor.surface plus ankerPanel() benutzen."),
    Rule(label: "Gradient", pattern: "Gradient",
         reason: "Keine Verlaeufe. Flache Fuellung aus der Rampe benutzen."),
    Rule(label: "shadow", pattern: #"\.shadow\("#,
         reason: "Kein Schatten. Die Kante macht AnkerBorder.rule sichtbar."),
    Rule(label: "blur", pattern: #"\.blur\("#,
         reason: "Keine Weichzeichnung."),
    Rule(label: "font(.system", pattern: #"font\(\.system\("#,
         reason: "Schrift kommt aus AnkerType, nicht aus einer Zahl an der Aufrufstelle."),
    Rule(label: "tracking", pattern: #"\.tracking\("#,
         reason: "Die Laufweite gehoert zum Typo-Token."),
    Rule(label: "textCase", pattern: #"\.textCase\("#,
         reason: "Grossschreibung gehoert zum Typo-Token (overline, eyebrow, microLabel)."),
    Rule(label: "SF Symbols", pattern: "systemName:|systemImage:",
         reason: "Icons kommen aus AnkerIcon (Lucide)."),
    // Bewusst auch das blosse `? .white :` — genau in dieser Form standen die Faelle, die im
    // Dunkelmodus weisse Schrift auf helle Flaeche gesetzt haben. `Color.white` allein zu
    // pruefen liess sie durch.
    Rule(label: "Weiss/Schwarz", pattern: #"(?<![A-Za-z0-9_])\.(?:white|black)\b"#,
         reason: "AnkerColor.onAccent bzw. eine Rampenstufe benutzen — Weiss kippt im Dunkelmodus nicht mit."),
    // Ein `clipShape(Rectangle())` ist auf einer scharfen Flaeche wirkungslos und auf einer
    // runden falsch. Wo es steht, steht fast immer das alte Panel-Idiom daneben.
    Rule(label: "Rechteck geklippt", pattern: #"clipShape\(Rectangle\(\)\)"#,
         reason: "Ohne Wirkung auf scharfen Flaechen. Runde Flaechen kommen aus ankerCard/ankerField/ankerControl."),
    // Die Ordnung der Anker.  `week.goalList` ist nach einem CloudKit-Sync ungeordnet: jede
    // Reihenfolgeentscheidung darauf faellt auf zwei Geraeten anders aus.
    Rule(label: "Ungeordnete Anker",
         pattern: #"goalList(?:\s*\?\?\s*\[\])?\.(?:first\?|firstIndex|prefix|enumerated|last\?|dropFirst)"#,
         reason: "Reihenfolge und Nummer kommen aus GoalOrdering, nie aus der Beziehung."),
    Rule(label: "ProgressRing", pattern: "ProgressRing",
         reason: "Ein Ring ist eine gerundete, geschmueckte Form. AnkerProgressBar benutzen."),
    Rule(label: "Rohhex", pattern: #"Color\((?:hex|light): ""#,
         reason: "Hexwerte stehen nur in Theme.swift."),
    Rule(label: "Kreis", pattern: #"(?:Circle|Ellipse)\("#,
         reason: "Marker und Bedienelemente sind Quadrate. Rectangle() benutzen."),
    // Groessen (frame, width, height) bleiben Zahlen — ein 22pt-Kaestchen ist kein Abstand.
    // Negative Werte auch: `.padding(-4)` ist ein Ueberstand, kein Raster.
    Rule(label: "Roher Abstand",
         pattern: #"(?:spacing: |Spacer\(minLength: |\.padding\((?:\.(?:horizontal|vertical|top|bottom|leading|trailing), )?)(?!0\b)\d"#,
         reason: "Abstaende kommen aus AnkerSpacing (4/8/12/16/24/32)."),
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
    for name in sources {
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

if violations == 0 {
    print("\ndesign-guard: alle Schranken halten.")
    exit(0)
}
print("\ndesign-guard: \(violations) Verstoesse.")
exit(1)
