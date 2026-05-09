#if canImport(SwiftUI)
import SwiftUI

enum SeatLayout {
    static let seatGap: CGFloat = 14

    static func positions(
        shape: TableShape,
        capacity: Int,
        scaledDiameter: CGFloat,
        scaledWidth: CGFloat,
        scaledDepth: CGFloat
    ) -> [CGPoint] {
        guard capacity > 0 else { return [] }
        switch shape {
        case .round:
            return roundPositions(capacity: capacity, scaledDiameter: scaledDiameter)
        case .rectangular:
            return rectPositions(capacity: capacity, w: scaledWidth, d: scaledDepth)
        case .square:
            return rectPositions(capacity: capacity, w: scaledWidth, d: scaledWidth)
        }
    }

    private static func roundPositions(capacity: Int, scaledDiameter: CGFloat) -> [CGPoint] {
        let radius = scaledDiameter / 2 + seatGap
        var result: [CGPoint] = []
        let startAngle = -CGFloat.pi / 2
        for i in 0..<capacity {
            let angle = startAngle + 2 * .pi * CGFloat(i) / CGFloat(capacity)
            result.append(CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
        }
        return result
    }

    /// Verteilung an Rechtecken: Lange Seiten (Breite) zuerst, kurze Seiten
    /// (Tiefe) bekommen je 1 Stuhl wenn Kapazität ungerade oder >= 6.
    private static func rectPositions(capacity: Int, w: CGFloat, d: CGFloat) -> [CGPoint] {
        guard capacity > 0 else { return [] }
        // Endsitze: 0 für sehr kleine Tafeln, sonst je 1 (links/rechts)
        let endSeatCount: Int = capacity >= 4 ? 2 : 0
        let sideSeats = capacity - endSeatCount
        let topCount = sideSeats / 2 + (sideSeats % 2)
        let bottomCount = sideSeats / 2
        var result: [CGPoint] = []

        // Top
        for i in 0..<topCount {
            let denom = max(topCount, 1)
            let x = -w/2 + (CGFloat(i) + 0.5) * (w / CGFloat(denom))
            result.append(CGPoint(x: x, y: -d/2 - seatGap))
        }
        // Bottom
        for i in 0..<bottomCount {
            let denom = max(bottomCount, 1)
            let x = -w/2 + (CGFloat(i) + 0.5) * (w / CGFloat(denom))
            result.append(CGPoint(x: x, y: d/2 + seatGap))
        }
        // Ends — links zuerst, dann rechts
        if endSeatCount >= 1 {
            result.append(CGPoint(x: -w/2 - seatGap, y: 0))
        }
        if endSeatCount >= 2 {
            result.append(CGPoint(x: w/2 + seatGap, y: 0))
        }
        return result
    }
}
#endif
