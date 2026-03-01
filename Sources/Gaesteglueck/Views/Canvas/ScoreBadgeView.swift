#if canImport(SwiftUI)
import SwiftUI

struct ScoreBadgeView: View {
    let score: Double

    private var emoji: String {
        switch score {
        case ..<0: "😟"
        case 0..<50: "😐"
        case 50..<100: "🙂"
        default: "😄"
        }
    }

    private var color: Color {
        switch score {
        case ..<0: .red
        case 0..<50: .orange
        case 50..<100: .yellow
        default: .green
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(emoji)
            Text("\(Int(score))")
                .font(.title3.bold().monospacedDigit())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15), in: Capsule())
    }
}
#endif
