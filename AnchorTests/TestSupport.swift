import Foundation
import SwiftData
@testable import Anchorit

extension TaskActions {
    /// Woche **mit** allen sieben Tagen. Die App legt Tage erst beim Schreiben an; viele Tests
    /// greifen aber direkt auf `week.dayList` zu und wollen den vollen Wochenrahmen.
    @MainActor
    @discardableResult
    static func ensureFullWeek(containing date: Date, weeks: [Week], modelContext: ModelContext) -> Week {
        let week = ensureWeek(containing: date, weeks: weeks, modelContext: modelContext)
        ensureWeekDays(in: week)
        return week
    }
}
