#if canImport(SwiftUI)
import SwiftUI

/// Leere-Listen-Begrüßung mit zentriertem Icon-Quadrat, Display-Title,
/// Body-Copy und optionaler Action darunter. Variant `.warm` legt zusätzlich
/// Akzent-Tint und WavePattern hinter den Inhalt — für besonders prominente
/// Empty States wie das Welcome auf dem Dashboard.
struct EmptyStateCard<Action: View>: View {
    enum Variant { case `default`, warm }

    let icon: String
    let title: String
    let message: String
    var variant: Variant = .default
    @ViewBuilder var action: () -> Action

    init(
        icon: String,
        title: String,
        message: String,
        variant: Variant = .default,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.variant = variant
        self.action = action
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Colors.surface)
                        .frame(width: 56, height: 56)
                        .cardShadow()
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Tokens.Colors.accent)
                }
                .padding(.bottom, 10)

                Text(title)
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(Tokens.Typography.bodyM)
                    .foregroundStyle(Tokens.Colors.ink2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .lineSpacing(3)

                action()
                    .padding(.top, 14)
            }
            .padding(40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    fileprivate var backgroundLayer: some View {
        switch variant {
        case .default:
            Tokens.Colors.bg2
        case .warm:
            ZStack {
                Tokens.Colors.accentTint
                WavePattern(opacity: 0.18)
            }
        }
    }
}

extension EmptyStateCard where Action == EmptyView {
    init(icon: String, title: String, message: String, variant: Variant = .default) {
        self.init(icon: icon, title: title, message: message, variant: variant, action: { EmptyView() })
    }
}
#endif
