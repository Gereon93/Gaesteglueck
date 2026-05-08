#if canImport(SwiftUI)
import SwiftUI

/// KI-Vorschlag-Karte mit Akzent-Tint Verlauf, Sparkles-Icon-Quadrat links
/// und Action-Buttons unten. Wird im Dashboard, S6 Floating, S7 Sheet
/// verwendet — visueller Marker dafür dass die Aussage von der KI kommt.
struct AISuggestionCard<Content: View, Actions: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    init(
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.content = content
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Tokens.Colors.accent, Color(hex: "#b88a5c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 26, height: 26)

                content()
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineSpacing(3)
            }
            actions()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Tokens.Colors.accentTint, Color(hex: "#f7f0ee"), Color(hex: "#f5f4ee")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
    }
}

extension AISuggestionCard where Actions == EmptyView {
    init(@ViewBuilder content: @escaping () -> Content) {
        self.init(content: content, actions: { EmptyView() })
    }
}
#endif
