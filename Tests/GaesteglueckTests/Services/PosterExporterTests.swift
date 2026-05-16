#if canImport(AppKit)
import Testing
import Foundation
@testable import Gaesteglueck

@Suite("PosterExporter")
struct PosterExporterTests {
    @Test("Generates non-empty PDF for empty room")
    func emptyRoom() {
        let data = PosterExporter.generatePDF(
            tables: [],
            unassignedGuests: [],
            eventName: "Hochzeit",
            date: nil
        )
        #expect(data.count > 100)
    }

    @Test("Single table with guests produces poster")
    func singleTable() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Anna", lastName: "Müller", partnerAssignment: .partner1)
        table.guests = [guest]

        let data = PosterExporter.generatePDF(
            tables: [table],
            unassignedGuests: [],
            eventName: "Hochzeit",
            date: Date()
        )
        #expect(data.count > 200)
    }

    @Test("Unassigned guests do not appear on the spatial poster")
    func unassignedGuestsIgnored() {
        let unassigned = (0..<3).map { i in
            Guest(firstName: "Fremd\(i)", partnerAssignment: .partner1)
        }
        let withUnassigned = PosterExporter.generatePDF(
            tables: [],
            unassignedGuests: unassigned,
            eventName: "Hochzeit",
            date: nil
        )
        let empty = PosterExporter.generatePDF(
            tables: [],
            unassignedGuests: [],
            eventName: "Hochzeit",
            date: nil
        )
        #expect(withUnassigned.count == empty.count)
    }

    @Test("Many tables produce larger poster than few")
    func sizeGrows() {
        let few = (0..<2).map {
            let t = GuestTable(name: "T\($0)", shape: .round, diameter: 180)
            t.positionX = Double($0) * 200
            t.positionY = 0
            return t
        }
        let many = (0..<10).map {
            let t = GuestTable(name: "T\($0)", shape: .round, diameter: 180)
            t.positionX = Double($0 % 5) * 200
            t.positionY = Double($0 / 5) * 200
            return t
        }
        let smallData = PosterExporter.generatePDF(tables: few, unassignedGuests: [], eventName: "H", date: nil)
        let largeData = PosterExporter.generatePDF(tables: many, unassignedGuests: [], eventName: "H", date: nil)
        #expect(largeData.count > smallData.count)
    }
}
#endif
