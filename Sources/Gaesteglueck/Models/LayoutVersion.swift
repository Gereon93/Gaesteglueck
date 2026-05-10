import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class LayoutVersion {
    var id: UUID
    var name: String
    var note: String
    var createdAt: Date
    var event: Event?
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutTableSnapshot.version)
    #endif
    var tables: [LayoutTableSnapshot] = []
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutLabelSnapshot.version)
    #endif
    var labels: [LayoutLabelSnapshot] = []
    #if canImport(SwiftData)
    @Relationship(deleteRule: .cascade, inverse: \LayoutSeatSnapshot.version)
    #endif
    var seats: [LayoutSeatSnapshot] = []

    init(name: String, note: String = "") {
        self.id = UUID()
        self.name = name
        self.note = note
        self.createdAt = .now
        self.event = nil
    }
}

#if canImport(SwiftData)
@Model
#endif
final class LayoutTableSnapshot {
    var id: UUID
    var name: String
    var shape: TableShape
    var diameter: Double
    var width: Double
    var depth: Double
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var isChildTable: Bool
    var isBridalTable: Bool
    var combinationGroup: UUID?
    var combinationOrder: Int?
    var disabledSeatIndicesData: Data?
    var version: LayoutVersion?

    init(
        id: UUID,
        name: String,
        shape: TableShape,
        diameter: Double,
        width: Double,
        depth: Double,
        positionX: Double,
        positionY: Double,
        rotation: Double,
        isChildTable: Bool,
        isBridalTable: Bool,
        combinationGroup: UUID?,
        combinationOrder: Int?,
        disabledSeatIndicesData: Data?
    ) {
        self.id = id
        self.name = name
        self.shape = shape
        self.diameter = diameter
        self.width = width
        self.depth = depth
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.isChildTable = isChildTable
        self.isBridalTable = isBridalTable
        self.combinationGroup = combinationGroup
        self.combinationOrder = combinationOrder
        self.disabledSeatIndicesData = disabledSeatIndicesData
        self.version = nil
    }
}

#if canImport(SwiftData)
@Model
#endif
final class LayoutLabelSnapshot {
    var id: UUID
    var text: String
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var version: LayoutVersion?

    init(id: UUID, text: String, positionX: Double, positionY: Double, rotation: Double) {
        self.id = id
        self.text = text
        self.positionX = positionX
        self.positionY = positionY
        self.rotation = rotation
        self.version = nil
    }
}

#if canImport(SwiftData)
@Model
#endif
final class LayoutSeatSnapshot {
    var id: UUID
    var guestID: UUID
    var tableID: UUID
    var seatIndex: Int?
    var version: LayoutVersion?

    init(guestID: UUID, tableID: UUID, seatIndex: Int?) {
        self.id = UUID()
        self.guestID = guestID
        self.tableID = tableID
        self.seatIndex = seatIndex
        self.version = nil
    }
}
