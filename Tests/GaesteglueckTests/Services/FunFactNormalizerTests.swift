import Testing
import Foundation
@testable import Gaesteglueck

/// Stub-LLM der eine feste Antwort liefert — kein Netz, keine Kosten.
/// Golden-Tests: prüfen dass Parsing/Filter/Fehlerpfade stabil bleiben,
/// damit ein Prompt- oder Code-Refactor nicht still etwas zerlegt.
private struct StubLLM: LLMClient {
    let canned: String
    func chat(messages: [LLMMessage], temperature: Double, maxTokens: Int, jsonMode: Bool) async throws -> String {
        canned
    }
}

@Suite("FunFactNormalizer")
struct FunFactNormalizerTests {
    @Test("Valides JSON → normalisierte Vorschläge, identische gefiltert")
    @MainActor
    func parsesAndFilters() async throws {
        let g1 = Guest(firstName: "A", funFact: "Ist den Jakobsweg rückwärts gelaufen")
        let g2 = Guest(firstName: "B", funFact: "Ich löse jeden Tag ein Kreuzworträtsel.")
        let raw = """
        {"results":[
          {"id":"G1","text":"Ich bin den Jakobsweg rückwärts gelaufen."},
          {"id":"G2","text":"Ich löse jeden Tag ein Kreuzworträtsel."}
        ]}
        """
        let out = try await FunFactNormalizer.proposeBatch(
            guests: [g1, g2], client: StubLLM(canned: raw)
        )
        #expect(out.count == 2)
        let r1 = out.first { $0.guestID == g1.id }
        #expect(r1?.normalized == "Ich bin den Jakobsweg rückwärts gelaufen.")
        // g2 war schon 1. Person → Vorschlag identisch (Caller filtert das raus)
        let r2 = out.first { $0.guestID == g2.id }
        #expect(r2?.original == r2?.normalized)
    }

    @Test("Markdown-umzäuntes JSON wird trotzdem geparst")
    @MainActor
    func handlesMarkdownFence() async throws {
        let g = Guest(firstName: "A", funFact: "Hat Socken gestrickt")
        let raw = "Klar! Hier:\n```json\n{\"results\":[{\"id\":\"G1\",\"text\":\"Ich habe Socken gestrickt.\"}]}\n```"
        let out = try await FunFactNormalizer.proposeBatch(
            guests: [g], client: StubLLM(canned: raw)
        )
        #expect(out.first?.normalized == "Ich habe Socken gestrickt.")
    }

    @Test("Unlesbare Antwort wirft .unparseable mit Snippet — kein stilles []")
    @MainActor
    func throwsOnGarbage() async throws {
        let g = Guest(firstName: "A", funFact: "x")
        let raw = "Ich kann dir leider keine FunFacts umschreiben, das ist gegen meine Richtlinien."
        await #expect(throws: FunFactNormalizer.Error.self) {
            _ = try await FunFactNormalizer.proposeBatch(
                guests: [g], client: StubLLM(canned: raw)
            )
        }
    }

    @Test("Leere Gästeliste → keine Vorschläge, kein Call")
    @MainActor
    func emptyShortCircuits() async throws {
        let out = try await FunFactNormalizer.proposeBatch(
            guests: [Guest(firstName: "A", funFact: "")],
            client: StubLLM(canned: "DAS DARF NIE GEPARST WERDEN")
        )
        #expect(out.isEmpty)
    }
}

/// Prompt-Snapshot light: schützt die Kern-Intention der System-Prompts.
/// Kein Full-Snapshot (zu brüchig) — nur Invarianten die NICHT versehentlich
/// rausrefactored werden dürfen. Schlägt fehl wenn jemand den Prompt
/// entkernt; bewusste Änderung = Test bewusst anpassen.
@Suite("Prompt-Invarianten")
struct PromptInvariantTests {
    @Test("FunFact-Normalizer-Prompt fordert 1. Person + JSON")
    func normalizerPromptIntact() {
        let p = FunFactNormalizer.systemPromptForTesting
        #expect(p.contains("1. Person"))
        #expect(p.contains("INHALT NICHT ÄNDERN"))
        #expect(p.contains("\"results\""))
    }

    @Test("FunFact-Validator-Prompt: GROSSZÜGIG + good/generic + JSON")
    func validatorPromptIntact() {
        let p = FunFactValidator.systemPromptForTesting
        #expect(p.contains("GROSSZÜGIG"))
        #expect(p.contains("good"))
        #expect(p.contains("generic"))
        #expect(p.contains("\"results\""))
    }
}
