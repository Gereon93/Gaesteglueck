#if canImport(AppKit)
import Foundation
import AppKit

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

    static func generatePDF(tables: [GuestTable], eventName: String, date: Date?, options: Options = .default) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return Data() }

        let primaryColor: NSColor = options.blackAndWhite ? .black : .labelColor
        let secondaryColor: NSColor = options.blackAndWhite ? NSColor(white: 0.35, alpha: 1) : .secondaryLabelColor
        let allergyColor: NSColor = options.blackAndWhite ? .black : NSColor(srgbRed: 0.77, green: 0.29, blue: 0.29, alpha: 1)

        var pageNumber = 0

        func beginPage() {
            pageNumber += 1
            var mediaBox = pageRect
            context.beginPage(mediaBox: &mediaBox)
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
        }

        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor? = nil) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color ?? primaryColor]
            (text as NSString).draw(at: point, withAttributes: attrs)
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
                    context.endPage()
                    beginPage()
                    y = 40
                }
                drawText("\(table.name) (\(table.shape.rawValue), \(table.guests.count)/\(table.capacity) Plätze)", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
                y += 22
                if table.guests.isEmpty {
                    drawText("Keine Gäste zugewiesen", at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12), color: secondaryColor)
                    y += 18
                } else {
                    let sortedGuests: [Guest] = options.withSeatNumbers
                        ? table.guests.sorted { lhs, rhs in
                            switch (lhs.seatIndex, rhs.seatIndex) {
                            case let (l?, r?): return l < r
                            case (_?, nil): return true
                            case (nil, _?): return false
                            default: return lhs.fullName < rhs.fullName
                            }
                        }
                        : table.guests.sorted { $0.fullName < $1.fullName }
                    for guest in sortedGuests {
                        var line = "\u{2022} "
                        if options.withSeatNumbers {
                            if let idx = guest.seatIndex {
                                line += "Sitz \(idx + 1) · "
                            } else {
                                line += "ohne Platz · "
                            }
                        }
                        line += guest.fullName
                        if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
                        if guest.hasIntolerances { line += " \u{26A0}\u{FE0F} \(guest.intolerances.joined(separator: ", ")) " }
                        if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
                        let isFlagged = options.highlightAllergies && guest.hasIntolerances
                        let font: NSFont = isFlagged ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 12)
                        let color: NSColor = isFlagged ? allergyColor : primaryColor
                        drawText(line, at: CGPoint(x: 60, y: y), font: font, color: color)
                        y += 18
                    }
                }
                y += 10
            }
            drawFooterIfWanted()
        }

        if options.includeCatererSummary {
            if options.includeTableLists { context.endPage() }
            beginPage()
            y = 40
            drawText("Übersicht für den Caterer", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 24))
            y += 35

            let allGuests = tables.flatMap(\.guests)
            let counts = Dictionary(grouping: allGuests, by: \.dietaryChoice).mapValues(\.count)
            for (choice, count) in counts.sorted(by: { $0.key < $1.key }) {
                drawText("\(choice): \(count)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12))
                y += 20
            }
            let childCount = allGuests.filter { $0.ageCategory != .adult }.count
            drawText("Kinder: \(childCount)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12))
            y += 30

            let withIntolerances = allGuests.filter(\.hasIntolerances)
            if !withIntolerances.isEmpty {
                drawText("Unverträglichkeiten:", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
                y += 22
                for guest in withIntolerances.sorted(by: { $0.fullName < $1.fullName }) {
                    let font: NSFont = options.highlightAllergies ? .boldSystemFont(ofSize: 12) : .systemFont(ofSize: 12)
                    let color: NSColor = options.highlightAllergies ? allergyColor : primaryColor
                    drawText("  \(guest.fullName): \(guest.intolerances.joined(separator: ", "))", at: CGPoint(x: 60, y: y), font: font, color: color)
                    y += 18
                }
            }
            drawFooterIfWanted()
        }

        if pageNumber > 0 { context.endPage() }
        context.closePDF()
        return pdfData as Data
    }

    private static func drawDocumentHeader(
        title: String,
        date: Date?,
        drawText: (String, CGPoint, NSFont, NSColor?) -> Void,
        secondaryColor: NSColor,
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
