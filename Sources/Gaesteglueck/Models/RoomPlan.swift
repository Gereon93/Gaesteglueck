import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class RoomPlan {
    var id: UUID
    var imageData: Data?
    var scalePointAX: Double?
    var scalePointAY: Double?
    var scalePointBX: Double?
    var scalePointBY: Double?
    var scaleRealWorldCM: Double?
    var roomWidthCM: Double?
    var roomDepthCM: Double?

    var pixelsToCM: Double? {
        guard let ax = scalePointAX, let ay = scalePointAY,
              let bx = scalePointBX, let by = scalePointBY,
              let realCM = scaleRealWorldCM else { return nil }
        let pixelDistance = sqrt(pow(bx - ax, 2) + pow(by - ay, 2))
        guard pixelDistance > 0 else { return nil }
        return realCM / pixelDistance
    }

    init() {
        self.id = UUID()
    }
}
