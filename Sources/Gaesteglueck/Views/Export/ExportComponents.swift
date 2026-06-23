#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData
import AppKit

// MARK: - Checkrow / Radio

struct CheckRow: View {
    let label: String
    let hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isOn ? Tokens.Colors.accent : Tokens.Colors.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(isOn ? Tokens.Colors.accent : Tokens.Colors.line2, lineWidth: 1.5)
                        }
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 16, height: 16)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    if let hint {
                        Text(hint)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

struct RadioRow: View {
    let label: String
    let subtitle: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Tokens.Colors.surface)
                        .overlay {
                            Circle().strokeBorder(isActive ? Tokens.Colors.accent : Tokens.Colors.line2, lineWidth: 1.5)
                        }
                    if isActive {
                        Circle()
                            .fill(Tokens.Colors.accent)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 16, height: 16)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? Tokens.Colors.accentTint : Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isActive ? Tokens.Colors.accent : Tokens.Colors.line, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
#endif
#endif
