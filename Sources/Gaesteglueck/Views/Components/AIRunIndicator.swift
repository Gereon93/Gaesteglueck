#if canImport(SwiftUI)
import SwiftUI

struct AIRunIndicator: View {
    let title: String
    var detail: String? = nil
    var progress: (done: Int, total: Int)? = nil
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            if let p = progress, p.total > 0 {
                ProgressView(value: Double(p.done), total: Double(p.total))
                    .frame(width: 280)
                Text("\(p.done) / \(p.total) · \(max(0, p.total - p.done)) offen")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            } else if let detail {
                Text(detail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button("Abbrechen", role: .cancel, action: onCancel)
                .buttonStyle(.bordered)
        }
        .padding(28)
        .frame(width: 360)
    }
}

#endif
