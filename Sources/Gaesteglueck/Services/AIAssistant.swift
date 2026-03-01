import Foundation

enum AIAssistant {
    /// Generate a natural-language summary of the current seating situation and suggestions.
    static func generatePrompt(
        tables: [GuestTable],
        guests: [Guest],
        relationships: [Relationship],
        violations: [Violation]
    ) -> String {
        var prompt = "Hier ist die aktuelle Sitzordnung einer Hochzeit:\n\n"

        for table in tables {
            let guestNames = table.guests.map { g in
                var desc = g.name
                if let role = g.familyRole { desc += " (\(role.rawValue))" }
                if let group = g.groupLabel { desc += " [\(group)]" }
                return desc
            }
            prompt += "**\(table.name)** (\(table.shape.rawValue), \(table.guests.count)/\(table.capacity)):\n"
            prompt += guestNames.isEmpty ? "  Leer\n" : guestNames.map { "  - \($0)" }.joined(separator: "\n") + "\n"
        }

        let unassigned = guests.filter { $0.table == nil }
        if !unassigned.isEmpty {
            prompt += "\n**Noch nicht zugewiesen:** \(unassigned.map(\.name).joined(separator: ", "))\n"
        }

        if !violations.isEmpty {
            prompt += "\n**Probleme:**\n"
            for v in violations {
                let nameA = guests.first { $0.id == v.personAID }?.name ?? "?"
                let nameB = guests.first { $0.id == v.personBID }?.name ?? "?"
                prompt += "  - \(v.description): \(nameA) & \(nameB)\n"
            }
        }

        prompt += "\nGib 3-5 konkrete Vorschläge, wie die Sitzordnung verbessert werden kann. Berücksichtige Familiengruppen, Konflikte und die Stimmung an den Tischen."

        return prompt
    }
}
