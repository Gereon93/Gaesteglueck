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
                        VStack(alignment: .leading, spacing: 2) {
                            Text(violation.description)
                                .font(.caption)
                            let names = violation.guestIDs.compactMap { id in
                                allGuests.first { $0.id == id }?.fullName
                            }
                            if !names.isEmpty {
                                Text(names.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}
#endif
