#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedSection: AppSection? = .dashboard
    @Query private var events: [Event]

    var body: some View {
        if events.isEmpty {
            // Erst-Launch: direkt ins Welcome (S1) — vollbild, ohne Sidebar
            OnboardingWizardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Tokens.Colors.bg)
        } else {
            mainSplit
        }
    }

    private var mainSplit: some View {
        NavigationSplitView {
            AppSidebar(selection: $selectedSection)
        } detail: {
            switch selectedSection {
            case .dashboard:
                DashboardView(selection: $selectedSection)
            case .guests:
                GuestListView()
            case .tables:
                RoomCanvasView()
            case .tags:
                TagListView()
            case .assistant:
                KIWizardView()
            case .export:
                #if os(macOS)
                ExportView()
                #else
                ContentUnavailableView(
                    "Export nur am Mac",
                    systemImage: "square.and.arrow.up",
                    description: Text("PDF- und Bild-Exporte sind in der iPad-Version noch nicht verfügbar.")
                )
                #endif
            case .settings:
                SettingsView()
            case nil:
                ContentUnavailableView(
                    "Bereich wählen",
                    systemImage: "sidebar.left",
                    description: Text("Wähle einen Bereich aus der Seitenleiste.")
                )
            }
        }
    }
}
#endif
