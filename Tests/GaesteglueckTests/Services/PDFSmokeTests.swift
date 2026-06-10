#if canImport(AppKit)
import Testing
import Foundation
@testable import Gaesteglueck

/// Smoke-Test: erzeugt mit realistischen Sample-Daten alle PDF-Exporte und
/// schreibt sie nach /tmp/gpdf-smoke/. Dient nur dem manuellen Sichten —
/// die Assertions pruefen, dass die Files nicht leer sind.
@Suite("PDF Smoke")
struct PDFSmokeTests {
    @Test("Exportiert alle PDFs mit reichhaltigen Sample-Daten")
    func exportSamples() throws {
        let outDir = URL(fileURLWithPath: "/tmp/gpdf-smoke", isDirectory: true)
        try? FileManager.default.removeItem(at: outDir)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let event = Event(
            name: "Hochzeit",
            date: Date(timeIntervalSince1970: 1_780_704_000),
            venue: "Gut Beispiel",
            partner1Name: "Gereon",
            partner2Name: "Maria"
        )

        // 5 Tische mit verschiedenen Formen + Rotation
        let brauttisch = GuestTable(name: "Brauttafel", shape: .rectangular,
                                    width: 240, depth: 80,
                                    rotation: 0,
                                    isBridalTable: true)
        brauttisch.positionX = 600
        brauttisch.positionY = 200

        let t1 = GuestTable(name: "Familie Maier", shape: .round, diameter: 180)
        t1.positionX = 200
        t1.positionY = 400
        let t2 = GuestTable(name: "Freunde Gereon", shape: .round, diameter: 180)
        t2.positionX = 500
        t2.positionY = 500
        t2.rotation = 30
        let t3 = GuestTable(name: "Freunde Maria", shape: .round, diameter: 180)
        t3.positionX = 800
        t3.positionY = 500
        let t4 = GuestTable(name: "Familie Mustermann", shape: .square, width: 140, depth: 140)
        t4.positionX = 350
        t4.positionY = 700
        t4.rotation = -15

        let allTables = [brauttisch, t1, t2, t3, t4]

        func assign(_ table: GuestTable, _ guests: [Guest]) {
            for (idx, g) in guests.enumerated() {
                g.seatIndex = idx
                g.table = table
            }
            table.guests = guests
        }

        // Brautpaar + 6 Trauzeugen an der Brauttafel
        let g0a = guest("Max", "Beispiel", side: .partner1, diet: "Fleisch", funFact: "Hat schon mal ein eigenes Gedicht im Gemeindeblatt veröffentlicht")
        let g0b = guest("Maria", "Beispiel", side: .partner2, diet: "Vegetarisch", funFact: "Sammelt alte Kochbücher vom Flohmarkt")
        g0a.isPinned = true
        g0b.isPinned = true
        assign(brauttisch, [g0a, g0b,
                             guest("Lea", "Trauzeugin", side: .partner2, diet: "Vegan"),
                             guest("Max", "Trauzeuge", side: .partner1, diet: "Fleisch", intolerances: ["Nuesse"]),
                             guest("Anna", "Schwester", side: .partner2, diet: "Vegetarisch"),
                             guest("Jonas", "Bruder", side: .partner1, diet: "Fleisch")])

        // Familie Maier — 8 Personen, mit Allergien
        assign(t1, [
            guest("Horst", "Maier", side: .partner1, diet: "Fleisch"),
            guest("Inge", "Maier", side: .partner1, diet: "Vegetarisch", intolerances: ["Laktose"]),
            guest("Peter", "Maier", side: .partner1, diet: "Fleisch"),
            guest("Marie", "Maier", side: .partner1, diet: "Vegan", intolerances: ["Gluten"]),
            guest("Tom", "Maier", side: .partner1, age: .child, diet: "Fleisch"),
            guest("Lena", "Maier", side: .partner1, age: .toddler, diet: "Vegetarisch"),
            guest("Oma", "Maier", side: .partner1, diet: "Fleisch"),
            guest("Opa", "Maier", side: .partner1, diet: "Fleisch")
        ])

        assign(t2, (1...8).map { i in
            guest("Freund\(i)", "Gereons", side: .partner1, diet: i % 3 == 0 ? "Vegetarisch" : "Fleisch",
                  funFact: i % 2 == 0 ? "Hat als Kind eine ganze Woche im Zelt im Garten geschlafen" : "")
        })
        assign(t3, (1...8).map { i in
            guest("Freundin\(i)", "Marias", side: .partner2,
                  diet: i % 4 == 0 ? "Vegan" : "Vegetarisch",
                  intolerances: i == 3 ? ["Histamin"] : [])
        })
        assign(t4, (1...4).map { i in
            guest("Cousin\(i)", "Mustermann", side: .partner1, diet: "Fleisch")
        })

        let allGuests = allTables.flatMap(\.guests) + [
            // Plus noch ein paar nicht zugewiesene
            guest("Plus", "Eins", side: .both, diet: "Fleisch"),
            guest("Spaeter", "Anmeldung", side: .both, diet: "Vegetarisch")
        ]

        // 1) Tischlisten + Caterer
        let pdfTablelists = PDFExporter.generatePDF(
            tables: allTables, eventName: event.name, date: event.date,
            options: PDFExporter.Options()
        )
        try pdfTablelists.write(to: outDir.appendingPathComponent("01-tischlisten.pdf"))
        #expect(pdfTablelists.count > 1000)

        // 2) Tischkarten
        let pdfCards = TableCardExporter.generatePDF(guests: allGuests, eventName: event.name)
        try pdfCards.write(to: outDir.appendingPathComponent("02-tischkarten.pdf"))
        #expect(pdfCards.count > 1000)

        // 3) Plakat
        let unassigned = allGuests.filter { $0.table == nil }
        let pdfPoster = PosterExporter.generatePDF(
            tables: allTables, unassignedGuests: unassigned,
            eventName: event.name, date: event.date
        )
        try pdfPoster.write(to: outDir.appendingPathComponent("03-plakat.pdf"))
        #expect(pdfPoster.count > 1000)

        // 4) Bildlicher Sitzplan — alle vier Namens-Stile
        for style in VisualSeatingPlanExporter.NameStyle.allCases {
            let pdf = VisualSeatingPlanExporter.generatePDF(
                tables: allTables, eventName: event.name, date: event.date,
                nameStyle: style
            )
            try pdf.write(to: outDir.appendingPathComponent("04-bildlich-\(style.rawValue.replacingOccurrences(of: " ", with: "_")).pdf"))
            #expect(pdf.count > 1000)
        }

        // 5) FunFact-Worklist
        let pdfFunFact = FunFactWorklistExporter.generatePDF(
            guests: allGuests.filter { $0.funFact.isEmpty || !$0.funFactApproved },
            title: "FunFact-Liste \(event.name)"
        )
        try pdfFunFact.write(to: outDir.appendingPathComponent("05-funfacts.pdf"))

        // 6) Spielkarten
        let pdfGame = FunFactGameCardsExporter.generatePDF(
            guests: allGuests.filter { !$0.funFact.isEmpty },
            eventName: event.name
        )
        try pdfGame.write(to: outDir.appendingPathComponent("06-spielkarten.pdf"))

        // 7) vCards
        let vcf = PhoneVCardExporter.generate(guests: allGuests, eventName: event.name)
        try vcf.write(to: outDir.appendingPathComponent("07-telefon.vcf"))

        // 8) Canvas-PNG (kein Saalplan-Bild im Test, nur Tische)
        if let png = VisualSeatingPlanExporter.generatePNG(
            tables: allTables,
            labels: [],
            roomBackground: nil,
            roomCMSize: CGSize(width: 1200, height: 900),
            nameStyle: .smartDeduped
        ) {
            try png.write(to: outDir.appendingPathComponent("08-canvas.png"))
            #expect(png.count > 5000)
        }

        print("\n✅ Smoke-PDFs unter:", outDir.path)
    }

