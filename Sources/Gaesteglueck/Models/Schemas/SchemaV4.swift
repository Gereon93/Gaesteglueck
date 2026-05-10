#if canImport(SwiftData)
import Foundation
import SwiftData

enum SchemaV4: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(4, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Event.self,
            Guest.self,
            GuestTable.self,
            Tag.self,
            Constraint.self,
            RoomPlan.self,
            TableInventoryItem.self,
            CanvasLabel.self,
        ]
    }
}
#endif
