import Testing
@testable import Gaesteglueck

@Suite("Gaesteglueck")
struct GaesteglueckTests {
    @Test("Package is set up correctly")
    func packageSetup() {
        #expect(true)
    }
}
