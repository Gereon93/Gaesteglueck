import Testing
import Foundation
@testable import Gaesteglueck

@Suite("CanvasLabel Model")
struct CanvasLabelTests {
    @Test("Init with text and default position")
    func defaultInit() {
        let label = CanvasLabel(text: "Eingang")
        #expect(label.text == "Eingang")
        #expect(label.positionX == 0)
        #expect(label.positionY == 0)
        #expect(label.rotation == 0)
    }

    @Test("Init with explicit position and rotation")
    func explicitInit() {
        let label = CanvasLabel(text: "DJ", positionX: 100, positionY: 200, rotation: 90)
        #expect(label.positionX == 100)
        #expect(label.positionY == 200)
        #expect(label.rotation == 90)
    }
}
