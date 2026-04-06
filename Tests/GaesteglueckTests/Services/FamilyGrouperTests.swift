import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Family Grouper")
struct FamilyGrouperTests {
    @Test("Groups guests by familyID")
    func groupsByFamily() {
        let familyID = UUID()
        let alice = Guest(firstName: "Alice", partnerAssignment: .partner1, familyID: familyID)
        let bob = Guest(firstName: "Bob", partnerAssignment: .partner1, familyID: familyID)
        let carol = Guest(firstName: "Carol", partnerAssignment: .partner2)

        let groups = FamilyGrouper.group([alice, bob, carol])
        #expect(groups.count == 2)
    }

    @Test("Family members listed together")
    func familyTogether() {
        let familyID = UUID()
        let alice = Guest(firstName: "Alice", partnerAssignment: .partner1, familyID: familyID)
        let bob = Guest(firstName: "Bob", partnerAssignment: .partner1, familyID: familyID)

        let groups = FamilyGrouper.group([alice, bob])
        #expect(groups.count == 1)
        #expect(groups[0].count == 2)
    }
}
