#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// Wiederverwendbare Leaf-Bausteine für den Saal-Konfigurator.

struct SaalStatBlock: View {
    let label: String
    let value: String
    var accent: Color = Tokens.Colors.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
            Text(value)
                .font(Tokens.Typography.display(size: 22))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Tokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SaalConfigRow<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Tokens.Colors.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct SaalStepperField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, design: .rounded)).foregroundStyle(Tokens.Colors.ink3)
            HStack(spacing: 6) {
                TextField("0", value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Stepper("", value: $value, in: range)
                    .labelsHidden()
            }
        }
    }
}

struct SaalDoubleField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, design: .rounded)).foregroundStyle(Tokens.Colors.ink3)
            TextField("0", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .font(.system(size: 12.5, design: .rounded))
        }
    }
}

struct SaalErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tokens.Colors.warn)
            Text(message)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.warn.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
#endif
