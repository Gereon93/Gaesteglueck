import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class TableInventoryItem {
    var id: UUID
    var shape: TableShape
    var width: Double
    var depth: Double
    var diameter: Double
    var availableCount: Int
    var label: String

    init(
        shape: TableShape,
        width: Double = 200,
        depth: Double = 100,
        diameter: Double = 180,
        availableCount: Int = 1,
        label: String = ""
    ) {
        self.id = UUID()
        self.shape = shape
        self.width = width
        self.depth = depth
        self.diameter = diameter
        self.availableCount = availableCount
        self.label = label.isEmpty ? "\(shape.rawValue) \(Int(shape == .round ? diameter : width))cm" : label
    }
}
