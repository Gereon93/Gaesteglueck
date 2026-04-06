#if canImport(SwiftUI)
import SwiftUI
import SwiftData

// Note: @main is omitted because this is a library target.
// The actual app target (Xcode project) adds @main.
struct GaesteglueckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Event.self, Guest.self, GuestTable.self,
            Tag.self, Constraint.self, RoomPlan.self,
            TableInventoryItem.self,
        ])
    }
}
#endif
