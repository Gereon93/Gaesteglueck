#if canImport(SwiftData)
import Foundation
import SwiftData

enum RoomPlanFactory {
    /// Liefert den vorhandenen RoomPlan zurück oder erzeugt einen frischen,
    /// inserted in den ModelContext. Single Source of Truth — nicht in jedem
    /// View duplizieren.
    @MainActor
    static func ensure(in context: ModelContext, existing: [RoomPlan]) -> RoomPlan {
        if let plan = existing.first { return plan }
        let plan = RoomPlan()
        context.insert(plan)
        return plan
    }
}
#endif
