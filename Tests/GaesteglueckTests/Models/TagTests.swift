import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Tag Model")
struct TagTests {
    @Test("Tag creation with defaults")
    func tagCreation() {
        let tag = Tag(name: "Studienfreunde Maria", category: .friendGroup)
        #expect(tag.name == "Studienfreunde Maria")
        #expect(tag.category == .friendGroup)
        #expect(tag.color == TagCategory.friendGroup.defaultColor)
        #expect(tag.guestIDs.isEmpty)
    }

    @Test("Tag with custom color and partner")
    func tagWithCustomColor() {
        let tag = Tag(
            name: "JGA Gereon",
            category: .activity,
            color: "#FF5733",
            partnerAssignment: .partner1
        )
        #expect(tag.color == "#FF5733")
        #expect(tag.partnerAssignment == .partner1)
    }

    @Test("Add and remove guest IDs")
    func guestManagement() {
        let tag = Tag(name: "Test", category: .custom)
        let guestID = UUID()
        tag.guestIDs.append(guestID)
        #expect(tag.guestIDs.count == 1)
        #expect(tag.guestIDs.contains(guestID))
    }
}
