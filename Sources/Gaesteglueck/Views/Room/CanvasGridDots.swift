#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Grid

struct CanvasGridDots: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let dot = Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1))
                    context.fill(dot, with: .color(Color.black.opacity(0.05)))
                    y += step
                }
                x += step
            }
        }
    }
}
#endif
