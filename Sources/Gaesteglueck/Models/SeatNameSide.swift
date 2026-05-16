import Foundation

/// Auf welcher Seite eines Sitzes der Gast-Name (bei "Namen einblenden")
/// gezeichnet wird. `.auto` = pro Sitz aus der Tischkante abgeleitet
/// (Sitz oben → Name oben, usw.). Die expliziten Werte zwingen ALLE Namen
/// des Tisches auf eine Seite — nützlich um z.B. bei nebeneinander stehenden
/// Längstischen alle Namen in den freien Gang nach außen zu schieben.
enum SeatNameSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case top = "Oben"
    case bottom = "Unten"
    case left = "Links"
    case right = "Rechts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .auto: "wand.and.stars"
        case .top: "arrow.up"
        case .bottom: "arrow.down"
        case .left: "arrow.left"
        case .right: "arrow.right"
        }
    }

    /// Einheitsvektor im Tisch-lokalen (nicht rotierten) Koordinatensystem.
    /// `.auto` hat keinen festen Vektor (wird pro Sitz aufgelöst).
    var localUnitVector: CGVector {
        switch self {
        case .auto: CGVector(dx: 0, dy: -1)
        case .top: CGVector(dx: 0, dy: -1)
        case .bottom: CGVector(dx: 0, dy: 1)
        case .left: CGVector(dx: -1, dy: 0)
        case .right: CGVector(dx: 1, dy: 0)
        }
    }
}
