import Testing
import Foundation
@testable import Gaesteglueck

@Suite("GroupAnalyzer")
struct GroupAnalyzerTests {
    @Test("Detect clusters from tags")
    func detectClusters() {
        let guest1 = Guest(firstName: "Alice")
        let guest2 = Guest(firstName: "Bob")
        let guest3 = Guest(firstName: "Charlie")
        let guest4 = Guest(firstName: "Diana")

        let tag1 = Tag(name: "Studienfreunde", category: .friendGroup)
        tag1.guestIDs = [guest1.id, guest2.id, guest3.id]

        let tag2 = Tag(name: "Arbeitskollegen", category: .work)
        tag2.guestIDs = [guest4.id]

        let clusters = GroupAnalyzer.detectClusters(guests: [guest1, guest2, guest3, guest4], tags: [tag1, tag2])
        #expect(clusters.count == 2)
        let large = clusters.first { $0.guestIDs.count == 3 }
        #expect(large != nil)
        #expect(large?.tagName == "Studienfreunde")
    }

    @Test("Find bridge persons")
    func findBridgePersons() {
        let guest1 = Guest(firstName: "Alice")
        let tag1 = Tag(name: "Studienfreunde", category: .friendGroup)
        tag1.guestIDs = [guest1.id, UUID()]
        let tag2 = Tag(name: "Siemens", category: .work)
        tag2.guestIDs = [guest1.id, UUID()]

        let bridges = GroupAnalyzer.findBridgePersons(guests: [guest1], tags: [tag1, tag2])
        #expect(bridges.count == 1)
        #expect(bridges[0].guestID == guest1.id)
        #expect(bridges[0].sharedTags.count == 2)
    }

    @Test("Build LLM context")
    func buildContext() {
        let guest = Guest(firstName: "Test", lastName: "User", partnerAssignment: .partner1)
        let tag = Tag(name: "WG", category: .friendGroup, partnerAssignment: .partner1)
        tag.guestIDs = [guest.id]
        let context = GroupAnalyzer.buildLLMContext(guests: [guest], tags: [tag], constraints: [], tables: [])
        #expect(context.contains("Test User"))
        #expect(context.contains("WG"))
    }
}
