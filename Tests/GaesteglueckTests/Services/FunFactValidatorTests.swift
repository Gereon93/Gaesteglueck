import Testing
import Foundation
@testable import Gaesteglueck

@Suite("FunFactValidator")
struct FunFactValidatorTests {
    @Test("Empty funFact gets .empty verdict without LLM call")
    @MainActor
    func emptyVerdict() async throws {
        let g = Guest(firstName: "Anna", lastName: "M", funFact: "")
        // Wir brauchen für diesen Test KEINEN echten Client — empty wird vor dem Aufruf abgefangen.
        // Stub via Endpoint der nie erreichbar ist.
        let client = LMStudioClient(endpoint: "http://127.0.0.1:1")
        let results = try? await FunFactValidator.validateBatch(guests: [g], client: client)
        #expect(results?.count == 1)
        #expect(results?.first?.verdict == .empty)
        #expect(results?.first?.guestID == g.id)
    }

    @Test("Whitespace-only funFact treated as empty")
    @MainActor
    func whitespaceEmpty() async throws {
        let g = Guest(firstName: "B", lastName: "C", funFact: "   ")
        let client = LMStudioClient(endpoint: "http://127.0.0.1:1")
        let results = try? await FunFactValidator.validateBatch(guests: [g], client: client)
        #expect(results?.first?.verdict == .empty)
    }

    @Test("Output parser handles missing IDs as .generic")
    @MainActor
    func parsingFallback() {
        // Direkter Test der internen Parse-Funktion — exposes via internal access
        // Der LLM-Output enthält nur G1 obwohl 2 Gäste reingegeben wurden.
        // G2 sollte als .generic gelten.
        let raw = "{\"results\":[{\"id\":\"G1\",\"verdict\":\"good\",\"reason\":\"top\"}]}"
        let g1 = Guest(firstName: "A", funFact: "x")
        let g2 = Guest(firstName: "B", funFact: "y")
        let mapping = ["G1": g1.id, "G2": g2.id]
        let parsed = FunFactValidator.parseResponseForTesting(raw, idMap: mapping)
        let g1r = parsed.first { $0.guestID == g1.id }
        let g2r = parsed.first { $0.guestID == g2.id }
        #expect(g1r?.verdict == .good)
        #expect(g2r?.verdict == .generic)
    }
}
