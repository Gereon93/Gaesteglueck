#if canImport(SwiftUI)
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case guests = "Gäste"
    case tables = "Tische & Raum"
    case tags = "Gruppen & Tags"
    case assistant = "KI-Assistent"
    case settings = "Einstellungen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: "house"
        case .guests: "person.3"
        case .tables: "tablecells"
        case .tags: "tag"
        case .assistant: "sparkles"
        case .settings: "gear"
        }
    }
}

struct AppSidebar: View {
    @Binding var selection: AppSection?

    var body: some View {
        List(AppSection.allCases, selection: $selection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .tag(section)
        }
        .navigationTitle("Gästeglück")
    }
}
#endif
