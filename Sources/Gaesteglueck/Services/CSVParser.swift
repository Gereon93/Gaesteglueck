import Foundation

enum CSVParser {
    static func parse(_ content: String) throws -> [ImportedFamily] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { throw ImportError.emptyFile }

        let delimiter: Character = headerLine.contains(";") ? ";" : ","
        let headers = headerLine.split(separator: delimiter)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        guard let nameIdx = headers.firstIndex(of: "name") else {
            throw ImportError.missingNameColumn
        }
        let sideIdx = headers.firstIndex(where: { ["seite", "side"].contains($0) })
        let dietIdx = headers.firstIndex(where: { ["essen", "ernährung", "dietary", "diet"].contains($0) })
        let allergyIdx = headers.firstIndex(where: { ["unverträglichkeiten", "allergien", "allergies"].contains($0) })
        let childrenIdx = headers.firstIndex(where: { ["kinder", "children"].contains($0) })

        var families: [ImportedFamily] = []

        for line in lines.dropFirst() {
            let fields = line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            guard fields.indices.contains(nameIdx), !fields[nameIdx].isEmpty else { continue }

            let rawName = fields[nameIdx]
            let side = parseSide(fields, at: sideIdx)
            let dietary = parseDietary(fields, at: dietIdx)
            let allergies = allergyIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""

            // Split couple names: "Klaus & Erika Müller" or "Max und Lisa Becker"
            let names = splitCoupleNames(rawName)
            let familyID = names.count > 1 ? UUID() : nil

            var members = names.map { name in
                ImportedGuest(name: name, side: side, dietaryPreference: dietary, allergies: allergies, isChild: false)
            }

            // Parse children column: "Max (8) und Lina (5)"
            if let cIdx = childrenIdx, fields.indices.contains(cIdx), !fields[cIdx].isEmpty {
                let lastName = extractLastName(from: rawName)
                let children = parseChildren(fields[cIdx], lastName: lastName, side: side)
                members.append(contentsOf: children)
            }

            families.append(ImportedFamily(
                sharedFamilyID: members.count > 1 ? (familyID ?? UUID()) : nil,
                members: members
            ))
        }

        return families
    }

    // MARK: - Helpers (internal for reuse by ExcelParser)

    private static func parseSide(_ fields: [String], at index: Int?) -> Side {
        guard let idx = index, fields.indices.contains(idx) else { return .neutral }
        switch fields[idx].lowercased() {
        case "braut", "bride": return .bride
        case "bräutigam", "groom": return .groom
        default: return .neutral
        }
    }

    private static func parseDietary(_ fields: [String], at index: Int?) -> DietaryPreference {
        guard let idx = index, fields.indices.contains(idx) else { return .meat }
        switch fields[idx].lowercased() {
        case "vegan": return .vegan
        case "vegetarisch", "vegetarian", "veggie": return .vegetarian
        default: return .meat
        }
    }

    /// Splits "Klaus & Erika Müller" into ["Klaus Müller", "Erika Müller"]
    static func splitCoupleNames(_ raw: String) -> [String] {
        let separators = [" & ", " und ", " + "]
        for sep in separators {
            if raw.contains(sep) {
                let parts = raw.components(separatedBy: sep)
                guard parts.count == 2 else { return [raw] }
                let lastName = extractLastName(from: raw)
                return parts.map { part in
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.contains(" ") {
                        return trimmed // Already has last name
                    } else {
                        return "\(trimmed) \(lastName)"
                    }
                }
            }
        }
        return [raw]
    }

    static func extractLastName(from fullName: String) -> String {
        let words = fullName.trimmingCharacters(in: .whitespaces)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        return words.last ?? ""
    }

    /// Parses "Max (8) und Lina (5)" into child ImportedGuests
    static func parseChildren(_ raw: String, lastName: String, side: Side) -> [ImportedGuest] {
        let childParts = raw.components(separatedBy: CharacterSet(charactersIn: ",;&"))
            .flatMap { $0.components(separatedBy: " und ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return childParts.map { part in
            let name = part.replacingOccurrences(of: #"\s*\(.*?\)"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            let fullName = name.contains(" ") ? name : "\(name) \(lastName)"
            return ImportedGuest(name: fullName, side: side, dietaryPreference: .meat, allergies: "", isChild: true)
        }
    }
}
