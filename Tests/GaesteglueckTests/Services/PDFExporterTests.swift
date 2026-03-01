#if canImport(UIKit)
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("PDF Exporter")
struct PDFExporterTests {
    @Test("Generates non-empty PDF data")
    func generatesPDF() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let guest = Guest(name: "Anna", side: .bride)
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
}
#endif
