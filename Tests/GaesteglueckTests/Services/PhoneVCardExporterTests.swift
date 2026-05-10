import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Phone vCard Exporter")
struct PhoneVCardExporterTests {
    @Test("Ueberspringt Gaeste ohne Telefonnummer")
    func skipsWithoutPhone() {
        let withPhone = Guest(firstName: "Anna", lastName: "Beispiel")
        withPhone.phoneNumber = "+49 170 1234567"
        let withoutPhone = Guest(firstName: "Bert", lastName: "Beispiel")

        let data = PhoneVCardExporter.generate(guests: [withPhone, withoutPhone], eventName: "Hochzeit")
        let text = String(data: data, encoding: .utf8) ?? ""

        #expect(text.contains("FN:Anna Beispiel"))
        #expect(text.contains("TEL;TYPE=CELL:+49 170 1234567"))
        #expect(!text.contains("Bert"))
    }

    @Test("Eine vCard pro Gast mit BEGIN/END")
    func multipleCards() {
        let g1 = Guest(firstName: "Anna", lastName: "B")
        g1.phoneNumber = "111"
        let g2 = Guest(firstName: "Carla", lastName: "D")
        g2.phoneNumber = "222"

        let text = String(data: PhoneVCardExporter.generate(guests: [g1, g2], eventName: "Hochzeit"),
                          encoding: .utf8) ?? ""
        let beginCount = text.components(separatedBy: "BEGIN:VCARD").count - 1
        let endCount = text.components(separatedBy: "END:VCARD").count - 1
        #expect(beginCount == 2)
        #expect(endCount == 2)
        #expect(text.contains("CATEGORIES:Gäste Hochzeit"))
    }

    @Test("Sortiert alphabetisch nach fullName")
    func sortedAlphabetically() {
        let bert = Guest(firstName: "Bert", lastName: "")
        bert.phoneNumber = "1"
        let anna = Guest(firstName: "Anna", lastName: "")
        anna.phoneNumber = "2"

        let text = String(data: PhoneVCardExporter.generate(guests: [bert, anna], eventName: "X"),
                          encoding: .utf8) ?? ""
        let annaIdx = text.range(of: "FN:Anna")?.lowerBound
        let bertIdx = text.range(of: "FN:Bert")?.lowerBound
        #expect(annaIdx != nil && bertIdx != nil && annaIdx! < bertIdx!)
    }

    @Test("Escapet Sonderzeichen in Namen")
    func escapesSpecialChars() {
        let g = Guest(firstName: "Anna; Maria", lastName: "Müller, geb. Schmidt")
        g.phoneNumber = "1"
        let text = String(data: PhoneVCardExporter.generate(guests: [g], eventName: "X"),
                          encoding: .utf8) ?? ""
        #expect(text.contains("Anna\\; Maria"))
        #expect(text.contains("Müller\\, geb. Schmidt"))
    }
}
