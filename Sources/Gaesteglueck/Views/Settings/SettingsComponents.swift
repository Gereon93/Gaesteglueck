#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
    }
}

// MARK: - Settings Row

struct SettingsRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .frame(width: 200, alignment: .leading)
            trailing()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }
}

// MARK: - Toggle

struct GGToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? Tokens.Colors.accent : Tokens.Colors.bg3)
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
    }
}
#endif
