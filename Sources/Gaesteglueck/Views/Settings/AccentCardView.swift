#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Akzentfarbe — 5 Swatches.
struct AccentCardView: View {
    @AppStorage("accentColorHex") private var accentColorHex = "#c8788c"

    private static let accentSwatches: [String] = [
        "#c8788c", // Rose (default)
        "#b88a5c", // Amber
        "#7a8b6c", // Sage
        "#6e8aab", // Slate Blue
        "#9b7bae", // Mauve
    ]

    var body: some View {
        SettingsCard(
            title: "Akzentfarbe",
            subtitle: "Erscheint auf Buttons, Sidebar-Selektionen und im Export."
        ) {
            HStack(spacing: 10) {
                ForEach(Self.accentSwatches, id: \.self) { hex in
                    Button {
                        accentColorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                            if accentColorHex == hex {
                                Circle()
                                    .strokeBorder(Tokens.Colors.surface, lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .strokeBorder(Color(hex: hex), lineWidth: 1.5)
                                    .frame(width: 38, height: 38)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Eigene Farbe…") {}
                    .warmButton(.secondary, size: .sm)
            }
        }
    }
}
#endif
