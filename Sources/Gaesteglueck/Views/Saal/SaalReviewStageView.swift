#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// Review-Phase: KI-Vorschlag prüfen und ggf. neu rechnen lassen.
struct SaalReviewStageView: View {
    let proposal: SaalProposal
    let onRecompute: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(proposal.tables.count) Tische empfohlen · \(proposal.totalCapacity) Plätze")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if !proposal.reasoning.isEmpty {
                    Text(proposal.reasoning)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Button("Neu rechnen") {
                onRecompute()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12.5, design: .rounded))
            .foregroundStyle(Tokens.Colors.accent)
        }

        ForEach(proposal.tables) { table in
            ProposedTableCard(table: table)
        }
    }
}
#endif
