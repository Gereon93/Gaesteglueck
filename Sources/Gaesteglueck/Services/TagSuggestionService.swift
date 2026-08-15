import Foundation

/// Brückenkomponente zwischen Beziehungs-Wizard-Eingabe (zwei Freitext-Felder)
/// und LM Studio. Ein einziger LLM-Call macht zwei Dinge auf einmal:
///   1) Tags aus der Beziehungsbeschreibung ableiten
///   2) Vorhandene Gäste den Tags zuordnen (Familienname-Heuristik + Kontext)
/// Damit muss der User nicht erst Tags klicken und dann Gäste zuziehen.
struct TagSuggestionService {
    let client: LLMClient

    /// Ergebnis-Wrapper damit das UI im Fehlerfall (Parser findet nichts) die
    /// Roh-Antwort des LLM anzeigen kann — dann sieht der User direkt ob das
    /// Modell Markdown-Wrapper, Plain-Text oder Reasoning-Dump geliefert hat.
    struct GenerationResult: Sendable {
        let proposals: [ProposedTag]
        let rawResponse: String
    }

    func generateWithRaw(
        partner1Name: String,
        partner2Name: String,
        partner1Hint: String,
        partner2Hint: String,
        guests: [GuestSnapshot]
    ) async throws -> GenerationResult {
        let userPrompt = buildUserPrompt(
            partner1Name: partner1Name,
            partner2Name: partner2Name,
            partner1Hint: partner1Hint,
            partner2Hint: partner2Hint,
            guests: guests
        )
        let raw = try await client.chat(
            messages: [
                LLMMessage(role: "system", content: Self.systemPrompt),
                LLMMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.3,
            maxTokens: 16000,
            jsonMode: false
        )
        let proposals = parseResponse(raw, validGuestIDs: Set(guests.map(\.id)))
        return GenerationResult(proposals: proposals, rawResponse: raw)
    }

    func generate(
        partner1Name: String,
        partner2Name: String,
        partner1Hint: String,
        partner2Hint: String,
        guests: [GuestSnapshot]
    ) async throws -> [ProposedTag] {
        let userPrompt = buildUserPrompt(
            partner1Name: partner1Name,
            partner2Name: partner2Name,
            partner1Hint: partner1Hint,
            partner2Hint: partner2Hint,
            guests: guests
        )
        // 16k Tokens damit auch Reasoning-Modelle (Gemma 4 thinking, etc.)
        // Platz für Thinking + JSON-Antwort haben. Ohne den Headroom verbrennt
        // ein 4B-MoE wie Gemma 4 A4B sämtliche Tokens beim "Start thinking..."
        // und gibt content="" zurück (siehe finish_reason=length).
        //
        // jsonMode (response_format: json_object) bewusst AUS — zickt mit
        // Reasoning-Modellen (decoder error / leere choices). Wir verlassen
        // uns auf den System-Prompt + den manuellen JSON-Extractor.
        let raw = try await client.chat(
            messages: [
                LLMMessage(role: "system", content: Self.systemPrompt),
                LLMMessage(role: "user", content: userPrompt)
            ],
            temperature: 0.3,
            maxTokens: 16000,
            jsonMode: false
        )
        return parseResponse(raw, validGuestIDs: Set(guests.map(\.id)))
    }

    static let systemPrompt: String = """
Antworte SOFORT mit dem fertigen JSON, ohne vorheriges Nachdenken oder Selbstgespräch. Keine Erklärungen, keine Markdown-Wrapper, kein <think>-Block — direkt das JSON-Objekt.

Du bist ein Hochzeits-Beziehungs-Analyst. Aus zwei Freitext-Listen (Partner 1 und Partner 2) erzeugst du strukturierte Tags und ordnest jeden Gast dem passenden Tag zu.

WICHTIG: Familie (Eltern, Onkel, Tanten, Geschwister, Cousins, Schwiegereltern, Großeltern) wird bereits über das `familyRole`-Feld am Gast erfasst. Erzeuge KEINE Family-Tags wie "Eltern Bob" oder "Onkel Alice". Konzentriere dich ausschließlich auf Freundeskreise (Realschule, Studium, Wohnheim), Aktivitäten (Fasching, Sport, Hobby), Arbeitskontexte, Hochzeitsrollen (Trauzeugen, JGA) und übergreifende Crews ("Geburtstagsfeier-Stammtisch", "Skihütten-Crew").

REGELN:
1. Pro genannter Beziehungsgruppe entsteht GENAU EIN Tag (nicht mehrere).
2. Der Tag-Name beschreibt die Gruppe knapp und enthält den Vornamen des Partners als Suffix, wenn die Gruppe partnerspezifisch ist (z.B. "Realschulfreunde Bob"). Bei JGA wird daraus zwei Tags: "JGA Bob" und "JGA Alice".
3. category (englisches Token):
   - friends  = Freundesgruppen jeder Art (Realschule, Studium, Kindheit, Sport, Nachbarn) UND der JGA-Kreis (das ist ein Freundeskreis, kein Job am Hochzeitstag)
   - work     = Arbeitskollegen, Berufsschule (sofern beruflich gemeint)
   - hobby    = Vereine, Fasching, Sport, gemeinsame Aktivitäten
   - role     = NUR Jobs am Hochzeitstag: Trauzeugen, Brautjungfern, Blumenkinder, Ringträger
   - other    = wenn nichts passt
4. partnerAssignment:
   - "partner1" = nur Partner 1
   - "partner2" = nur Partner 2
   - "both"    = explizit gemeinsam (z.B. "Familienfreunde von beiden", JGA-Gesamtkreis)
   - null      = neutral
5. derivationRule: 1 deutscher Satz, der erklärt wer in den Tag fällt. Beispiel: "Personen die mit Bob auf der Realschule waren."
6. guestIDs: Liste der UUIDs aus der Gästeliste die zu diesem Tag gehören. Heuristik:
   - Nutze Hinweise aus funFact/notes/Hobbys, sonst leer lassen
   - Wenn kein Match möglich: leeres Array zurückgeben (User ordnet später per Hand zu)
7. JGA-Spezialfall: Wenn der Begriff in BEIDEN Listen vorkommt → zwei separate Tags (einer pro Partner), Inhalt: nur die jeweils zugehörigen Gäste.

Antworte mit einem JSON-Objekt das ein Feld "tags" enthält. Jeder Tag-Eintrag hat die Felder name (string), category (einer von: friends, work, hobby, role, other), partnerAssignment (einer von: partner1, partner2, both, oder null), derivationRule (string, ein deutscher Satz), guestIDs (array von UUID-strings aus der Gästeliste, kann leer sein).

Beispiel-Schema (NICHT diese Werte zurückgeben — sondern eigene Vorschläge basierend auf den Eingaben):
- name: "Realschulfreunde Bob"
- category: "friends"
- partnerAssignment: "partner1"
- derivationRule: "Personen die mit Bob zur Realschule gegangen sind."
- guestIDs: ["..."]
"""

    private func buildUserPrompt(
        partner1Name: String,
        partner2Name: String,
        partner1Hint: String,
        partner2Hint: String,
        guests: [GuestSnapshot]
    ) -> String {
        var prompt = ""
        prompt += "PARTNER 1 = \(partner1Name)\n"
        prompt += "PARTNER 2 = \(partner2Name)\n\n"
        prompt += "BEZIEHUNGEN VON \(partner1Name):\n\(partner1Hint.isEmpty ? "(keine)" : partner1Hint)\n\n"
        prompt += "BEZIEHUNGEN VON \(partner2Name):\n\(partner2Hint.isEmpty ? "(keine)" : partner2Hint)\n\n"
        prompt += "GÄSTE (id | Vorname Nachname | Seite | registrationGroup | Hinweise):\n"
        for guest in guests {
            let side: String
            switch guest.partnerAssignment {
            case .partner1: side = "P1"
            case .partner2: side = "P2"
            case .both: side = "Beide"
            case .unassigned: side = "—"
            }
            let group = guest.registrationGroup?.uuidString.prefix(8).description ?? "—"
            var hints: [String] = []
            if !guest.funFact.isEmpty { hints.append("FunFact: " + guest.funFact) }
            if !guest.notes.isEmpty { hints.append("Notes: " + guest.notes) }
            if !guest.profession.isEmpty { hints.append("Beruf: " + guest.profession) }
            if !guest.hobbies.isEmpty { hints.append("Hobbys: " + guest.hobbies.joined(separator: ", ")) }
            let hintBlock = hints.isEmpty ? "" : " | " + hints.joined(separator: " · ")
            prompt += "- \(guest.id.uuidString) | \(guest.fullName) | \(side) | grp:\(group)\(hintBlock)\n"
        }
        return prompt
    }

    func parseResponse(_ raw: String, validGuestIDs: Set<UUID>) -> [ProposedTag] {
        guard let jsonString = extractJSONObject(from: raw),
              let data = jsonString.data(using: .utf8) else { return [] }

        guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagsRaw = parsed["tags"] as? [[String: Any]] else { return [] }

        var result: [ProposedTag] = []
        for entry in tagsRaw {
            guard let name = (entry["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else { continue }
            let categoryToken = (entry["category"] as? String ?? "other").lowercased()
            let category = mapCategory(categoryToken)
            let partner = mapPartner(entry["partnerAssignment"] as? String)
            let rule = (entry["derivationRule"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let rawIDs = entry["guestIDs"] as? [String] ?? entry["guestIds"] as? [String] ?? []
            let validIDs = rawIDs.compactMap { UUID(uuidString: $0) }.filter { validGuestIDs.contains($0) }
            result.append(ProposedTag(
                name: name,
                category: category,
                partnerAssignment: partner,
                derivationRule: rule,
                guestIDs: validIDs
            ))
        }
        return result
    }

    private func mapCategory(_ token: String) -> TagCategory {
        switch token {
        case "family", "familie": return .family
        case "friends", "friendgroup", "freunde": return .friendGroup
        case "work", "arbeit": return .work
        case "hobby", "activity", "aktivität", "aktivitaet": return .activity
        case "role", "rolle", "hochzeitsrolle": return .role
        default: return .custom
        }
    }

    private func mapPartner(_ token: String?) -> PartnerAssignment? {
        guard let token = token?.lowercased() else { return nil }
        switch token {
        case "partner1", "p1": return .partner1
        case "partner2", "p2": return .partner2
        case "both", "beide": return .both
        case "null", "none", "neutral", "unassigned", "": return nil
        default: return nil
        }
    }

    /// LLM-Antworten werden manchmal mit Markdown-Code-Fences oder Vorrede
    /// zurückgegeben. Wir extrahieren das erste {...}-Objekt.
    private func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var escape = false
        var idx = start
        while idx < raw.endIndex {
            let ch = raw[idx]
            if escape { escape = false }
            else if ch == "\\" && inString { escape = true }
            else if ch == "\"" { inString.toggle() }
            else if !inString {
                if ch == "{" { depth += 1 }
                else if ch == "}" {
                    depth -= 1
                    if depth == 0 {
                        return String(raw[start...idx])
                    }
                }
            }
            idx = raw.index(after: idx)
        }
        return nil
    }
}
