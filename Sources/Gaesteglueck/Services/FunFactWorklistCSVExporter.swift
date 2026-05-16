import Foundation

/// Erzeugt eine CSV-Datei der FunFact-Workliste — Excel-import-fertig.
/// Spalten: Vorname, Nachname, Status, Aktueller FunFact, Notizen (leer
/// zum Ausfüllen). Semikolon-separiert (DE-Excel-Default).
enum FunFactWorklistCSVExporter {
    static func generateCSV(guests: [Guest]) -> Data {
        var rows: [String] = []
        rows.append(["Vorname", "Nachname", "Status", "Aktueller FunFact", "Neuer FunFact"]
            .map(escape).joined(separator: ";"))

        for g in guests {
            let trimmed = g.funFactDisplay.trimmingCharacters(in: .whitespaces)
            let status: String
            if trimmed.isEmpty {
                status = "FEHLT"
            } else if !g.funFactApproved {
                status = "UNKLAR"
            } else {
                status = "OK"
            }
            rows.append([
                escape(g.firstName),
                escape(g.lastName),
                escape(status),
                escape(trimmed),
                escape("")
            ].joined(separator: ";"))
        }

        // BOM für Excel-Kompatibilität bei Umlauten
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
