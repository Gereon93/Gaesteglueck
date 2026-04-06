#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @State private var selectedSection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView()
            case .guests:
                GuestListView()
            case .tables:
                RoomCanvasView()
            case .tags:
                TagListView()
            case .assistant:
                KIWizardView()
            case .settings:
                SettingsView()
            case nil:
                ContentUnavailableView("Bereich wählen", systemImage: "sidebar.left", description: Text("Wähle einen Bereich aus der Seitenleiste."))
            }
        }
    }
}
#endif
