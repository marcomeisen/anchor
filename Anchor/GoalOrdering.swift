import Foundation
import SwiftData

/// Die deterministische Ankerreihenfolge.
///
/// Einzige Quelle für Nummer, Auswahl der sichtbaren vier und Erkennung überzähliger Anker.
/// Ohne sie ist „Anker 2" eine geräteabhängige Aussage: CloudKit spiegelt To-many-Beziehungen
/// ungeordnet, und `StoreMaintenance` hängt beim Zusammenführen Ziele in Iterationsreihenfolge
/// an — anders als Tage, die es ausdrücklich nachsortiert.
@MainActor
enum GoalOrdering {
    nonisolated static let maxAnchors = 4

    /// `order` aufsteigend, Gleichstand über `id.uuidString`.
    static func isBefore(_ lhs: Goal, _ rhs: Goal) -> Bool {
        lhs.order != rhs.order ? lhs.order < rhs.order : lhs.id.uuidString < rhs.id.uuidString
    }

    static func sorted(_ goals: [Goal]) -> [Goal] {
        goals.sorted(by: isBefore)
    }

    /// Die sichtbaren vier.
    static func anchors(in week: Week) -> [Goal] {
        Array(sorted(week.goalList).prefix(maxAnchors))
    }

    /// Was über die vier hinausgeht. Entsteht real: die Grenze wird pro Gerät geprüft, zwei
    /// Geräte offline können also je ein fünftes Ziel anlegen.
    static func excess(in week: Week) -> [Goal] {
        Array(sorted(week.goalList).dropFirst(maxAnchors))
    }

    /// 1 bis 4, oder `nil` für einen überzähligen Anker.
    static func anchorNumber(of goal: Goal, in week: Week) -> Int? {
        guard let index = anchors(in: week).firstIndex(where: { $0.id == goal.id }) else { return nil }
        return index + 1
    }

    static func anchor(number: Int, in week: Week) -> Goal? {
        let anchors = anchors(in: week)
        guard anchors.indices.contains(number - 1) else { return nil }
        return anchors[number - 1]
    }

    /// Nächster freier Platz — `max(order) + 1`, **nicht** `count`.
    ///
    /// Zwei Geräte, die offline je ein Ziel anlegen, bekommen sonst dieselbe Nummer und die
    /// Reihenfolge entscheidet der Zufall. Mit `max + 1` und dem uuid-Gleichstandsentscheid
    /// konvergiert es.
    static func nextOrder(in week: Week) -> Int {
        (week.goalList.map(\.order).max() ?? -1) + 1
    }

    /// Vergibt `order` lückenlos 0…n-1 in Sortierreihenfolge.
    ///
    /// Gibt zurück, ob sich etwas geändert hat — sonst würde `StoreMaintenance` bei jedem Lauf
    /// eine Umsortierung melden und speichern, auch auf sauberem Bestand.
    @discardableResult
    static func normalize(_ week: Week) -> Bool {
        let ordered = sorted(week.goalList)
        var didChange = false

        for (index, goal) in ordered.enumerated() where goal.order != index {
            goal.order = index
            didChange = true
        }

        if didChange {
            week.goals = ordered
        }
        return didChange
    }

    /// Nur Anker, die der Nutzer wirklich angelegt hat.
    ///
    /// Der Onboarding-Platzhalter ist ein echter `Goal`-Datensatz und würde eine Woche sonst
    /// unerreichbar machen: ein Anker, der nie eine Aufgabe bekommt.
    static func countableAnchors(in week: Week) -> [Goal] {
        anchors(in: week).filter(WeekPlanning.isUserCreated)
    }
}
