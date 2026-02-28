#if canImport(SwiftUI)
import SwiftUI
import SwiftData

@main
struct GaesteglueckApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Event.self, Guest.self, GuestTable.self, Relationship.self, RoomPlan.self])
    }
}
#endif
