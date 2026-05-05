import Testing
import Foundation
@testable import Gaesteglueck

@Suite("GoogleSheetsImportFlow")
struct GoogleSheetsImportFlowTests {
    @Test("Initial state is idle")
    func initialIdle() async {
        let flow = GoogleSheetsImportFlow(importer: .stub(""))
        let state = await flow.state
        #expect(state == .idle)
    }

    @Test("Successful submit produces preview with parsed rows")
    func successfulSubmit() async throws {
        let csv = "Familienname,Anzahl,Gäste\nMüller,2,Anna Bert\n"
        let flow = GoogleSheetsImportFlow(importer: .stub(csv))
        await flow.submit(url: "https://docs.google.com/spreadsheets/d/abc/edit")
        let state = await flow.state
        guard case .preview(let rows) = state else {
            Issue.record("expected .preview, got \(state)")
            return
        }
        #expect(rows.count == 1)
        #expect(rows.first?.familyName == "Müller")
    }

    @Test("Invalid URL surfaces friendly error")
    func invalidURL() async {
        let flow = GoogleSheetsImportFlow(importer: .stub(""))
        await flow.submit(url: "not a url")
        let state = await flow.state
        guard case .error(let msg) = state else {
            Issue.record("expected .error, got \(state)")
            return
        }
        #expect(msg.contains("Sheet-ID"))
    }

    @Test("Empty CSV body surfaces friendly error")
    func emptyCSV() async {
        let flow = GoogleSheetsImportFlow(importer: .stub(""))
        await flow.submit(url: "https://docs.google.com/spreadsheets/d/abc/edit")
        let state = await flow.state
        guard case .error = state else {
            Issue.record("expected .error, got \(state)")
            return
        }
    }

    @Test("HTML response (private sheet) surfaces friendly error")
    func htmlResponseSurfacesError() async {
        let html = "<html><body>Login required</body></html>"
        let flow = GoogleSheetsImportFlow(importer: .stub(html))
        await flow.submit(url: "https://docs.google.com/spreadsheets/d/abc/edit")
        let state = await flow.state
        guard case .error(let msg) = state else {
            Issue.record("expected .error, got \(state)")
            return
        }
        #expect(msg.contains("Anmeldung") || msg.contains("freigegeben"))
    }

    @Test("Submitting transitions through loading")
    func loadingState() async throws {
        let csv = "Familienname,Anzahl\nTest,1\n"
        let flow = GoogleSheetsImportFlow(importer: .stub(csv))
        await flow.submit(url: "https://docs.google.com/spreadsheets/d/abc/edit")
        let history = await flow.stateHistory
        #expect(history.contains(.loading))
    }
}

private extension GoogleSheetsImporter {
    static func stub(_ body: String) -> GoogleSheetsImporter {
        GoogleSheetsImporter(fetch: { _ in Data(body.utf8) })
    }
}
