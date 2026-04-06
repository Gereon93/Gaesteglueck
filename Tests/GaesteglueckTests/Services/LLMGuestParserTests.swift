import Testing
import Foundation
@testable import Gaesteglueck

@Suite("LLMGuestParser")
struct LLMGuestParserTests {
    @Test("Parse structured JSON response into ImportedGuests")
    func parseValidJSON() throws {
        let json = """
        [
          {"firstName": "Peter", "lastName": "Sommer", "dietary": "Fleisch", "intolerances": [], "isChild": false, "funFact": "fährt gern Rennrad"},
          {"firstName": "Johannes", "lastName": "Sommer", "dietary": "Fleisch", "intolerances": [], "isChild": true, "funFact": "spielt Schach"}
        ]
        """
        let guests = try LLMGuestParser.parseResponse(json)
        #expect(guests.count == 2)
        #expect(guests[0].firstName == "Peter")
        #expect(guests[0].lastName == "Sommer")
        #expect(guests[0].ageCategory == .adult)
        #expect(guests[1].firstName == "Johannes")
        #expect(guests[1].ageCategory == .child)
    }

    @Test("Build prompt from registration row")
    func buildPrompt() {
        let row = RegistrationRow(familyName: "Sommer", guestCount: 5, guestDetails: "Peter, Fleisch, Marlene, Fleisch, Johannes, Fleisch, Kind", funFacts: "Peter: fährt gern Rennrad", notes: "")
        let prompt = LLMGuestParser.buildPrompt(for: row)
        #expect(prompt.contains("Sommer"))
        #expect(prompt.contains("5"))
        #expect(prompt.contains("Peter"))
        #expect(prompt.contains("JSON"))
    }

    @Test("Parse response with markdown code fences")
    func parseWithCodeFences() throws {
        let response = """
        Hier sind die extrahierten Gäste:

        ```json
        [{"firstName": "Kai", "lastName": "Hofer", "dietary": "Fleisch", "intolerances": [], "isChild": false, "funFact": ""}]
        ```
        """
        let guests = try LLMGuestParser.parseResponse(response)
        #expect(guests.count == 1)
        #expect(guests[0].firstName == "Kai")
    }

    @Test("Fallback regex parser for simple cases")
    func fallbackParser() {
        let row = RegistrationRow(familyName: "Brandt und Dallmann", guestCount: 2, guestDetails: "Nils Brandt, Fleisch\nMartha Dallmann, Fleisch", funFacts: "", notes: "")
        let guests = LLMGuestParser.fallbackParse(row)
        #expect(guests.count == 2)
        #expect(guests[0].firstName == "Nils")
        #expect(guests[0].lastName == "Brandt")
        #expect(guests[1].firstName == "Martha")
    }
}
