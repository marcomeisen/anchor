import Foundation

// Schranke für die Übersetzung — aus der Repowurzel aufrufen:
//
//     swift Scripts/l10n-guard.swift
//
// Prüft `Anchor/Localizable.xcstrings`:
// - Jeder benutzte Schlüssel hat **Deutsch und Englisch**. Fehlt Deutsch, sieht ein deutsches
//   Gerät den englischen Text: Die Rückfallsprache der App ist Englisch.
// - Platzhalter (`%@`, `%lld`) stimmen in Anzahl und Art überein.
// - Englische Texte enthalten keine Umlaute — ein Zeichen für vergessene Übersetzung.
// - Keine veralteten Schlüssel (`stale`).
//
// Neue Texte kommen so in den Katalog: bauen (macOS **und** iOS-Simulator, weil manche Texte
// nur unter einer Plattform kompilieren), dann
//     xcrun xcstringstool sync Anchor/Localizable.xcstrings --stringsdata <…>.stringsdata …
// und für jeden neuen Schlüssel `de` und `en` eintragen.

struct Failure { let key: String; let reason: String }

let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Anchor/Localizable.xcstrings")
guard let data = try? Data(contentsOf: url),
      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let strings = json["strings"] as? [String: [String: Any]] else {
    print("l10n-guard: Localizable.xcstrings nicht lesbar")
    exit(2)
}

let specifier = try! NSRegularExpression(pattern: #"%(?:\d+\$)?(@|lld|ld|d)"#)
func specifiers(_ text: String) -> [String] {
    specifier.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
        String(text[Range($0.range(at: 1), in: text)!])
    }.sorted()
}

func value(_ entry: [String: Any], _ language: String) -> String? {
    guard let localizations = entry["localizations"] as? [String: Any],
          let localized = localizations[language] as? [String: Any],
          let unit = localized["stringUnit"] as? [String: Any] else { return nil }
    return unit["value"] as? String
}

var failures: [Failure] = []
for (key, entry) in strings.sorted(by: { $0.key < $1.key }) {
    if (entry["shouldTranslate"] as? Bool) == false { continue }
    if (entry["extractionState"] as? String) == "stale" {
        failures.append(Failure(key: key, reason: "veraltet — Schlüssel entfernen"))
        continue
    }
    guard let german = value(entry, "de") else {
        failures.append(Failure(key: key, reason: "Deutsch fehlt"))
        continue
    }
    guard let english = value(entry, "en") else {
        failures.append(Failure(key: key, reason: "Englisch fehlt"))
        continue
    }
    if specifiers(german) != specifiers(key) {
        failures.append(Failure(key: key, reason: "deutsche Platzhalter weichen ab"))
    }
    // „%@." und „%@, %@." tragen den deutschen Ordinalpunkt, Englisch lässt ihn weg.
    if specifiers(english) != specifiers(key) {
        failures.append(Failure(key: key, reason: "englische Platzhalter weichen ab: \(english)"))
    }
    if english.rangeOfCharacter(from: CharacterSet(charactersIn: "äöüÄÖÜß")) != nil {
        failures.append(Failure(key: key, reason: "Umlaut im Englischen: \(english)"))
    }
}

if failures.isEmpty {
    print("l10n-guard: \(strings.count) Schlüssel, alle auf Deutsch und Englisch.")
    exit(0)
}
for failure in failures {
    print("  ✗ \(failure.key.debugDescription): \(failure.reason)")
}
print("\nl10n-guard: \(failures.count) Probleme.")
exit(1)
