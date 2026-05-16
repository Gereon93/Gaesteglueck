#if canImport(Foundation)
import Foundation

enum FunFactValidator {
    enum Verdict: Sendable, Equatable {
        case good       // konkret, persönlich, am Brauttisch erzählbar
        case generic    // "Hobby", "Beruf", zu allgemein
        case empty      // funFact war leer
    }

    struct Result: Sendable {
        let guestID: UUID
        let verdict: Verdict
        let reason: String   // kurze Begründung vom LLM (1 Satz)
    }

    // MARK: - Prompt

    private static let systemPrompt = """
        Du bewertest FunFacts für ein Hochzeits-Kennenlern-Spiel. Die FunFacts werden anonym \
        auf den Tischen verteilt; jeder Gast soll raten zu wem der FunFact gehört, die Person \
        finden und ein Foto mit ihr machen.

        WICHTIG: Sei GROSSZÜGIG. Im Zweifel "good". "Generic" ist die Ausnahme — nur bei \
        offensichtlich unspielbaren Einträgen.

        GUT (good) = der FunFact ist konkret genug dass man im Gespräch danach raten kann. \
        Reicht völlig: ein konkretes Hobby, ein konkretes Erlebnis, eine bestimmte Vorliebe, \
        eine spezifische Eigenheit. Eine Mini-Story ist NICHT erforderlich. Beispiele für GUT:
        - "Hat schon mal ein eigenes Gedicht im Gemeindeblatt veröffentlicht" — konkrete Erfahrung
        - "Habe meinen Mann im Schachverein kennengelernt" — konkrete Story
        - "Hat in der 6. Klasse einen Vorlese-Wettbewerb gewonnen" — konkretes Erlebnis
        - "Hat sich beim ersten Stadionbesuch versehentlich in den Gästeblock gesetzt" — konkrete Anekdote
        - "Ist schon mal von einem Tretboot in den Ententeich gefallen" — konkretes Erlebnis
        - "Baut auf dem Balkon Hopfen an und braut eigenes Bier" — konkrete Eigenheit
        - "Mag Schildkröten und hat mal Linedance getanzt" — konkrete Vorlieben
        - "Kann kein Buch mit mehr als 500 Seiten zu Ende lesen" — konkrete Eigenart
        - "Ist Wickie-Fan" — konkretes Bekenntnis
        - "Frühstückt seit zehn Jahren jeden Tag Porridge" — konkrete Gewohnheit
        - "Es vergeht kein Tag ohne ein Kreuzworträtsel" — konkrete Gewohnheit
        - "Wird seit der Schulzeit nur beim Spitznamen genannt" — konkrete Aussage

        GENERIC = NUR diese drei Fälle:
        1. Ein einzelnes generisches Wort ohne Kontext: "Hobby", "Beruf", "Sport", "Familie", \
           "Siemens" (Firmenname allein), "Schachverein" (allein, ohne Verb/Story), \
           "Kunst und Politik" (Schlagwörter ohne Bezug zur Person).
        2. Beschreibung VON AUSSEN über die Person (nicht ihre eigene Aussage): \
           "ist süß", "ist sehr nett", "ist immer hilfsbereit".
        3. Trifft auf alle zu: "kennt das Brautpaar", "freut sich auf die Hochzeit".

        Wenn der FunFact ein Verb + Objekt enthält (z.B. "braut eigenes Bier", "mag Schildkröten", \
        "ist Wickie-Fan"), ist er IMMER good. Auch ohne weitere Begründung.

        ZIEL des Spiels: die Gäste sollen über jeden FunFact INS GESPRÄCH kommen. Frag dich \
        bei jedem Eintrag: "Könnte ein Gast bei diesem FunFact ein Gespräch anfangen?" Wenn ja: \
        good. Auch wenn der Text unrund formuliert ist — solange ein Anker da ist, ist er good.

        Antworte AUSSCHLIESSLICH mit JSON, ohne Markdown:
        {
          "results": [
            {"id": "G1", "verdict": "good", "reason": "Konkrete spielbare Eigenheit."},
            {"id": "G2", "verdict": "generic", "reason": "Einzelnes Stichwort ohne Bezug."}
          ]
        }

        Verdict ist exakt "good" oder "generic". Reason ist max. 12 Wörter, deutsch.
        """

