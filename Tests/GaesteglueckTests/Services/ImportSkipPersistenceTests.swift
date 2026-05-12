import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Import — übersprungene Anmeldungen werden persistiert")
struct ImportSkipPersistenceTests {
    private static let csvWithThreeRows = """
    Zeitstempel,E-Mail,Familienname,Anzahl,Gäste-Details,Fun Facts,Anmerkungen
    2024-05-01 10:00:00,anna@example.com,Müller,2,"Anna, Fleisch / Bert, Vegetarisch",,
    2024-05-01 11:00:00,carl@example.com,Meier,1,"Carl, Fleisch",,
    2024-05-01 12:00:00,dora@example.com,Schmidt,1,"Dora, Vegan",,
    """

    @Test("Submit ohne Skip-Liste liefert alle Anmeldungen")
    func submitWithoutSkipListYieldsAllRows() async throws {
        let flow = GoogleSheetsImportFlow(
            importer: GoogleSheetsImporter(fetch: { _ in Data(Self.csvWithThreeRows.utf8) }),
            saveBackup: { _, _ in nil }
        )
        await flow.submit(url: "https://docs.google.com/spreadsheets/d/abc/edit")
        let state = await flow.state
        guard case .preview(let rows) = state else {
            Issue.record("expected .preview, got \(state)")
            return
        }
        #expect(rows.count == 3)
    }

    @Test("Übersprungene sourceIDs werden vor der Vorschau rausgefiltert")
    func skippedSourceIDsAreFilteredOut() async throws {
        let flow = GoogleSheetsImportFlow(
            importer: GoogleSheetsImporter(fetch: { _ in Data(Self.csvWithThreeRows.utf8) }),
            saveBackup: { _, _ in nil }
        )
        let skipped: Set<String> = ["email:anna@example.com", "email:dora@example.com"]
        await flow.submit(
            url: "https://docs.google.com/spreadsheets/d/abc/edit",
            skippedSourceIDs: skipped
        )
        let state = await flow.state
        guard case .preview(let rows) = state else {
            Issue.record("expected .preview, got \(state)")
            return
        }
        #expect(rows.count == 1)
        #expect(rows.first?.familyName == "Meier")
        #expect(rows.first?.sourceID == "email:carl@example.com")
    }

    @Test("Skip-Liste mit unbekannten IDs verändert das Ergebnis nicht")
    func unknownSkippedIDsDoNotAffectResult() async throws {
        let flow = GoogleSheetsImportFlow(
            importer: GoogleSheetsImporter(fetch: { _ in Data(Self.csvWithThreeRows.utf8) }),
            saveBackup: { _, _ in nil }
        )
        await flow.submit(
            url: "https://docs.google.com/spreadsheets/d/abc/edit",
            skippedSourceIDs: ["email:nobody@example.com"]
        )
        let state = await flow.state
        guard case .preview(let rows) = state else {
            Issue.record("expected .preview, got \(state)")
            return
        }
        #expect(rows.count == 3)
    }

    @Test("Event speichert skippedSourceIDs als persistente Liste")
    func eventStoresSkippedSourceIDs() {
        let event = Event(name: "Test")
        #expect(event.skippedSourceIDs.isEmpty)
        event.skippedSourceIDs.append("email:foo@example.com")
        event.skippedSourceIDs.append("phone:123")
        #expect(event.skippedSourceIDs.count == 2)
        #expect(event.skippedSourceIDs.contains("email:foo@example.com"))
    }
}
