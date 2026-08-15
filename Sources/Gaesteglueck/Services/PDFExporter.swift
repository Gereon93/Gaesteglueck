#if os(macOS)
#if canImport(AppKit)
import Foundation
import AppKit
import CoreText
import CoreGraphics

enum PDFExporter {
    struct Options: Sendable {
        var includeTableLists: Bool = true
        var includeCatererSummary: Bool = true
        var highlightAllergies: Bool = true
        var withSeatNumbers: Bool = false
        var withFooter: Bool = true
        var blackAndWhite: Bool = false

        static let `default` = Options()
    }

    static func generatePDF(
        tables: [GuestTable],
        eventName: String,
        date: Date?,
        options: Options = .default,
        partner1Name: String = "",
        partner2Name: String = ""
    ) -> Data {
        let pageRect = PDFPageSize.a4
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return Data() }

        let primaryColor: CGColor = options.blackAndWhite
            ? NSColor.black.cgColor
            : PDFColors.primary.cgColor
        let secondaryColor: CGColor = options.blackAndWhite
            ? NSColor(srgbRed: 0.30, green: 0.30, blue: 0.30, alpha: 1).cgColor
            : PDFColors.secondary.cgColor
        let allergyColor: CGColor = options.blackAndWhite
            ? NSColor.black.cgColor
            : PDFColors.allergy.cgColor

        var pageNumber = 0
        var pageOpen = false

        // Wir zeichnen Top-Down: y=0 ist oben. Beim CGContext ist y=0 unten,
        // also rechnet drawText die y-Koordinate intern um (pageHeight - y - lineHeight).
        // Kein eigener flip-Transform nötig → Core Text rendert sauber.

        func beginPage() {
            pageNumber += 1
            var mediaBox = pageRect
            context.beginPage(mediaBox: &mediaBox)
            pageOpen = true
        }

        func endPage() {
            guard pageOpen else { return }
            context.endPage()
            pageOpen = false
        }

