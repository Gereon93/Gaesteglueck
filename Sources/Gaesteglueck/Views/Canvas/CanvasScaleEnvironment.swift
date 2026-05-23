#if canImport(SwiftUI)
import SwiftUI

private struct CanvasScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0 / 3.0
}

private struct SeatDisplayNamesKey: EnvironmentKey {
    static let defaultValue: [UUID: String] = [:]
}

private struct SeatingLegendKey: EnvironmentKey {
    static let defaultValue: SeatingLegend = SeatingLegend(guests: [])
}

extension EnvironmentValues {
    var canvasScale: CGFloat {
        get { self[CanvasScaleKey.self] }
        set { self[CanvasScaleKey.self] = newValue }
    }

    /// Vorberechnete Anzeige-Namen pro Gast-ID gemäß gewähltem Namen-Stil.
    /// Leer = jeder Sitz nutzt den vollen Namen als Fallback.
    var seatDisplayNames: [UUID: String] {
        get { self[SeatDisplayNamesKey.self] }
        set { self[SeatDisplayNamesKey.self] = newValue }
    }

    /// Globale Nummerierung aller Unverträglichkeiten — Sitz-Chips zeigen
    /// die Nummer, die Canvas-Legende löst Nr → Allergen auf.
    var seatingLegend: SeatingLegend {
        get { self[SeatingLegendKey.self] }
        set { self[SeatingLegendKey.self] = newValue }
    }
}
#endif
