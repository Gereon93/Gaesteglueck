import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Importer")
struct GuestImporterTests {

    // --- CSV Parsing ---

    @Test("Parses simple CSV with name and side")
    func parseSimpleCSV() throws {
        let csv = """
        Name,Seite
        Anna Schmidt,Braut
        Klaus Müller,Bräutigam
        """
        let families = try CSVParser.parse(csv)
        #expect(families.count == 2)
        #expect(families[0].members[0].name == "Anna Schmidt")
    }

    @Test("CSV handles semicolon delimiter")
    func semicolonCSV() throws {
        let csv = "Name;Seite;Essen\nAnna;Braut;Vegetarisch"
        let families = try CSVParser.parse(csv)
        #expect(families[0].members[0].dietaryPreference == .vegetarian)
    }

    @Test("CSV parses dietary and allergy columns")
    func dietaryCSV() throws {
        let csv = """
        Name,Seite,Essen,Unverträglichkeiten
        Lisa,Braut,Vegan,Nüsse
        Tom,Bräutigam,Fleisch,
        """
        let families = try CSVParser.parse(csv)
        #expect(families[0].members[0].dietaryPreference == .vegan)
        #expect(families[0].members[0].allergies == "Nüsse")
        #expect(families[1].members[0].dietaryPreference == .meat)
    }

    @Test("CSV parses couple row with '&' separator")
    func coupleRowCSV() throws {
        let csv = """
        Name,Seite,Essen
        Klaus & Erika Müller,Braut,Fleisch
        """
        let families = try CSVParser.parse(csv)
        #expect(families.count == 1)
        #expect(families[0].members.count == 2)
        #expect(families[0].members[0].name == "Klaus Müller")
        #expect(families[0].members[1].name == "Erika Müller")
        #expect(families[0].sharedFamilyID != nil)
    }

    @Test("CSV parses couple row with 'und' separator")
    func coupleUndCSV() throws {
        let csv = """
        Name,Seite
        Max und Lisa Becker,Braut
        """
        let families = try CSVParser.parse(csv)
        #expect(families[0].members.count == 2)
        #expect(families[0].members[0].name == "Max Becker")
        #expect(families[0].members[1].name == "Lisa Becker")
    }

    @Test("CSV throws on missing name column")
    func missingNameCSV() {
        let csv = "Seite\nBraut"
        #expect(throws: ImportError.self) {
            try CSVParser.parse(csv)
        }
    }

    // --- Family Expansion ---

    @Test("Family row with children expands correctly")
    func familyWithChildren() throws {
        let csv = """
        Name,Seite,Kinder
        Klaus & Erika Müller,Braut,Max (8) und Lina (5)
        """
        let families = try CSVParser.parse(csv)
        #expect(families[0].members.count == 4)
        #expect(families[0].members[2].name == "Max Müller")
        #expect(families[0].members[2].isChild == true)
        #expect(families[0].members[3].name == "Lina Müller")
    }
}
