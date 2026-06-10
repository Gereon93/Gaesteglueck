import Testing
import Foundation
@testable import Gaesteglueck

@Suite("CSVParser RFC 4180")
struct CSVParserTests {
    @Test("Parses simple semicolon CSV")
    func simpleSemicolon() throws {
        let csv = """
        Familienname;Anzahl;Gäste-Details;Fun Facts;Anmerkungen
        Müller;2;Anna, Fleisch;Anna mag Bier;
        """
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].familyName == "Müller")
        #expect(rows[0].guestCount == 2)
        #expect(rows[0].guestDetails == "Anna, Fleisch")
    }

    @Test("Quoted cell with embedded newline keeps the newline")
    func multiLineQuotedCell() throws {
        // Genau das Brandt/Dallmann-Pattern, wie es Google-Forms-Exporte erzeugen
        let csv = "Familienname,Anzahl,Gäste-Details,Fun Facts,Anmerkungen\n" +
                  "Brandt und Dallmann,2,\"Nils Brandt, Fleisch\nMartha Dallmann, Fleisch\",,\n"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].familyName == "Brandt und Dallmann")
        #expect(rows[0].guestDetails.contains("Nils Brandt"))
        #expect(rows[0].guestDetails.contains("Martha Dallmann"))
        // Crucially: das interne Newline ist erhalten geblieben, nicht in 2 Zeilen zerlegt
        #expect(rows[0].guestDetails.contains("\n"))
    }

    @Test("Quoted cell with embedded delimiter")
    func quotedCellWithDelimiter() throws {
        let csv = "Familienname,Anzahl,Gäste-Details\n" +
                  "Stein,2,\"Clara: Vegetarisch, Heike: Fleisch\"\n"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].guestDetails == "Clara: Vegetarisch, Heike: Fleisch")
    }

    @Test("Doubled quotes inside quoted cell become literal quote")
    func doubledQuotesInsideCell() throws {
        let csv = "Familienname,Anzahl,Gäste-Details\n" +
                  "Müller,1,\"Gast \"\"Spitzname\"\" Müller\"\n"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].guestDetails == "Gast \"Spitzname\" Müller")
    }

    @Test("Auto-detects delimiter (tab vs semicolon vs comma)")
    func detectsDelimiter() throws {
        let semi = "Familienname;Anzahl\nA;1\n"
        let comma = "Familienname,Anzahl\nA,1\n"
        let tab = "Familienname\tAnzahl\nA\t1\n"
        for csv in [semi, comma, tab] {
            let rows = try CSVParser.parseRegistrations(csv)
            #expect(rows.count == 1)
            #expect(rows[0].familyName == "A")
            #expect(rows[0].guestCount == 1)
        }
    }

    @Test("Skips rows where attendance is 'Nein'")
    func skipsDeclinedAttendees() throws {
        let csv = "Familienname,Teilnahme,Anzahl\nMüller,Ja,2\nStein,Nein,2\n"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].familyName == "Müller")
    }

    @Test("CRLF line endings are handled")
    func crlfEndings() throws {
        let csv = "Familienname,Anzahl\r\nMüller,2\r\nStein,3\r\n"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 2)
    }

    @Test("Email is captured into sourceID and sourceEmail")
    func sourceIDFromEmail() throws {
        let csv = "Zeitstempel,E-Mail-Adresse,Familienname,Anzahl\n2026-01-01,foo@bar.com,Müller,2\n"
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].sourceEmail == "foo@bar.com")
        #expect(rows[0].sourceID == "email:foo@bar.com")
    }

    @Test("Real Google Forms header — count and details columns are not confused")
    func googleFormsHeaderShape() throws {
        // Typische Header-Struktur eines Google-Forms-Exports
        let csv = """
        Zeitstempel;E-Mail-Adresse;Familienname;Werdet Ihr/Du an unserer Hochzeitsfeier teilnehmen?;Gesamtzahl der Gäste (einschließlich dir selbst), die teilnehmen werden:;Bitte gib für JEDEN Gast (einschließlich dir selbst) die folgenden Informationen an: Name, Vegan/Vegetarisch/Fleisch, Unverträglichkeiten;Bitte für jeden Gast einen kurzen Fun Fact;Weitere Anmerkungen
        2026-01-01;a@b.de;Maier;Ja;1;Horst Maier, Fleisch;Horst: lange Geschichte;-
        """
        let rows = try CSVParser.parseRegistrations(csv)
        #expect(rows.count == 1)
        #expect(rows[0].familyName == "Maier")
        #expect(rows[0].guestCount == 1)
        // Crucially: details ist der echte Freitext, nicht die Anzahl "1"
        #expect(rows[0].guestDetails == "Horst Maier, Fleisch")
        #expect(rows[0].funFacts.contains("Horst"))
    }
}
