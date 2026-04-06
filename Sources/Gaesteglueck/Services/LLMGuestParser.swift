import Foundation

enum LLMGuestParser {
    struct ParsedGuest: Codable, Sendable {
        let firstName: String
        let lastName: String
        let dietary: String
        let intolerances: [String]
        let isChild: Bool
        let funFact: String
    }

    static let systemPrompt = """
        Du bist ein Daten-Parser für Hochzeitsanmeldungen. Extrahiere aus dem Freitext \
        alle einzelnen Gäste als JSON-Array.

        Pro Gast folgende Felder:
        - firstName: Vorname
        - lastName: Nachname (aus Familienname ableiten falls nicht angegeben)
        - dietary: Essenswahl ("Fleisch", "Vegetarisch", "Vegan") — "alles" oder unklar = "Fleisch"
        - intolerances: Array von Unverträglichkeiten (leer wenn keine)
        - isChild: true wenn explizit als Kind markiert
        - funFact: Fun Fact falls vorhanden (sonst "")

        Antworte NUR mit dem JSON-Array, keine Erklärungen.
        """

    static func buildPrompt(for row: RegistrationRow) -> String {
        """
        Familienname: "\(row.familyName)"
        Anzahl Gäste: \(row.guestCount)
        Gäste-Details: "\(row.guestDetails)"
        Fun Facts: "\(row.funFacts)"
        Anmerkungen: "\(row.notes)"

        Extrahiere alle \(row.guestCount) Gäste als JSON-Array.
        """
    }

    static func parseResponse(_ text: String) throws -> [ImportedGuest] {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("Konnte Antwort nicht als Text lesen")
        }
        let parsed = try JSONDecoder().decode([ParsedGuest].self, from: data)
        return parsed.map { p in
            ImportedGuest(
                firstName: p.firstName,
                lastName: p.lastName,
                dietaryChoice: normalizeDietary(p.dietary),
                intolerances: p.intolerances,
                ageCategory: p.isChild ? .child : .adult,
                funFact: p.funFact,
                notes: ""
            )
        }
    }

    static func extractJSON(from text: String) -> String {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.range(of: "```"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]") {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeDietary(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "vegan": return "Vegan"
        case "vegetarisch", "vegetarian", "veggie": return "Vegetarisch"
        default: return "Fleisch"
        }
    }

    static func fallbackParse(_ row: RegistrationRow) -> [ImportedGuest] {
        let text = row.guestDetails
        guard !text.isEmpty else {
            return [ImportedGuest(firstName: row.familyName, lastName: "", dietaryChoice: "Fleisch", intolerances: [], ageCategory: .adult, funFact: "", notes: "")]
        }

        let separators = ["\n", "//", ";"]
        var lines = [text]
        for sep in separators {
            lines = lines.flatMap { $0.components(separatedBy: sep) }
        }

        if lines.count == 1 && row.guestCount > 1 {
            let commaParts = text.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if commaParts.count >= row.guestCount * 2 {
                var guests: [ImportedGuest] = []
                var i = 0
                while i < commaParts.count - 1 {
                    let namePart = commaParts[i]
                    let dietPart = commaParts[i + 1]
                    let dietary = normalizeDietary(dietPart)
                    let isChild = dietPart.lowercased().contains("kind")
                    let names = splitName(namePart, familyName: row.familyName)
                    guests.append(ImportedGuest(firstName: names.first, lastName: names.last, dietaryChoice: dietary, intolerances: [], ageCategory: isChild ? .child : .adult, funFact: "", notes: ""))
                    i += 2
                }
                if !guests.isEmpty { return guests }
            }
        }

        return lines.compactMap { line -> ImportedGuest? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            let parts = trimmed.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let namePart = parts.first ?? trimmed
            let names = splitName(namePart, familyName: row.familyName)
            let dietary = parts.count > 1 ? normalizeDietary(parts[1]) : "Fleisch"
            let isChild = trimmed.lowercased().contains("kind")
            return ImportedGuest(firstName: names.first, lastName: names.last, dietaryChoice: dietary, intolerances: [], ageCategory: isChild ? .child : .adult, funFact: "", notes: "")
        }
    }

    private static func splitName(_ name: String, familyName: String) -> (first: String, last: String) {
        let words = name.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        if words.count >= 2 {
            return (words[0], words.dropFirst().joined(separator: " "))
        } else if words.count == 1 {
            let lastName = familyName.components(separatedBy: CharacterSet(charactersIn: ",/&")).first?.trimmingCharacters(in: .whitespaces) ?? ""
            return (words[0], lastName)
        }
        return (name, "")
    }
}
