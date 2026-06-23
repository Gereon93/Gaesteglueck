#if canImport(SwiftUI)
import SwiftUI

/// Reine Geometrie zur Auflösung der Namens-Seite eines Sitzes — ohne UI,
/// damit testbar. `.auto` leitet aus der nächstgelegenen Tischkante ab
/// (normiert auf die Tisch-Halbmaße, damit Eck-Sitze breiter Tische als
/// Oben/Unten zählen, nicht fälschlich als Links/Rechts).
enum TableCanvasSeatSideLogic {
    static func resolvedNameSide(
        override: SeatNameSide,
        localX: CGFloat,
        localY: CGFloat,
        halfWidth: CGFloat,
        halfDepth: CGFloat
    ) -> SeatNameSide {
        if override != .auto { return override }
        let nx = localX / max(halfWidth, 1)
        let ny = localY / max(halfDepth, 1)
        if abs(ny) >= abs(nx) {
            return ny < 0 ? .top : .bottom
        } else {
            return nx < 0 ? .left : .right
        }
    }
}
#endif
