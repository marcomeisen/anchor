import Foundation
import SwiftData

/// Die Zeilen der Anker-Matrix: vier Anker, etwaige überzählige, und der Eingangskorb.
enum MatrixRowKind: Equatable {
    /// Anker 1 bis 4.
    case anchor(number: Int)
    /// Fünfter und weiterer Anker. Kann durch einen Sync entstehen, weil zwei Geräte offline
    /// je ein Ziel anlegen können und die Vier-Anker-Grenze pro Gerät geprüft wird.
    case excess(number: Int)
    /// Aufgaben ohne Ziel.
    case inbox
}

struct MatrixRow: Identifiable, Equatable {
    /// `nil` beim Eingangskorb — der hat kein Ziel.
    let goalID: UUID?
    let kind: MatrixRowKind
    let title: String
    let colorHex: String
    let doneCount: Int
    let totalCount: Int

    var id: String {
        goalID?.uuidString ?? "inbox"
    }

    var progress: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    var number: String {
        switch kind {
        case .anchor(let n), .excess(let n): String(n)
        case .inbox: "–"
        }
    }

    var isInbox: Bool { kind == .inbox }

    var isExcess: Bool {
        if case .excess = kind { return true }
        return false
    }
}

/// Zeile = Anker, Spalte = Tag.
///
/// Der Entwurf begründet die Matrix damit, dass Ziehen **verankern und terminieren in einer
/// Bewegung** erledigt — die zwei Entscheidungen, die im Bestand zwei Blätter brauchen.
///
/// Bewusst ein eigener Typ ohne View: welche Aufgabe in welche Zelle gehört, ist die Aussage
/// der Ansicht und muss prüfbar sein. Die wichtigste Eigenschaft ist eine Invariante — die
/// Vereinigung aller Zellen einer Spalte ist genau der Tag. Nur deshalb gibt es überhaupt
/// Zeilen für überzählige Anker: ohne sie verschwänden deren Aufgaben aus der Ansicht.
@MainActor
enum AnkerMatrix {
    nonisolated static let maxAnchors = 4

    /// Die Anker in stabiler Reihenfolge.
    ///
    /// Über `order`, mit der `id` als Gleichstandsentscheid — dieselbe Konvention wie
    /// `StoreMaintenance.electSurvivor`, damit zwei Geräte unabhängig dasselbe Ergebnis
    /// bekommen. Bewusst **nicht** über den Titel: Umbenennen darf nicht umnummerieren.
    static func orderedGoals(in week: Week) -> [Goal] {
        GoalOrdering.sorted(week.goalList)
    }

    static func anchorNumber(of goal: Goal, in week: Week) -> Int? {
        guard let index = orderedGoals(in: week).firstIndex(where: { $0.id == goal.id }),
              index < maxAnchors else {
            return nil
        }
        return index + 1
    }

    static func rows(for week: Week) -> [MatrixRow] {
        let goals = orderedGoals(in: week)

        var rows = goals.enumerated().map { index, goal in
            let own = tasks(ofGoal: goal.id, in: week)
            return MatrixRow(
                goalID: goal.id,
                kind: index < maxAnchors ? .anchor(number: index + 1) : .excess(number: index + 1),
                title: goal.title,
                colorHex: goal.colorHex,
                doneCount: own.filter(\.isDone).count,
                totalCount: own.count
            )
        }

        let unanchored = week.dayList.flatMap(\.taskList).filter { $0.linkedGoal == nil }
        rows.append(
            MatrixRow(
                goalID: nil,
                kind: .inbox,
                title: "Ohne Anker",
                colorHex: "",
                doneCount: unanchored.filter(\.isDone).count,
                totalCount: unanchored.count
            )
        )
        return rows
    }

    /// Die Aufgaben einer Zelle.
    static func tasks(in row: MatrixRow, on day: Day) -> [AnkerTask] {
        day.taskList
            .filter { $0.linkedGoal?.id == row.goalID }
            .sorted { $0.order < $1.order }
    }

    static func orderedDays(in week: Week) -> [Day] {
        week.dayList.sorted { $0.date < $1.date }
    }

    private static func tasks(ofGoal goalID: UUID, in week: Week) -> [AnkerTask] {
        week.dayList.flatMap(\.taskList).filter { $0.linkedGoal?.id == goalID }
    }

    // MARK: - Texte
    //
    // Rein und ohne Modellbezug, damit die Formulierungen einzeln prüfbar sind.

    nonisolated static func metaLine(kind: MatrixRowKind, doneCount: Int, totalCount: Int) -> String {
        switch kind {
        case .inbox:
            return totalCount == 0 ? "Eingangskorb leer" : "\(totalCount) ohne Bezug"
        case .excess:
            return "überzähliger Anker · \(totalCount) Aufgaben"
        case .anchor:
            guard totalCount > 0 else { return "noch keine Aufgabe — hierher ziehen" }
            return "\(doneCount) von \(totalCount) erledigt"
        }
    }

    nonisolated static let emptyCellHint = "hier ablegen"

    /// Kopfzeile über der Matrix.
    nonisolated static func headline(inMotion: Int, anchorCount: Int, openTasks: Int) -> String {
        "\(inMotion) von \(anchorCount) Ankern in Bewegung · \(openTasks) offen"
    }

    /// Ein Anker ist „in Bewegung", wenn mindestens eine seiner Aufgaben erledigt ist.
    ///
    /// Mitten in der Woche ist „vollständig erledigt" fast immer null und damit als Kennzahl
    /// unbrauchbar — die Matrix soll zeigen, was sich bewegt, nicht was fertig ist.
    static func inMotionCount(in week: Week) -> Int {
        orderedGoals(in: week).prefix(maxAnchors).filter { goal in
            tasks(ofGoal: goal.id, in: week).contains(where: \.isDone)
        }.count
    }
}

/// Spaltenbreiten der Matrix.
///
/// Eigener Typ, weil Kopfzeile und Zeilen dieselbe Rechnung brauchen: die Tagesköpfe stehen
/// **außerhalb** des scrollenden Bereichs und würden sonst gegen die Zellen verrutschen.
struct AnkerMatrixMetrics: Equatable {
    static let anchorColumnWidth: CGFloat = 212
    static let minCellHeight: CGFloat = 78
    /// Darunter wird eine Tagesspalte unlesbar; dann scrollt die Matrix waagerecht.
    static let minDayColumnWidth: CGFloat = 108

    static func dayColumnWidth(containerWidth: CGFloat) -> (width: CGFloat, needsHorizontalScroll: Bool) {
        let available = containerWidth - anchorColumnWidth
        let ideal = available / 7
        if ideal < minDayColumnWidth {
            return (minDayColumnWidth, true)
        }
        return (ideal, false)
    }
}
