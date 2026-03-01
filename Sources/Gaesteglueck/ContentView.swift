#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection? = .guests

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .guests:
                GuestListView()
            case .tables:
                TableListView()
            case .room:
                RoomCanvasView()
            case .relationships:
                RelationshipListView()
            case nil:
                ContentUnavailableView("Bereich wählen", systemImage: "sidebar.left", description: Text("Wähle einen Bereich aus der Seitenleiste."))
            }
        }
    }
}
#endif
