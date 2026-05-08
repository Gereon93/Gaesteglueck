#if canImport(SwiftData)
import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Event.self,
            Guest.self,
            GuestTable.self,
            Tag.self,
            Constraint.self,
            RoomPlan.self,
            TableInventoryItem.self,
        ]
    }
}
#endif
