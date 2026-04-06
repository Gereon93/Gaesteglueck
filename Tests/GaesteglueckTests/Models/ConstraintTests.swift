import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Constraint Model")
struct ConstraintTests {
    @Test("Must sit together constraint")
    func mustSitTogether() {
        let idA = UUID()
        let idB = UUID()
        let constraint = Constraint(
            type: .mustSitTogether,
            guestIDs: [idA, idB],
            reason: "Ehepaar"
        )
        #expect(constraint.type == .mustSitTogether)
        #expect(constraint.guestIDs.count == 2)
        #expect(constraint.involves(idA))
        #expect(constraint.involves(idB))
        #expect(!constraint.involves(UUID()))
    }

    @Test("Must not sit together constraint")
    func mustNotSitTogether() {
        let constraint = Constraint(
            type: .mustNotSitTogether,
            guestIDs: [UUID(), UUID()],
            reason: "Konflikt"
        )
        #expect(constraint.type == .mustNotSitTogether)
        #expect(constraint.reason == "Konflikt")
    }
}
