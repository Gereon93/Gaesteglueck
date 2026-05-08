#if canImport(SwiftUI)
import SwiftUI

/// Warn-Banner für inline-Hinweise — Konflikte am Tisch, Allergien-Reminder,
/// Verstöße gegen Constraints. Drei Tönungen (warn/error/info) mit jeweils
/// eigenem Hintergrund + Border + Icon-Farbe.
struct ConflictBanner<Action: View>: View {
    enum Tone {
        case warn, error, info

        var background: Color {
            switch self {
            case .warn: Color(hex: "#fbf1e3")
            case .error: Color(hex: "#fbe6e6")
            case .info: Color(hex: "#eef3f8")
            }
        }
        var foreground: Color {
            switch self {
            case .warn: Color(hex: "#8b5a1f")
            case .error: Color(hex: "#8d3030")
            case .info: Color(hex: "#3d5878")
            }
        }
        var border: Color {
            switch self {
            case .warn: Color(hex: "#ecdab9")
            case .error: Color(hex: "#f0cccc")
            case .info: Color(hex: "#d4dde8")
            }
        }
        var icon: String {
            switch self {
            case .warn, .error: "exclamationmark.triangle.fill"
            case .info: "info.circle.fill"
            }
        }
    }

    let title: String
    var message: String? = nil
    var tone: Tone = .warn
    @ViewBuilder var action: () -> Action

    init(
        title: String,
        message: String? = nil,
        tone: Tone = .warn,
        @ViewBuilder action: @escaping () -> Action
    ) {
        self.title = title
        self.message = message
        self.tone = tone
        self.action = action
    }

    var body: some View {
        bannerBody
    }

    private var bannerBody: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: tone.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tone.foreground)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(tone.foreground)
                if let message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(tone.foreground.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            action()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(tone.background)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(tone.border, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }
}

extension ConflictBanner where Action == EmptyView {
    init(title: String, message: String? = nil, tone: Tone = .warn) {
        self.init(title: title, message: message, tone: tone, action: { EmptyView() })
    }
}
#endif
