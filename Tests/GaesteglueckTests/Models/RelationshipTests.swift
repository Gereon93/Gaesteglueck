import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Relationship Model")
struct RelationshipTests {
    @Test("Partner relationship has weight 1.0")
    func partnerWeight() {
        let rel = Relationship(personAID: UUID(), personBID: UUID(), type: .partner)
        #expect(rel.type.weight == 1.0)
    }

    @Test("Toxic relationship has negative weight")
    func toxicWeight() {
        let rel = Relationship(personAID: UUID(), personBID: UUID(), type: .toxic)
        #expect(rel.type.weight < 0)
    }

    @Test("Family relationship weight")
    func familyWeight() {
        #expect(RelationshipType.family.weight == 0.7)
    }

    @Test("Friend cluster weight")
    func friendWeight() {
        #expect(RelationshipType.friend.weight == 0.4)
    }

    @Test("Relationship is bidirectional check")
    func bidirectional() {
        let a = UUID()
        let b = UUID()
        let rel = Relationship(personAID: a, personBID: b, type: .partner)
        #expect(rel.involves(a))
        #expect(rel.involves(b))
        #expect(!rel.involves(UUID()))
    }
}
