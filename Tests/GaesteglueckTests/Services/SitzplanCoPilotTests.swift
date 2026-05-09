#if canImport(Testing)
import Foundation
import Testing
@testable import Gaesteglueck

@Suite("Sitzplan Co-Pilot")
struct SitzplanCoPilotTests {
    private let pilot = SitzplanCoPilot(client: LMStudioClient(endpoint: "http://localhost:1234"))

    @Test("Plain JSON parses text + actions")
    func plainJSON() {
        let raw = """
        {"text": "Patrick verschoben", "actions": [{"type": "moveGuest", "guestName": "Patrick Nowak", "toTable": "T2"}]}
        """
        let response = pilot.parseResponse(raw)
        #expect(response.text == "Patrick verschoben")
        #expect(response.actions.count == 1)
        if case .moveGuest(let name, let table) = response.actions[0] {
            #expect(name == "Patrick Nowak")
            #expect(table == "T2")
        } else {
            Issue.record("Expected moveGuest action")
        }
    }

    @Test("JSON with prosa around it still parses")
    func jsonInProsa() {
        let raw = """
        Hier ist die Antwort:
        {"text": "ok", "actions": []}
        Bis später!
        """
        let response = pilot.parseResponse(raw)
        #expect(response.text == "ok")
        #expect(response.actions.isEmpty)
    }

    @Test("Invalid JSON falls back to raw text")
    func invalidJSON() {
        let raw = "Das ist nur Text, kein JSON"
        let response = pilot.parseResponse(raw)
        #expect(response.text == raw)
        #expect(response.actions.isEmpty)
    }

    @Test("Unknown action types are silently dropped")
    func unknownActionType() {
        let raw = """
        {"text": "ok", "actions": [{"type": "explode", "guestName": "X"}, {"type": "moveGuest", "guestName": "A", "toTable": "T1"}]}
        """
        let response = pilot.parseResponse(raw)
        #expect(response.actions.count == 1)
    }

    @Test("Action type matching is case-insensitive")
    func caseInsensitive() {
        let raw = """
        {"text": "", "actions": [{"type": "MOVEGUEST", "guestName": "A", "toTable": "T1"}, {"type": "SwapGuests", "guestA": "X", "guestB": "Y"}]}
        """
        let response = pilot.parseResponse(raw)
        #expect(response.actions.count == 2)
    }

    @Test("swapGuests with missing field is dropped")
    func swapMissingField() {
        let raw = """
        {"text": "", "actions": [{"type": "swapGuests", "guestA": "X"}]}
        """
        let response = pilot.parseResponse(raw)
        #expect(response.actions.isEmpty)
    }
}
#endif
