import Foundation

enum GoogleSheetsURL {
    /// Wandelt eine Google-Sheets-URL (z. B. eine Edit- oder Share-URL) in eine
    /// CSV-Export-URL um. Funktioniert mit dem öffentlichen `export?format=csv`
    /// Endpunkt — kein OAuth, das Sheet muss "Jeder mit dem Link" freigegeben sein.
    /// Gibt `nil` zurück, wenn keine Sheet-ID extrahierbar ist.
    static func csvExportURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = extractSheetID(trimmed) else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "docs.google.com"
        components.path = "/spreadsheets/d/\(id)/export"

        var items = [URLQueryItem(name: "format", value: "csv")]
        if let gid = extractGID(trimmed) {
            items.append(URLQueryItem(name: "gid", value: gid))
        }
        components.queryItems = items

        return components.url
    }

    private static func extractSheetID(_ input: String) -> String? {
        // Pattern: /spreadsheets/d/<ID>/...
        guard let range = input.range(of: #"/spreadsheets/d/([a-zA-Z0-9_-]+)"#, options: .regularExpression) else {
            return nil
        }
        let match = String(input[range])
        return match.replacingOccurrences(of: "/spreadsheets/d/", with: "")
    }

    private static func extractGID(_ input: String) -> String? {
        guard let range = input.range(of: #"gid=([0-9]+)"#, options: .regularExpression) else {
            return nil
        }
        return String(input[range]).replacingOccurrences(of: "gid=", with: "")
    }
}
