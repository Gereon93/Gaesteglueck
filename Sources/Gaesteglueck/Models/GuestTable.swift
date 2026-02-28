import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class GuestTable {
    var id: UUID
    var name: String
    var shape: TableShape
    var diameter: Double
    var width: Double
    var depth: Double
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var isLocked: Bool
    var linkedTableID: UUID?
    var guests: [Guest]

    var capacity: Int {
        let seatWidth: Double = 60
        switch shape {
        case .round:
            let circumference = Double.pi * diameter
            return Int(circumference / seatWidth)
        case .rectangular:
            let perimeter = 2 * (width + depth)
            let rawSeats = Int(perimeter / seatWidth)
            return max(rawSeats - 2, 4)
        case .brideTable:
            return Int(width / seatWidth)
        }
    }

    func combinedCapacity(with other: GuestTable) -> Int {
        guard shape == .rectangular, other.shape == .rectangular else {
            return capacity + other.capacity
        }
        let seatWidth: Double = 60
        let totalWidth = width + other.width
        let longSideSeats = Int(totalWidth / seatWidth) * 2
        let shortSideSeats = Int(depth / seatWidth) * 2
        return longSideSeats + shortSideSeats
    }

    var remainingSeats: Int { capacity - guests.count }
    var isFull: Bool { guests.count >= capacity }

    init(
        name: String,
        shape: TableShape,
        diameter: Double = 180,
        width: Double = 200,
        depth: Double = 100,
        positionX: Double = 0,
        positionY: Double = 0,
        rotation: Double = 0
    ) {
        self.id = UUID()
        self.name = name
        self.shape = shape
        self.diameter = diameter
        self.width = width
        self.depth = depth
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.isLocked = false
        self.linkedTableID = nil
        self.guests = []
    }
}