        /// Zeichnet eine Zeile Text per Core Text. point ist Top-Left in
        /// Top-Down-Koordinaten (y=0 oben, y=pageHeight unten).
        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: CGColor? = nil) {
            PDFDrawing.drawText(
                text,
                at: point,
                font: font,
                color: color ?? primaryColor,
                in: context,
                pageRect: pageRect
            )
        }

        func drawFooterIfWanted() {
            guard options.withFooter else { return }
            let fmt = DateFormatter()
            fmt.dateStyle = .short
            fmt.locale = Locale(identifier: "de_DE")
            let stamp = fmt.string(from: Date())
            let footer = "\(eventName) · Stand \(stamp) · Seite \(pageNumber)"
            drawText(footer, at: CGPoint(x: 40, y: pageRect.height - 30), font: .systemFont(ofSize: 9), color: secondaryColor)
        }

        var y: CGFloat = 40

        if options.includeTableLists {
            beginPage()
            y = drawDocumentHeader(title: "Sitzplan: \(eventName)", date: date, drawText: drawText, secondaryColor: secondaryColor, atY: y)
            for table in tables.sorted(by: { $0.name < $1.name }) {
                if y > pageRect.height - 100 {
                    drawFooterIfWanted()
                    endPage()
                    beginPage()
                    y = 40
                }
                let attending = table.attendingGuests
                drawText("\(table.name) (\(table.shape.rawValue), \(attending.count)/\(table.capacity) Plätze)",
                         at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
                y += 22
                if attending.isEmpty {
                    drawText("Keine Gäste zugewiesen", at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12), color: secondaryColor)
                    y += 18
                } else {
                    let sortedGuests: [Guest] = options.withSeatNumbers
                        ? attending.sorted { lhs, rhs in
                            switch (lhs.seatIndex, rhs.seatIndex) {
                            case let (l?, r?): return l < r
                            case (_?, nil): return true
                            case (nil, _?): return false
                            default: return lhs.fullName < rhs.fullName
                            }
                        }
                        : sortByCoupleOrder(guests: attending,
                                            partner1Name: partner1Name,
                                            partner2Name: partner2Name)
                    for guest in sortedGuests {
                        var line = "• "
                        if options.withSeatNumbers {
                            if let idx = guest.seatIndex {
                                line += "Sitz \(idx + 1) · "
                            } else {
                                line += "ohne Platz · "
                            }
                        }
                        line += guest.fullName
                        if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
                        if guest.hasIntolerances { line += " ⚠ \(guest.intolerances.joined(separator: ", "))" }
                        if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
                        let isFlagged = options.highlightAllergies && guest.hasIntolerances
                        let font: NSFont = isFlagged ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 12)
                        let color = isFlagged ? allergyColor : primaryColor
                        drawText(line, at: CGPoint(x: 60, y: y), font: font, color: color)
                        y += 18
                    }
                }
                y += 10
            }
            drawFooterIfWanted()
        }

        if options.includeCatererSummary {
            if options.includeTableLists { endPage() }
            beginPage()
            y = 40
            drawText("Übersicht für den Caterer", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 24))
            y += 35

            let summary = CatererSummary(tables: tables)
            for diet in summary.dietCounts {
                drawText("\(diet.choice): \(diet.count)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12))
                y += 20
            }
            drawText("Gesamt Essen: \(summary.totalMeals)",
                     at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 12))
            y += 20
            y += 6
            // Altersgruppen einzeln auflisten — Caterer braucht das fuer
            // Kindermenue, Hochstuhl-Anzahl etc.
            for age in summary.ageCounts {
                drawText("\(age.category.rawValue): \(age.count)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12))
                y += 20
            }
            drawText("Gesamt Personen: \(summary.totalPersons)",
                     at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 12))
            y += 20
            y += 10

            if !summary.intolerant.isEmpty {
                drawText("Unverträglichkeiten:", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
                y += 22
                for guest in summary.intolerant {
                    let font: NSFont = options.highlightAllergies ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 12)
                    let color = options.highlightAllergies ? allergyColor : primaryColor
                    drawText("  \(guest.fullName): \(guest.intolerances.joined(separator: ", "))",
                             at: CGPoint(x: 60, y: y), font: font, color: color)
                    y += 18
                }
            }

            if !summary.changes.isEmpty {
                y += 10
                drawText("Späte Absagen — Plätze bleiben leer, nicht einplanen:",
                         at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
                y += 22
                let removed = summary.removedDietCounts
                    .map { "−\($0.count) \($0.choice)" }
                    .joined(separator: ", ")
                if !removed.isEmpty {
                    drawText("Wegfall: \(removed)", at: CGPoint(x: 60, y: y), font: .boldSystemFont(ofSize: 12))
                    y += 20
                }
                for change in summary.changes {
                    var line = "  \(change.name) (\(change.tableName))"
                    let detail = CatererSummary.changeDetail(change)
                    if !detail.isEmpty { line += " — \(detail)" }
                    drawText(line, at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12))
                    y += 18
                }
            }
            drawFooterIfWanted()
        }

        endPage()
        context.closePDF()
        return pdfData as Data
    }

    /// Sortiert Gäste eines Tisches so, dass das Brautpaar zuerst kommt (falls am
     /// Tisch sitzend), danach Paare/Familien gruppiert (gleicher registrationGroup),
     /// danach Einzelpersonen — innerhalb jeder Gruppe alphabetisch stabil.
    private static func sortByCoupleOrder(
        guests: [Guest],
        partner1Name: String,
        partner2Name: String
    ) -> [Guest] {
        func isBridalCouple(_ g: Guest, _ name: String) -> Bool {
            guard !name.isEmpty else { return false }
            return g.firstName == name || g.fullName == name
        }

        // Gruppen-Anker = alphabetisch erster Name innerhalb derselben registrationGroup;
        // ohne Gruppe = der eigene Name. Sorgt dafür dass Mitglieder einer Gruppe
        // im sortierten Output direkt nacheinander stehen.
        var groupAnchor: [UUID: String] = [:]
        let byGroup = Dictionary(grouping: guests) { $0.registrationGroup }
        for (gid, members) in byGroup {
            guard gid != nil else { continue }
            let anchor = members.map(\.fullName).min() ?? ""
            for m in members { groupAnchor[m.id] = anchor }
        }

        return guests.sorted { lhs, rhs in
            let lhsBride1 = isBridalCouple(lhs, partner1Name)
            let lhsBride2 = isBridalCouple(lhs, partner2Name)
            let rhsBride1 = isBridalCouple(rhs, partner1Name)
            let rhsBride2 = isBridalCouple(rhs, partner2Name)
            let lhsPrio = lhsBride1 ? 0 : (lhsBride2 ? 1 : 2)
            let rhsPrio = rhsBride1 ? 0 : (rhsBride2 ? 1 : 2)
            if lhsPrio != rhsPrio { return lhsPrio < rhsPrio }

            let lhsAnchor = groupAnchor[lhs.id] ?? lhs.fullName
            let rhsAnchor = groupAnchor[rhs.id] ?? rhs.fullName
            if lhsAnchor != rhsAnchor { return lhsAnchor < rhsAnchor }
            return lhs.fullName < rhs.fullName
        }
    }

    private static func drawDocumentHeader(
        title: String,
        date: Date?,
        drawText: (String, CGPoint, NSFont, CGColor?) -> Void,
        secondaryColor: CGColor,
        atY startY: CGFloat
    ) -> CGFloat {
        var y = startY
        drawText(title, CGPoint(x: 40, y: y), .boldSystemFont(ofSize: 24), nil)
        y += 35
        if let date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.locale = Locale(identifier: "de_DE")
            drawText(fmt.string(from: date), CGPoint(x: 40, y: y), .systemFont(ofSize: 14), secondaryColor)
            y += 25
        }
        return y + 15
    }
}
#endif
#endif
