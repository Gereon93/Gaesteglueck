import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
final class Relationship {
    var id: UUID
    var personAID: UUID
    var personBID: UUID
    var type: RelationshipType
    var notes: String

    init(personAID: UUID, personBID: UUID, type: RelationshipType, notes: String = "") {
        self.id = UUID()
        self.personAID = personAID
        self.personBID = personBID
        self.type = type
        self.notes = notes
    }

    func involves(_ personID: UUID) -> Bool {
        personAID == personID || personBID == personID
    }

    func otherPerson(than personID: UUID) -> UUID? {
        if personAID == personID { return personBID }
        if personBID == personID { return personAID }
        return nil
    }
}
