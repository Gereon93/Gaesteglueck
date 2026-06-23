#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S9 — Einstellungen (siehe design_handoff_gaesteglueck → S9). Karten in
/// zentrierter 720pt-Spalte: KI-Anbieter, KI pro Funktion, Akzentfarbe,
/// Event-Daten, Sitzplan-Regeln, Gästeliste-Spalten, Daten.
///
/// Die einzelnen Karten liegen als eigenständige Views unter `Settings/` —
/// jede hält ihren eigenen State (@AppStorage/@Query) und ist damit
/// unabhängig reaktiv.
struct SettingsView: View {
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                VStack(spacing: 16) {
                    AISettingsCardView()
                    AccentCardView()
                    EventCardView()
                    SeatingCardView()
                    ListColumnsCardView()
                    DataCardView()
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .background(Tokens.Colors.bg)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(
            title: "Einstellungen",
            subtitle: "Lokale Konfiguration · ändert nichts außerhalb dieses Macs."
        )
    }
}
#endif
