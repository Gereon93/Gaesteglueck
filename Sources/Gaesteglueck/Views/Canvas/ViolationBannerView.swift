#if canImport(SwiftUI)
import SwiftUI

struct ViolationBannerView: View {
    let violations: [Violation]
    let allGuests: [Guest]

    var body: some View {
        if !violations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(violations) { violation in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(violationText(violation))
                            .font(.caption)
                    }
                }
            }
            .padding(8)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func violationText(_ v: Violation) -> String {
        let nameA = allGuests.first { $0.id == v.personAID }?.name ?? "?"
        let nameB = allGuests.first { $0.id == v.personBID }?.name ?? "?"
        switch v.type {
        case .partnersSeparated:
            return "\(nameA) & \(nameB) sind getrennt!"
        case .toxicAtSameTable:
            return "\(nameA) & \(nameB) sitzen am selben Tisch!"
        case .tableOverCapacity:
            return "Tisch überbelegt"
        }
    }
}
#endif
