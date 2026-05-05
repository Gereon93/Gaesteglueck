import Foundation

enum GoogleSheetsImportError: Error, Equatable, LocalizedError {
    case invalidURL
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Wir konnten aus diesem Link keine Sheet-ID lesen. Stell sicher, dass es ein Google-Sheets-Link ist."
        case .invalidEncoding:
            "Die Antwort von Google ist nicht lesbar. Ist das Sheet öffentlich freigegeben (Jeder mit dem Link)?"
        }
    }
}

struct GoogleSheetsImporter: Sendable {
    typealias Fetch = @Sendable (URL) async throws -> Data

    let fetch: Fetch

    static let live = GoogleSheetsImporter(fetch: { url in
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    })

    /// Lädt eine öffentlich freigegebene Google-Tabelle als CSV-Text.
    /// Das Sheet muss auf "Jeder mit dem Link kann ansehen" stehen.
    func fetchCSV(from input: String) async throws -> String {
        guard let url = GoogleSheetsURL.csvExportURL(from: input) else {
            throw GoogleSheetsImportError.invalidURL
        }
        let data = try await fetch(url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw GoogleSheetsImportError.invalidEncoding
        }
        return string
    }
}
