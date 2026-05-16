#if canImport(Foundation)
import Foundation

/// Bringt gemischt formulierte FunFacts in eine einheitliche Form:
/// durchgehend 1. Person ("Ich bin den Jakobsweg rückwärts gelaufen.",
/// "Ich löse jeden Tag ein Kreuzworträtsel."). Inhalt bleibt unverändert — nur
/// Grammatik/Person wird vereinheitlicht. Der User reviewt das Ergebnis,
/// es wird NICHT automatisch bestätigt.
enum FunFactNormalizer {
    struct Result: Sendable, Identifiable {
        let guestID: UUID
        var id: UUID { guestID }
        let original: String
        let normalized: String
    }

    enum Error: Swift.Error, LocalizedError {
        /// LLM lief (kostet ggf. Geld), Antwort war aber nicht als erwartetes
        /// JSON lesbar. Snippet = was das Modell tatsächlich geschickt hat.
        case unparseable(String)

        var errorDescription: String? {
            switch self {
            case .unparseable(let snippet):
                return "KI-Antwort nicht verständlich (Modell zu schwach / falsches Format). "
                    + "Antwort-Anfang:\n\(snippet)"
            }
        }
    }

    private static let systemPrompt = """
        Du vereinheitlichst FunFacts für ein Hochzeits-Spiel. Die Texte sind \
        gemischt formuliert: mal 3. Person ("Ist den Jakobsweg rückwärts gelaufen"), \
        mal 1. Person ("Ich löse jeden Tag ein Kreuzworträtsel"), mal Stichwort.

        AUFGABE: Schreibe JEDEN FunFact in einheitliche 1. Person um, als ob die \
        Person selbst spricht, UND hebe ihn sprachlich an: korrekte Grammatik, \
        Rechtschreibung, Zeichensetzung, runde Satzstellung, kein Telegrammstil, \
        keine Füllwörter. Ergebnis: ein sauber formulierter, vollständiger Satz, \
        beginnend mit "Ich …", Punkt am Ende — so als stünde es gepflegt auf einer \
        Karte.

        REGELN — strikt:
        - INHALT NICHT ÄNDERN. Keine Fakten erfinden, weglassen, ausschmücken oder \
          abschwächen. „Sprachlich anheben" heißt NUR: Form, Grammatik, Stil — \
          NICHT neue Details, Adjektive oder Wertungen hinzufügen. Derselbe Fakt, \
          nur sauber formuliert.
        - 3. Person → 1. Person: "Ist gelaufen" → "Ich bin gelaufen". \
          "Hat gestrickt" → "Ich habe gestrickt".
        - Bereits 1. Person: Person beibehalten, aber trotzdem Grammatik/ \
          Rechtschreibung/Satzbau glätten und sauber ausformulieren.
        - Holprige/abgekürzte Eingaben zu einem flüssigen Satz machen \
          (z.B. "90min war ich Stadionsprecher" → "Ich war 90 Minuten lang Stadionsprecher.").
        - Klammer-Zusätze/Erklärungen beibehalten (ggf. auch in 1. Person), \
          ebenfalls sprachlich glätten.
        - Keine Anrede, kein Name, kein "Mein FunFact ist:" davor — nur der Satz.
        - Wenn ein Eintrag leer/nur ein generisches Stichwort ist und sich nicht \
          sinnvoll in 1. Person bringen lässt: gib den Originaltext unverändert zurück.

        BEISPIELE (Form/Stil gehoben, Fakt identisch):
        - "Ist den Jakobsweg rückwärts gelaufen" → "Ich bin den Jakobsweg rückwärts gelaufen."
        - "Hat schon über zweihundert Socken gestrickt" → "Ich habe schon über zweihundert Socken gestrickt."
        - "ich war in kanada im radio und in der zeitung" → "Ich war in Kanada im Radio und in der Zeitung."
        - "90min war ich Stadionsprecher" → "Ich war 90 Minuten lang Stadionsprecher."
        - "bau aufm balkon hopfen an brau bier selbst" → "Ich baue auf dem Balkon Hopfen an und braue eigenes Bier."

        Antworte AUSSCHLIESSLICH mit JSON, ohne Markdown:
        {
          "results": [
            {"id": "G1", "text": "Ich bin den Jakobsweg rückwärts gelaufen."},
            {"id": "G2", "text": "Ich löse jeden Tag ein Kreuzworträtsel."}
          ]
        }
        """

    private static func buildUserPrompt(idMap: [String: (UUID, String)]) -> String {
        var lines = ["## FunFacts"]
        for key in idMap.keys.sorted() {
            let (_, text) = idMap[key]!
            lines.append("- \(key): \"\(text)\"")
        }
        return lines.joined(separator: "\n")
    }

    private struct LLMResponse: Decodable {
        struct Entry: Decodable { let id: String; let text: String }
        let results: [Entry]
    }

    /// Schlägt vereinheitlichte Texte vor (ein einziger LLM-Call). Verändert
    /// die Gäste NICHT — der Aufrufer entscheidet was übernommen wird.
    @MainActor
    static func proposeBatch(
        guests: [Guest],
        client: LLMClient,
        onProgress: @MainActor (_ done: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws -> [Result] {
        let candidates = guests.filter {
            !$0.funFact.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard !candidates.isEmpty else { return [] }
        onProgress(0, candidates.count)

        let chunkSize = 20
        var out: [Result] = []
        var idx = 0
        while idx < candidates.count {
            try Task.checkCancellation()

            let chunk = Array(candidates[idx ..< min(idx + chunkSize, candidates.count)])
            idx += chunkSize

            var idMap: [String: (UUID, String)] = [:]
            for (i, g) in chunk.enumerated() {
                idMap["G\(i + 1)"] = (g.id, g.funFact)
            }

            let raw = try await client.prompt(
                system: systemPrompt,
                user: buildUserPrompt(idMap: idMap),
                temperature: 0.2,
                jsonMode: false
            )

            let json = FunFactValidator.extractJSONObject(from: raw)
            guard let data = json.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(LLMResponse.self, from: data) else {
                let snippet = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
                throw Error.unparseable(snippet.isEmpty ? "(leere Antwort)" : snippet)
            }

            for entry in decoded.results {
                guard let (uuid, original) = idMap[entry.id] else { continue }
                let cleaned = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleaned.isEmpty else { continue }
                out.append(Result(guestID: uuid, original: original, normalized: cleaned))
            }
            onProgress(min(idx, candidates.count), candidates.count)
        }
        return out
    }

#if DEBUG
    /// Nur für Prompt-Invarianten-Tests — kein Produktionspfad.
    static var systemPromptForTesting: String { systemPrompt }
#endif
}
#endif
