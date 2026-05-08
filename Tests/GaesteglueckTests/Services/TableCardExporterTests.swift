#if canImport(AppKit)
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("TableCardExporter")
struct TableCardExporterTests {
    @Test("Empty guest list still produces valid PDF data")
    func emptyGuests() {
        let data = TableCardExporter.generatePDF(guests: [], eventName: "Hochzeit Test")
        #expect(data.count > 100)
    }

    @Test("Single guest produces non-empty PDF")
    func singleGuest() {
        let guest = Guest(firstName: "Anna", lastName: "Müller", partnerAssignment: .partner1)
        guest.funFact = "Liest jedes Jahr 50 Bücher"
        let data = TableCardExporter.generatePDF(guests: [guest], eventName: "Hochzeit Test")
        #expect(data.count > 200)
    }

    @Test("Many guests produce larger PDF than few")
    func paginationGrowsData() {
        let fewGuests = (0..<3).map { i in
            Guest(firstName: "Gast\(i)", partnerAssignment: .partner1)
        }
        let manyGuests = (0..<25).map { i in
            Guest(firstName: "Gast\(i)", partnerAssignment: .partner1)
        }
        let smallData = TableCardExporter.generatePDF(guests: fewGuests, eventName: "Hochzeit")
        let largeData = TableCardExporter.generatePDF(guests: manyGuests, eventName: "Hochzeit")
        #expect(largeData.count > smallData.count)
    }

    @Test("Guests are sorted alphabetically by full name")
    func sortedByName() {
        let zara = Guest(firstName: "Zara", lastName: "Adler", partnerAssignment: .partner1)
        let anna = Guest(firstName: "Anna", lastName: "Berg", partnerAssignment: .partner1)
        let result = TableCardExporter.sortedByFullName([zara, anna])
        #expect(result.first?.firstName == "Anna")
        #expect(result.last?.firstName == "Zara")
        let data = TableCardExporter.generatePDF(guests: [zara, anna], eventName: "Hochzeit")
        #expect(!data.isEmpty)
    }
}
#endif
