import Foundation

/// Vom LLM zurückgegebener Tag-Vorschlag plus die Gäste-IDs die der Generator
/// zugeordnet hat. Wird im UI vor dem Übernehmen reviewt.
struct ProposedTag: Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var category: TagCategory
    var partnerAssignment: PartnerAssignment?
    var derivationRule: String
    var guestIDs: [UUID]
    var accepted: Bool = true
}

/// Sendable Snapshot eines Guest-Modells — damit die LLM-Generation
/// off-main-actor laufen kann ohne SwiftData-Modelle über die Aktor-Grenze
/// zu schieben.
struct GuestSnapshot: Sendable, Equatable {
    let id: UUID
    let fullName: String
    let partnerAssignment: PartnerAssignment
    let registrationGroup: UUID?
    let funFact: String
    let notes: String
    let profession: String
    let hobbies: [String]
    /// Wenn der User die Familienrolle schon am Gast gepflegt hat (Mutter,
    /// Onkel, Cousin), kann der lokale Tag-Generator daraus die Mitglieder
    /// von Family-Tags wie "Eltern Gereon" ohne KI ableiten.
    let familyRole: FamilyRole?
    let familyRolePartner: PartnerAssignment?
}

/// Deterministischer Tag-Parser ohne KI. Die User-Eingabe ist faktisch schon
/// eine Tag-Liste (kommagetrennt) — wir splitten, normalisieren, kategorisieren
/// per Keyword-Heuristik und generieren saubere Tag-Namen mit Partner-Suffix.
/// Schlägt nie fehl, braucht keine LLM-Verbindung, ist instantan.
enum LocalTagDeriver {
    /// Ergebnis der lokalen Ableitung: Tag-Vorschläge plus die Begriffe die
    /// bewusst übersprungen wurden weil sie über die Familienrolle am Gast
    /// bereits abgedeckt sind. Der Skip-Counter taucht im UI als Info-Banner
    /// auf damit der User sieht dass seine Eingabe ernst genommen wurde.
    struct Result: Sendable {
        let proposals: [ProposedTag]
        let skippedFamilyTerms: [String]
    }

    static func derive(
        partner1Name: String,
        partner2Name: String,
        partner1Hint: String,
        partner2Hint: String,
        guests: [GuestSnapshot] = []
    ) -> Result {
        let p1Items = tokenize(partner1Hint)
        let p2Items = tokenize(partner2Hint)

        var result: [ProposedTag] = []
        var skippedFamily: [String] = []
        var p2Used: Set<String> = []

        for p1Item in p1Items {
            let normalized = normalize(p1Item)
            if isFamilyOnlyTerm(p1Item) {
                skippedFamily.append(p1Item)
                // Auch P2-Match markieren als verbraucht damit P2 das nicht doppelt erzeugt
                if let p2Match = p2Items.first(where: { normalize($0) == normalized }) {
                    p2Used.insert(normalize(p2Match))
                    skippedFamily.append(p2Match)
                }
                continue
            }
            if let p2Match = p2Items.first(where: { normalize($0) == normalized }) {
                p2Used.insert(normalize(p2Match))
                if isPerPartnerWhenShared(normalized) {
                    result.append(makeTag(p1Item, partner: .partner1, partnerName: partner1Name, guests: guests))
                    result.append(makeTag(p2Match, partner: .partner2, partnerName: partner2Name, guests: guests))
                } else {
                    result.append(makeTag(p1Item, partner: .both, partnerName: nil, guests: guests))
                }
            } else {
                result.append(makeTag(p1Item, partner: .partner1, partnerName: partner1Name, guests: guests))
            }
        }
        for p2Item in p2Items {
            if p2Used.contains(normalize(p2Item)) { continue }
            if isFamilyOnlyTerm(p2Item) {
                skippedFamily.append(p2Item)
                continue
            }
            result.append(makeTag(p2Item, partner: .partner2, partnerName: partner2Name, guests: guests))
        }
        return Result(proposals: result, skippedFamilyTerms: skippedFamily)
    }

    /// Begriffe die bereits über `Guest.familyRole` modelliert werden — diese
    /// als Tag zu erzeugen wäre Doppelarbeit (und würde im Tag-Bereich nur
    /// Krach machen). Beispiele: "Eltern", "Onkel & Tanten", "Schwester mit
    /// Familie", "Cousine/Cousin", "Schwiegereltern", "Familie Maria".
    /// "Familienfreunde" / "Familien Freunde" zählen NICHT als Family-only —
    /// das sind Freundes-Tags die nur das Wort "Familie" enthalten.
    private static func isFamilyOnlyTerm(_ raw: String) -> Bool {
        let n = normalize(raw)
        // Falsche Freunde rauspicken: "Familienfreunde", "Familien Freunde"
        if n.contains("freund") { return false }
        // Wenn der Begriff einer FamilyRole-Mapping-Heuristik trifft → skip
        if !familyRoles(for: raw).isEmpty { return true }
        // Plain "Familie X" ohne weitere Spezifikation ist auch redundant
        if n == "familie" || n.hasPrefix("familie ") { return true }
        return false
    }

