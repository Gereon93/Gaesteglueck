import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Importer")
struct GuestImporterTests {

    // --- CSV Parsing ---

    @Test("Parses simple CSV with name column")
    func parseSimpleCSV() throws {
        let csv = """
        Familie/Name,Anzahl
        Schmidt,2
        Müller,1
        """
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 2)
        #expect(rows[0].familyName == "Schmidt")
        #expect(rows[0].guestCount == 2)
    }

    @Test("CSV handles semicolon delimiter")
    func semicolonCSV() throws {
        let csv = "Familie/Name;Anzahl;Anmerkungen\nSchmidt;3;Vegetarisch bitte"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows[0].guestCount == 3)
        #expect(rows[0].notes == "Vegetarisch bitte")
    }

    @Test("CSV filters non-attending rows")
    func filterNonAttending() throws {
        let csv = """
        Name,Teilnahme,Anzahl
        Schmidt,Ja,2
        Müller,Nein,1
        """
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].familyName == "Schmidt")
    }

    @Test("CSV handles tab delimiter")
    func tabCSV() throws {
        let csv = "Name\tAnzahl\nSchmidt\t3"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].guestCount == 3)
    }

    @Test("CSV throws on empty file")
    func emptyCSV() {
        let csv = ""
        #expect(throws: ImportError.self) {
            try CSVParser.parseRegistrations(csv)
        }
    }

    @Test("CSV parses fun facts")
    func funFactCSV() throws {
        let csv = """
        Name,Fun Fact
        Schmidt,Liebt Tanzen
        """
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows[0].funFacts == "Liebt Tanzen")
    }
}
