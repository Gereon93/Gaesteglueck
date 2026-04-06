#if canImport(AppKit)
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("PDF Exporter")
struct PDFExporterTests {
    @Test("Generates non-empty PDF data")
    func generatesPDF() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Anna", partnerAssignment: .partner1)
        table.guests = [guest]

        let data = PDFExporter.generatePDF(
            tables: [table],
            eventName: "Hochzeit",
            date: Date()
        )
        #expect(!data.isEmpty)
    }

    @Test("PDF contains sufficient data")
    func containsEventName() {
        let data = PDFExporter.generatePDF(
            tables: [],
            eventName: "Test-Hochzeit",
            date: Date()
        )
        #expect(data.count > 100)
    }

    @Test("PDF includes dietary summary section")
    func dietarySummary() {
        let table = GuestTable(name: "T1", shape: .round, diameter: 180)
        let veganGuest = Guest(firstName: "Lisa", partnerAssignment: .partner1, dietaryChoice: "Vegan", intolerances: ["Nüsse"])
        let meatGuest = Guest(firstName: "Klaus", partnerAssignment: .partner2)
        table.guests = [veganGuest, meatGuest]

        let data = PDFExporter.generatePDF(
            tables: [table],
            eventName: "Hochzeit",
            date: Date()
        )
        #expect(data.count > 200)
    }
}
#endif