    /// Rendert die Canvas-PNG (ImageRenderer-Pfad) mit allen Anzeige-Optionen,
    /// damit die Namen-Positionierung & neuen Indikatoren manuell prüfbar sind.
    @Test("Canvas-PNG rendert mit Diät/Alter/Allergie + Legende")
    @MainActor
    func canvasPNGSmoke() throws {
        let outDir = URL(fileURLWithPath: "/tmp/gpdf-smoke", isDirectory: true)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        let t = GuestTable(name: "T1", shape: .rectangular, width: 80, depth: 320, rotation: 90)
        t.positionX = 400; t.positionY = 400
        let guests = [
            guest("Regina", "Albers", side: .partner1, diet: "Vegetarisch"),
            guest("Lilli", "Gold", side: .partner1, diet: "Vegan"),
            guest("Karen", "Fuchs", side: .partner2, intolerances: ["Gluten", "Weizen"]),
            guest("Henriette", "Klein", side: .partner2, age: .child),
            guest("Max", "Becker", side: .partner1, age: .baby),
            guest("Sebastian", "Schmidt", side: .partner2)
        ]
        for (i, g) in guests.enumerated() { g.table = t; g.seatIndex = i }

        let names = VisualSeatingPlanExporter.displayNames(for: guests, style: .full)
        let legend = SeatingLegend(guests: guests)
        if let png = CanvasImageExporter.generatePNG(
            tables: [t], displayNames: names, rules: .default, scale: 1.0,
            showSeatNames: true, infoDisplay: .all, showAgeMarkers: true,
            chipContent: .initials, showTableWarnings: true,
            showRoomLabels: true, showLegend: true, legend: legend
        ) {
            try png.write(to: outDir.appendingPathComponent("09-canvas-render.png"))
            #expect(png.count > 5000)
        }
        // Variante: Allergen-Nummer direkt im Kreis
        if let png2 = CanvasImageExporter.generatePNG(
            tables: [t], displayNames: names, rules: .default, scale: 1.0,
            showSeatNames: true, infoDisplay: .all, showAgeMarkers: true,
            chipContent: .intolerance, showTableWarnings: true,
            showRoomLabels: true, showLegend: true, legend: legend
        ) {
            try png2.write(to: outDir.appendingPathComponent("09b-canvas-content-intol.png"))
            #expect(png2.count > 5000)
        }
        print("\n✅ Canvas-Render-PNGs unter:", outDir.path)
    }

    // MARK: - Builders

    private func guest(_ first: String, _ last: String,
                       side: PartnerAssignment,
                       age: AgeCategory = .adult,
                       diet: String = "Fleisch",
                       intolerances: [String] = [],
                       funFact: String = "",
                       phoneNumber: String = "") -> Guest {
        let g = Guest(firstName: first, lastName: last, partnerAssignment: side,
                      ageCategory: age, dietaryChoice: diet,
                      intolerances: intolerances, funFact: funFact)
        g.phoneNumber = phoneNumber
        return g
    }
}
#endif
