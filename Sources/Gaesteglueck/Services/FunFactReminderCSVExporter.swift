import Foundation

/// Erzeugt eine CSV mit fertigen Erinnerungstexten je Gast — eine Zeile pro
/// offene Person, der Text in der letzten Spalte ist direkt ins Messenger-
/// fenster kopierbar. Spalten: Vorname, Nachname, Telefon, Status,
/// Erinnerungstext.
enum FunFactReminderCSVExporter {
    static func generateCSV(guests: [Guest], event: Event?) -> Data {
        var rows: [String] = []
        rows.append(["Vorname", "Nachname", "Telefon", "Status", "Erinnerungstext"]
            .map(escape).joined(separator: ";"))

        for g in guests {
            let trimmed = g.funFact.trimmingCharacters(in: .whitespaces)
            let status = trimmed.isEmpty ? "FEHLT" : "UNKLAR"
            let phone = PhoneFormatter.display(g.phoneNumber)
            let message = FunFactReminderGenerator.message(for: g, event: event)
            rows.append([
                escape(g.firstName),
                escape(g.lastName),
                escape(phone),
                escape(status),
                escape(message)
            ].joined(separator: ";"))
        }

        let bom = "\u{FEFF}"
        let csv = bom + rows.joined(separator: "\r\n") + "\r\n"
        return csv.data(using: .utf8) ?? Data()
    }

    private static func escape(_ field: String) -> String {
        if field.contains(";") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
