#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// Karte für einen einzelnen von der KI vorgeschlagenen Tisch.
struct ProposedTableCard: View {
    let table: ProposedTable

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                shapeBadge
                VStack(alignment: .leading, spacing: 2) {
                    Text(table.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    Text(sizeLine)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                Spacer()
                Text("\(table.capacity) Pl.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Tokens.Colors.accentSoft)
                    .clipShape(Capsule())
                if table.isBridal {
                    Image(systemName: "heart.fill").foregroundStyle(Tokens.Colors.accent)
                }
                if table.isChild {
                    Image(systemName: "figure.child").foregroundStyle(Tokens.Colors.ink2)
                }
            }
            if !table.reason.isEmpty {
                Text(table.reason)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !table.clusters.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Text(table.clusters.joined(separator: " · "))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Tokens.Colors.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var shapeBadge: some View {
        Group {
            switch table.shape {
            case .round:
                Circle().fill(Tokens.Colors.accentTint)
                    .overlay(Circle().strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.2))
            case .rectangular:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Tokens.Colors.accentTint)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.2))
                    .frame(width: 36, height: 18)
            case .square:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Tokens.Colors.accentTint)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.2))
            }
        }
        .frame(width: 26, height: 26)
    }

    private var sizeLine: String {
        switch table.shape {
        case .round: return "\(Int(table.diameterCM)) cm Ø"
        case .rectangular: return "\(Int(table.widthCM))×\(Int(table.depthCM)) cm"
        case .square: return "\(Int(table.widthCM))×\(Int(table.widthCM)) cm"
        }
    }
}
#endif
