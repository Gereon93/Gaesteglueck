#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Recommendation Row

struct RecommendationRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Tokens.Colors.accentTint)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text(message)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Meter

struct DashboardMeter: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    private var percent: Double { total > 0 ? Double(count) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Tokens.Colors.bg2)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(2, geo.size.width * percent), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
#endif
