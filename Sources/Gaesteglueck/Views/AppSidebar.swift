#if canImport(SwiftUI)
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case guests = "Gäste"
    case tables = "Tische"
    case room = "Raumplan"
    case relationships = "Beziehungen"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .guests: "person.3"
        case .tables: "tablecells"
        case .room: "square.split.bottomrightquarter"
        case .relationships: "heart.text.clipboard"
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
