import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Family Grouper")
struct FamilyGrouperTests {
    @Test("Groups guests by familyID")
    func groupsByFamily() {
        let familyID = UUID()
        let alice = Guest(name: "Alice", side: .bride, familyID: familyID)
        let bob = Guest(name: "Bob", side: .bride, familyID: familyID)
        let carol = Guest(name: "Carol", side: .groom)

        let groups = FamilyGrouper.group([alice, bob, carol])
        #expect(groups.count == 2)
    }

    @Test("Family members listed together")
    func familyTogether() {
        let familyID = UUID()
        let alice = Guest(name: "Alice", side: .bride, familyID: familyID)
        let bob = Guest(name: "Bob", side: .bride, familyID: familyID)

        let groups = FamilyGrouper.group([alice, bob])
        #expect(groups.count == 1)
        #expect(groups[0].count == 2)
    }

    @Test("Separated families detected")
    func separatedFamilies() {
        let familyID = UUID()
        let alice = Guest(name: "Alice", side: .bride, familyID: familyID)
        let bob = Guest(name: "Bob", side: .bride, familyID: familyID)
        let t1 = GuestTable(name: "T1", shape: .round)
        let t2 = GuestTable(name: "T2", shape: .round)
        t1.guests = [alice]
        t2.guests = [bob]

        let separated = FamilyGrouper.findSeparatedFamilies(tables: [t1, t2], guests: [alice, bob])
        #expect(!separated.isEmpty)
    }
}
