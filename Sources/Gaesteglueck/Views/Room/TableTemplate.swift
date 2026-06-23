#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Template

struct TableTemplate: Identifiable {
    let id = UUID()
    let shape: TableShape
    let diameter: Double
    let width: Double
    let depth: Double
    let capacity: Int
    let name: String
    let size: String
    let hint: String
    let isBridal: Bool
}

extension TableTemplate {
    /// Tisch-Vorlagen-Bibliothek (siehe S6a). Wird von der Bibliothek links,
    /// dem Inventar-Stepper und dem Auto-Vorschlag gemeinsam genutzt.
    static let all: [TableTemplate] = [
        .init(shape: .round, diameter: 160, width: 0, depth: 0, capacity: 8, name: "Rund · 8 Plätze", size: "160 cm Ø", hint: "Klassisch", isBridal: false),
        .init(shape: .round, diameter: 130, width: 0, depth: 0, capacity: 6, name: "Rund · 6 Plätze", size: "130 cm Ø", hint: "Familienkreis", isBridal: false),
        .init(shape: .round, diameter: 180, width: 0, depth: 0, capacity: 10, name: "Rund · 10 Plätze", size: "180 cm Ø", hint: "Großtisch", isBridal: false),
        .init(shape: .rectangular, diameter: 0, width: 320, depth: 90, capacity: 10, name: "Brauttafel · 10 Plätze", size: "320 × 90 cm", hint: "Brautpaar + Trauzeugen", isBridal: true),
        .init(shape: .rectangular, diameter: 0, width: 420, depth: 90, capacity: 14, name: "Lange Tafel · 14", size: "420 × 90 cm", hint: "Familie", isBridal: false),
        .init(shape: .square, diameter: 0, width: 100, depth: 100, capacity: 4, name: "Quadrat · 4 Plätze", size: "100 × 100 cm", hint: "Kinder", isBridal: false),
    ]
}
#endif