    /// Splittet an Komma + Semikolon, trimmt, filtert leere.
    private static func tokenize(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Lowercased + Sonderzeichen weg + häufige Tippfehler-Varianten gleichgemacht.
    /// "Onkel Tanten" und "onkel, tanten" und "Onkel und Tanten" → gleicher Key.
    private static func normalize(_ raw: String) -> String {
        let lower = raw.lowercased()
            .replacingOccurrences(of: "ä", with: "a")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: " und ", with: " ")
            .replacingOccurrences(of: " & ", with: " ")
            .replacingOccurrences(of: "/", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
        // Pluralvereinheitlichung — grob, nur für Match-Zwecke
        return lower
            .replacingOccurrences(of: "innen", with: "")
            .replacingOccurrences(of: "freunde", with: "freund")
            .replacingOccurrences(of: "freundinnen", with: "freund")
            .replacingOccurrences(of: "schwestern", with: "schwester")
            .replacingOccurrences(of: "tanten", with: "tante")
            .replacingOccurrences(of: "cousins", with: "cousin")
            .replacingOccurrences(of: "cousinen", with: "cousin")
            .replacingOccurrences(of: "kommilitonen", with: "kommiliton")
            .replacingOccurrences(of: "kommilitone", with: "kommiliton")
    }

    /// Welche Begriffe sollen bei beidseitigem Vorkommen ZWEI Tags bekommen
    /// (einer pro Partner) statt einem gemeinsamen "beide"-Tag?
    /// Achtung: Trauzeuge fällt NICHT hierunter — Trauzeugen sitzen am
    /// Brautpaartisch und werden in makeTag() ohnehin auf .both gemappt.
    private static func isPerPartnerWhenShared(_ normalized: String) -> Bool {
        let perPartnerKeywords = [
            "jga", "junggesell",
            "eltern", "mama", "papa", "mutter", "vater",
            "geschwister", "schwester", "bruder",
            "onkel", "tante",
            "cousin",
            "kommiliton",
            "schulfreund",
            "arbeit"
        ]
        return perPartnerKeywords.contains { normalized.contains($0) }
    }

    private static func makeTag(_ raw: String, partner: PartnerAssignment, partnerName: String?, guests: [GuestSnapshot]) -> ProposedTag {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let cleanName = capitalizeFirstWords(trimmed)

        // Brautpaartisch-Rollen (Trauzeuge, Trauzeugin, Best Man) sitzen
        // semantisch BEIM BRAUTPAAR — auch wenn der User sie nur in einer
        // Liste genannt hat. Wir behalten den Namen mit Partner-Suffix für die
        // Identität, setzen partnerAssignment aber auf .both damit der
        // Sitzplaner sie am Brautpaartisch platziert.
        let n = trimmed.lowercased()
        let sitsAtBridalTable = n.contains("trauzeug") || n.contains("bestman") || n.contains("best man")
        let effectivePartner: PartnerAssignment = sitsAtBridalTable ? .both : partner

        let displayName: String
        if let pn = partnerName, partner != .both {
            // Identität bleibt: "Trauzeuge Gereon" / "Trauzeugin Maria"
            displayName = "\(cleanName) \(pn)"
        } else if partner == .both {
            displayName = "\(cleanName) (beide)"
        } else {
            displayName = cleanName
        }

        let autoIDs = matchingFamilyGuests(for: trimmed, partner: partner, in: guests)
        let rule = derivationRule(
            for: trimmed,
            partner: effectivePartner,
            partnerName: partnerName,
            hasAutoMatch: !autoIDs.isEmpty,
            sitsAtBridalTable: sitsAtBridalTable
        )
        return ProposedTag(
            name: displayName,
            category: categorize(trimmed),
            partnerAssignment: effectivePartner,
            derivationRule: rule,
            guestIDs: autoIDs
        )
    }

    /// Heuristisches Mapping: welche FamilyRoles sind in einem Tag-Begriff
    /// gemeint? "Eltern" → Mutter+Vater, "Geschwister" → Schwester+Bruder usw.
    private static func familyRoles(for raw: String) -> Set<FamilyRole> {
        let n = raw.lowercased()
        var roles: Set<FamilyRole> = []
        if n.contains("eltern") || n.contains("mama") || n.contains("papa") || n.contains("mutter") || n.contains("vater") {
            roles.formUnion([.mother, .father])
        }
        if n.contains("schwester") || n.contains("bruder") || n.contains("geschwister") {
            roles.formUnion([.sister, .brother])
        }
        if n.contains("onkel") || n.contains("tante") {
            roles.formUnion([.uncle, .aunt])
        }
        if n.contains("cousin") {
            roles.formUnion([.cousin, .cousine])
        }
        if n.contains("oma") || n.contains("opa") || n.contains("grosseltern") || n.contains("großeltern") || n.contains("grossmutter") || n.contains("großmutter") || n.contains("grossvater") || n.contains("großvater") {
            roles.formUnion([.grandmother, .grandfather])
        }
        if n.contains("schwager") || n.contains("schwägerin") || n.contains("schwagerin") {
            roles.formUnion([.brotherInLaw, .sisterInLaw])
        }
        if n.contains("schwiegereltern") || n.contains("schwiegermutter") || n.contains("schwiegervater") {
            roles.formUnion([.motherInLaw, .fatherInLaw])
        }
        if n.contains("nichte") || n.contains("neffe") {
            roles.formUnion([.niece, .nephew])
        }
        if n.contains("patenkind") || n.contains("patenkinder") {
            roles.insert(.godchild)
        }
        if n.contains("patenonkel") || n.contains("paten-onkel") {
            roles.insert(.godfather)
        }
        if n.contains("patentante") || n.contains("paten-tante") {
            roles.insert(.godmother)
        }
        if n.contains("patin") {
            roles.insert(.godmother)
        }
        if n.contains("paten ") || n.hasSuffix("paten") {
            if !roles.contains(.godfather) && !roles.contains(.godmother) && !roles.contains(.godchild) {
                roles.formUnion([.godfather, .godmother])
            }
        }
        return roles
    }

    private static func matchingFamilyGuests(for raw: String, partner: PartnerAssignment, in guests: [GuestSnapshot]) -> [UUID] {
        let roles = familyRoles(for: raw)
        guard !roles.isEmpty else { return [] }
        return guests.compactMap { g in
            guard let role = g.familyRole, roles.contains(role) else { return nil }
            // partner=.both → kein Filter auf Seite. Sonst: Seite muss matchen
            // (oder am Gast nicht gesetzt sein → dann zählen wir ihn dazu).
            if partner == .both { return g.id }
            if let side = g.familyRolePartner, side != partner { return nil }
            return g.id
        }
    }

    private static func capitalizeFirstWords(_ s: String) -> String {
        // "onkel tanten" → "Onkel Tanten", "schwester mit familie" → "Schwester mit Familie"
        let smallWords: Set<String> = ["mit", "und", "der", "die", "das", "von"]
        return s.split(separator: " ").enumerated().map { idx, word in
            let lower = word.lowercased()
            if idx > 0, smallWords.contains(lower) { return lower }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }.joined(separator: " ")
    }

    private static func categorize(_ raw: String) -> TagCategory {
        let n = raw.lowercased()
        // FALSCHE FREUNDE rauspicken BEVOR die Familie-Heuristik greift:
        // "Familienfreunde" / "Familien Freunde" / "Nachbarschaftsfamilie" sind
        // Freundeskreise, kein Verwandschaftsverhältnis — sonst würden sie
        // unter dem Familie-Filter landen und blutsverwandte Personen mit
        // FamilyRole überlagern.
        if containsAny(n, ["familienfreund", "familien freund"]) { return .friendGroup }
        // Hochzeitsrolle = ein Job AM Hochzeitstag (Trauzeuge, Brautjungfer,
        // Blumenkind, Ringträger). JGA ist KEIN Job am Tag — das ist ein
        // Event vorher mit Freundeskreis-Charakter, daher .friendGroup.
        if containsAny(n, ["trauzeug", "brautjungfer", "blumenkind", "ringtraeger", "ringträger", "bestman", "best man"]) { return .role }
        if containsAny(n, ["eltern", "mama", "papa", "mutter", "vater", "geschwister", "schwester", "bruder", "onkel", "tante", "cousin", "oma", "opa", "großeltern", "grosseltern", "familie", "patenkind", "patenonkel", "patentante"]) { return .family }
        if containsAny(n, ["arbeit", "kollege", "kolleg"]) { return .work }
        if containsAny(n, ["fasching", "verein", "sport", "chor", "tanzgruppe"]) { return .activity }
        if containsAny(n, ["jga", "junggesell", "freund", "kommilit", "schule", "wohnheim", "nachbar", "studium", "uni", "kindheit"]) { return .friendGroup }
        return .friendGroup
    }

    private static func containsAny(_ s: String, _ keywords: [String]) -> Bool {
        keywords.contains { s.contains($0) }
    }

    private static func derivationRule(for raw: String, partner: PartnerAssignment, partnerName: String?, hasAutoMatch: Bool = false, sitsAtBridalTable: Bool = false) -> String {
        let n = raw.lowercased()
        let who = partnerName ?? "dem Brautpaar"
        if sitsAtBridalTable {
            // Trauzeugen-Rolle: Identität bleibt erhalten, aber sitzt am Brautpaartisch
            if n.contains("trauzeug") { return "Trauzeuge/Trauzeugin von \(who) — sitzt am Brautpaartisch." }
            return "Wedding-Rolle für \(who) — sitzt am Brautpaartisch."
        }
        let prefix = hasAutoMatch ? "Aus Familienrollen abgeleitet — " : ""
        if n.contains("eltern") { return prefix + "Die Eltern von \(who)." }
        if n.contains("schwester") || n.contains("bruder") || n.contains("geschwister") { return prefix + "Geschwister von \(who) und ggf. deren Familie." }
        if n.contains("onkel") || n.contains("tante") { return prefix + "Onkel und Tanten von \(who)." }
        if n.contains("cousin") { return prefix + "Cousins/Cousinen von \(who)." }
        if n.contains("realschul") { return "Personen die mit \(who) auf der Realschule waren." }
        if n.contains("berufsschul") { return "Personen die mit \(who) auf der Berufsschule waren." }
        if n.contains("kommilit") { return "Studienfreunde von \(who)." }
        if n.contains("wohnheim") { return "Wohnheim-Freunde von \(who) aus der Studienzeit." }
        if n.contains("arbeit") || n.contains("kolleg") { return "Arbeitskollegen von \(who)." }
        if n.contains("fasching") { return "Fasching-Umfeld von \(who)." }
        if n.contains("nachbar") { return "Nachbarn von \(who)." }
        if n.contains("jga") { return "JGA-Kreis von \(who)." }
        if n.contains("familienfreunde") || n.contains("familien freunde") { return partner == .both ? "Familienfreunde, die beide Brautpaar-Seiten kennen." : "Familienfreunde von \(who)." }
        if n.contains("freundinnen") || n.contains("freunde") { return "Freundeskreis von \(who)." }
        return "Aus der Beziehungsbeschreibung von \(who) abgeleitet."
    }
}

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

WICHTIG: Familie (Eltern, Onkel, Tanten, Geschwister, Cousins, Schwiegereltern, Großeltern) wird bereits über das `familyRole`-Feld am Gast erfasst. Erzeuge KEINE Family-Tags wie "Eltern Gereon" oder "Onkel Maria". Konzentriere dich ausschließlich auf Freundeskreise (Realschule, Studium, Wohnheim), Aktivitäten (Fasching, Sport, Hobby), Arbeitskontexte, Hochzeitsrollen (Trauzeugen, JGA) und übergreifende Crews ("Geburtstagsfeier-Stammtisch", "Skihütten-Crew").

REGELN:
1. Pro genannter Beziehungsgruppe entsteht GENAU EIN Tag (nicht mehrere).
2. Der Tag-Name beschreibt die Gruppe knapp und enthält den Vornamen des Partners als Suffix, wenn die Gruppe partnerspezifisch ist (z.B. "Realschulfreunde Gereon"). Bei JGA wird daraus zwei Tags: "JGA Gereon" und "JGA Maria".
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
5. derivationRule: 1 deutscher Satz, der erklärt wer in den Tag fällt. Beispiel: "Personen die mit Gereon auf der Realschule waren."
6. guestIDs: Liste der UUIDs aus der Gästeliste die zu diesem Tag gehören. Heuristik:
   - Nutze Hinweise aus funFact/notes/Hobbys, sonst leer lassen
   - Wenn kein Match möglich: leeres Array zurückgeben (User ordnet später per Hand zu)
7. JGA-Spezialfall: Wenn der Begriff in BEIDEN Listen vorkommt → zwei separate Tags (einer pro Partner), Inhalt: nur die jeweils zugehörigen Gäste.

Antworte mit einem JSON-Objekt das ein Feld "tags" enthält. Jeder Tag-Eintrag hat die Felder name (string), category (einer von: friends, work, hobby, role, other), partnerAssignment (einer von: partner1, partner2, both, oder null), derivationRule (string, ein deutscher Satz), guestIDs (array von UUID-strings aus der Gästeliste, kann leer sein).

Beispiel-Schema (NICHT diese Werte zurückgeben — sondern eigene Vorschläge basierend auf den Eingaben):
- name: "Realschulfreunde Gereon"
- category: "friends"
- partnerAssignment: "partner1"
- derivationRule: "Personen die mit Gereon zur Realschule gegangen sind."
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
