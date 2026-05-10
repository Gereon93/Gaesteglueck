import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class CanvasLabel {
    var id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var event: Event?

    init(
        text: String,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0
    ) {
        self.id = UUID()
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.event = nil
    }
}
