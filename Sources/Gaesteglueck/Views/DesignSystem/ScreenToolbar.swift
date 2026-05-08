#if canImport(SwiftUI)
import SwiftUI

/// Konsistente Top-Toolbar für alle Hauptansichten — Title (18pt semibold,
/// -0.3 tracking, design displayS-ish) + optionaler Subtitle (12.5pt ink-3)
/// links, beliebig viele Actions rechts. Hairline-Bottom in `Tokens.Colors.line`.
/// Hintergrund ist `Tokens.Colors.bg` (warm parchment, kein Liquid Glass —
/// Glass bleibt der Sidebar vorbehalten).
struct ScreenToolbar<Actions: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var actions: () -> Actions

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .tracking(-0.3)
                        .foregroundStyle(Tokens.Colors.ink)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    actions()
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .background(Tokens.Colors.bg)

            Rectangle()
                .fill(Tokens.Colors.line)
                .frame(height: 1)
        }
    }
}

extension ScreenToolbar where Actions == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, actions: { EmptyView() })
    }
}
#endif
