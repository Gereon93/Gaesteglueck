#if canImport(SwiftUI)
import SwiftUI

/// Signature-Wellenmuster aus dem Design-Brief. Drei sanfte Quadratic-Bezier
/// Wellen, gekachelt — wird hinter Hero-Sektionen, im Welcome-Screen, im
/// AI-Suggestion-Sheet und auf Print-Bögen gelegt. Default-Farbe ist
/// `Tokens.Colors.accent`. Zeichnen mit niedriger Opazität (0.3-0.5).
struct WavePattern: View {
    var color: Color = Tokens.Colors.accent
    var opacity: Double = 0.4
    var tileWidth: CGFloat = 240
    var tileHeight: CGFloat = 120

    var body: some View {
        Canvas { context, size in
            let cols = Int(ceil(size.width / tileWidth)) + 1
            let rows = Int(ceil(size.height / tileHeight)) + 1
            for r in 0..<rows {
                for c in 0..<cols {
                    let origin = CGPoint(
                        x: CGFloat(c) * tileWidth,
                        y: CGFloat(r) * tileHeight
                    )
                    drawWaves(context: context, origin: origin)
                }
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }

    private func drawWaves(context: GraphicsContext, origin: CGPoint) {
        // 3 Wellen pro Tile bei y = 30, 60, 90
        for yOffset: CGFloat in [30, 60, 90] {
            var path = Path()
            path.move(to: CGPoint(x: origin.x - 10, y: origin.y + yOffset))
            // Quadratic curves: -10→70→150→230→310 mit control points bei 30,70,...
            // Vereinfacht: smooth Schwingung über die Kachelbreite
            var x: CGFloat = origin.x - 10
            let cycleWidth: CGFloat = 80
            while x < origin.x + tileWidth + 10 {
                let cpx = x + cycleWidth / 2
                let cpy = origin.y + yOffset - 20
                let endX = x + cycleWidth
                let endY = origin.y + yOffset
                path.addQuadCurve(
                    to: CGPoint(x: endX, y: endY),
                    control: CGPoint(x: cpx, y: cpy)
                )
                x += cycleWidth
                // Spiegeln für gegenlaufende Welle
                let cpx2 = x + cycleWidth / 2
                let cpy2 = origin.y + yOffset + 20
                let endX2 = x + cycleWidth
                let endY2 = origin.y + yOffset
                path.addQuadCurve(
                    to: CGPoint(x: endX2, y: endY2),
                    control: CGPoint(x: cpx2, y: cpy2)
                )
                x += cycleWidth
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.1, lineCap: .round)
            )
        }
    }
}
#endif
