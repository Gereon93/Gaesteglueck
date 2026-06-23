#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Canvas Grid Background

struct CanvasGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Tokens.Colors.line), lineWidth: 1)
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Tokens.Colors.line), lineWidth: 1)
                y += step
            }
        }
        .background(Tokens.Colors.bg)
    }
}
#endif
