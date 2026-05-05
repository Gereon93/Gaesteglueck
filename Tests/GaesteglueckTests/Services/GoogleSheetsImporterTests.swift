import Testing
import Foundation
@testable import Gaesteglueck

private actor URLCapture {
    var url: URL?
    func set(_ u: URL) { url = u }
}

@Suite("GoogleSheetsImporter")
struct GoogleSheetsImporterTests {
    @Test("Invalid URL throws invalidURL")
    func invalidURLThrows() async {
        let importer = GoogleSheetsImporter(fetch: { _ in Data() })
        await #expect(throws: GoogleSheetsImportError.invalidURL) {
            try await importer.fetchCSV(from: "not a url")
        }
    }

    @Test("Valid URL returns CSV body")
    func validURLReturnsBody() async throws {
        let payload = "Name,Anzahl\nMüller,3\n"
        let importer = GoogleSheetsImporter(fetch: { _ in
            Data(payload.utf8)
        })
        let csv = try await importer.fetchCSV(from: "https://docs.google.com/spreadsheets/d/abc/edit")
        #expect(csv == payload)
    }

    @Test("Fetcher receives the transformed export URL")
    func fetcherReceivesExportURL() async throws {
        let capture = URLCapture()
        let importer = GoogleSheetsImporter(fetch: { url in
            await capture.set(url)
            return Data("ok".utf8)
        })
        _ = try await importer.fetchCSV(from: "https://docs.google.com/spreadsheets/d/sheet1/edit#gid=42")
        let captured = await capture.url
        #expect(captured?.absoluteString == "https://docs.google.com/spreadsheets/d/sheet1/export?format=csv&gid=42")
    }

    @Test("Non-UTF8 data throws invalidEncoding")
    func nonUTF8Throws() async {
        let importer = GoogleSheetsImporter(fetch: { _ in
            Data([0xFF, 0xFE, 0xFD])
        })
        await #expect(throws: GoogleSheetsImportError.invalidEncoding) {
            try await importer.fetchCSV(from: "https://docs.google.com/spreadsheets/d/abc/edit")
        }
    }

    @Test("Network error propagates")
    func networkErrorPropagates() async {
        struct DummyError: Error {}
        let importer = GoogleSheetsImporter(fetch: { _ in throw DummyError() })
        await #expect(throws: DummyError.self) {
            try await importer.fetchCSV(from: "https://docs.google.com/spreadsheets/d/abc/edit")
        }
    }
}
