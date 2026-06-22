#if canImport(SwiftUI)
import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

// MARK: - FunFact-Review

struct FunFactReviewSheet: View {
    let proposals: [FunFactNormalizer.Result]
    @Binding var selection: Set<UUID>
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var costLine: String {
        let t = LLMCostEstimator.funfactBatchTokens(texts: proposals.map(\.original))
        let pricePerM = LLMClientFactory.effectiveOpenRouterPricePerM(for: .funfact)
        guard pricePerM > 0 else {
            return "Lokal (LM Studio) — kostenlos · ~\(t.prompt + t.completion) Tokens"
        }
        let usd = LLMCostEstimator.usd(
            promptTokens: t.prompt, completionTokens: t.completion,
            blendedUSDPerMillion: pricePerM
        )
        return "Geschätzte Kosten dieses Laufs: \(LLMCostEstimator.format(usd: usd)) (OpenRouter)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("FunFacts vereinheitlichen")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Text("\(selection.count)/\(proposals.count) ausgewählt")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            Text(costLine)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(proposals) { p in
                        Button {
                            if selection.contains(p.guestID) { selection.remove(p.guestID) }
                            else { selection.insert(p.guestID) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: selection.contains(p.guestID)
                                      ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(selection.contains(p.guestID) ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(p.original)
                                        .font(.system(size: 12, design: .rounded))
                                        .foregroundStyle(.secondary)
                                        .strikethrough()
                                    Text(p.normalized)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            Divider()
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Ausgewählte übernehmen") { onApply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selection.isEmpty)
            }
            .padding(16)
        }
        .frame(width: 620, height: 560)
    }
}

// MARK: - Simple flow layout for tag chips

struct ChipFlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if rowWidth + s.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width.isFinite ? width : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

/// Drag-Handle zwischen Tabellen-Spalten. Liegt visuell unsichtbar (transparenter
/// Hit-Bereich, dünne Linie als Indikator), zeigt resize-Cursor beim Hover und
/// verstellt per Drag die gebundene Breite — clamped auf [minWidth, maxWidth].
struct ColumnResizeHandle: View {
    @Binding var width: Double
    let minWidth: Double
    let maxWidth: Double
    @State private var startWidth: Double? = nil

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(width: 6)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .fill(Tokens.Colors.line2)
                    .frame(width: 1)
                    .opacity(0.5)
            )
            #if os(macOS)
            .onHover { inside in
                if inside {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            #endif
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if startWidth == nil { startWidth = width }
                        let proposed = (startWidth ?? width) + Double(value.translation.width)
                        width = Swift.max(minWidth, Swift.min(maxWidth, proposed))
                    }
                    .onEnded { _ in startWidth = nil }
            )
    }
}
#endif
