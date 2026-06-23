#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Gästeliste-Spalten — Sichtbarkeit der Tabellenspalten. Teilt die
/// `guestlist.col.*.visible`-Keys reaktiv mit der GuestListView.
struct ListColumnsCardView: View {
    @AppStorage("guestlist.col.funfact.visible") private var funfactVisible: Bool = true
    @AppStorage("guestlist.col.tags.visible") private var tagsVisible: Bool = true
    @AppStorage("guestlist.col.seite.visible") private var seiteVisible: Bool = true
    @AppStorage("guestlist.col.tisch.visible") private var tischVisible: Bool = true
    @AppStorage("guestlist.col.menu.visible") private var menuVisible: Bool = true

    var body: some View {
        SettingsCard(
            title: "Gästeliste-Spalten",
            subtitle: "Welche Spalten sollen in der Gäste-Tabelle angezeigt werden?"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("FunFact", isOn: Binding(
                    get: { funfactVisible },
                    set: { funfactVisible = $0 }
                ))
                Toggle("Tags", isOn: Binding(
                    get: { tagsVisible },
                    set: { tagsVisible = $0 }
                ))
                Toggle("Seite", isOn: Binding(
                    get: { seiteVisible },
                    set: { seiteVisible = $0 }
                ))
                Toggle("Tisch", isOn: Binding(
                    get: { tischVisible },
                    set: { tischVisible = $0 }
                ))
                Toggle("Menü", isOn: Binding(
                    get: { menuVisible },
                    set: { menuVisible = $0 }
                ))
            }
        }
    }
}
#endif
