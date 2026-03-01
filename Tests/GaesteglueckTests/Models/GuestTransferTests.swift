import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Transfer")
struct GuestTransferTests {
    @Test("Guest UUID string roundtrips correctly")
    func uuidRoundtrip() {
        let id = UUID()
        let string = id.uuidString
        let restored = UUID(uuidString: string)
        #expect(restored == id)
    }
}