    private static func buildUserPrompt(guests: [Guest]) -> String {
        var lines = ["## Gäste"]
        for (i, guest) in guests.enumerated() {
            let key = "G\(i + 1)"
            var line = "- \(key): \(guest.fullName)"
            if guest.ageCategory != .adult {
                line += " [\(guest.ageCategory.rawValue)]"
            }
            line += " — \"\(guest.funFact)\""
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Parsing

    private struct LLMResponse: Decodable {
        struct Entry: Decodable {
            let id: String
            let verdict: String
            let reason: String
        }
        let results: [Entry]
    }

    static func extractJSONObject(from text: String) -> String {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse rohen LLM-Output zurück zu [Result], mit idMap für UUID-Lookup.
    /// Fehlende IDs erhalten Verdict .generic. Unbekanntes verdict → .generic.
    static func parseResponse(_ raw: String, idMap: [String: UUID]) -> [Result] {
        let json = extractJSONObject(from: raw)
        guard let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(LLMResponse.self, from: data) else {
            return idMap.map { (key, uuid) in
                Result(guestID: uuid, verdict: .generic, reason: "LLM-Antwort nicht parsierbar.")
            }
        }

        var output: [String: Result] = [:]
        for entry in decoded.results {
            guard let uuid = idMap[entry.id] else { continue }
            let verdict: Verdict = entry.verdict == "good" ? .good : .generic
            output[entry.id] = Result(guestID: uuid, verdict: verdict, reason: entry.reason)
        }

        return idMap.map { (key, uuid) in
            output[key] ?? Result(guestID: uuid, verdict: .generic, reason: "Kein Ergebnis vom LLM.")
        }
    }

    // MARK: - Public API

    /// Bewertet eine Liste von Gast-FunFacts in einem einzigen LLM-Call.
    /// Empty FunFacts werden direkt als .empty markiert ohne LLM-Aufruf.
    @MainActor
    static func validateBatch(
        guests: [Guest],
        client: LLMClient,
        onProgress: @MainActor (_ done: Int, _ total: Int) -> Void = { _, _ in }
    ) async throws -> [Result] {
        var results: [Result] = []

        let nonEmpty = guests.filter { !$0.funFact.trimmingCharacters(in: .whitespaces).isEmpty }
        let emptyGuests = guests.filter { $0.funFact.trimmingCharacters(in: .whitespaces).isEmpty }

        for guest in emptyGuests {
            results.append(Result(guestID: guest.id, verdict: .empty, reason: "Kein FunFact vorhanden."))
        }

        // Baby + Kleinkind: jeder nicht-leere FunFact zählt automatisch als
        // gut (z.B. "ist süß"). Keine KI-Bewertung nötig — das Spiel-Kriterium
        // gilt nur für Gäste die selbst rätseln/Foto machen.
        let toddlerLike = nonEmpty.filter { $0.ageCategory == .baby || $0.ageCategory == .toddler }
        for guest in toddlerLike {
            results.append(Result(guestID: guest.id, verdict: .good, reason: "Baby/Kleinkind — automatisch akzeptiert."))
        }

        let needsLLM = nonEmpty.filter { $0.ageCategory != .baby && $0.ageCategory != .toddler }
        guard !needsLLM.isEmpty else { return results }

        onProgress(0, needsLLM.count)
        let chunkSize = 20
        var idx = 0
        while idx < needsLLM.count {
            try Task.checkCancellation()
            let chunk = Array(needsLLM[idx ..< min(idx + chunkSize, needsLLM.count)])
            idx += chunkSize

            var idMap: [String: UUID] = [:]
            for (i, guest) in chunk.enumerated() {
                idMap["G\(i + 1)"] = guest.id
            }
            let userPrompt = buildUserPrompt(guests: chunk)
            let raw = try await client.prompt(system: systemPrompt, user: userPrompt, temperature: 0.1, jsonMode: false)
            results.append(contentsOf: parseResponse(raw, idMap: idMap))
            onProgress(min(idx, needsLLM.count), needsLLM.count)
        }
        return results
    }

#if DEBUG
    /// Nur für Tests — parsiert einen rohen LLM-Output ohne Netzwerk.
    static func parseResponseForTesting(_ raw: String, idMap: [String: UUID]) -> [Result] {
        parseResponse(raw, idMap: idMap)
    }

    /// Nur für Prompt-Invarianten-Tests.
    static var systemPromptForTesting: String { systemPrompt }
#endif
}
#endif
