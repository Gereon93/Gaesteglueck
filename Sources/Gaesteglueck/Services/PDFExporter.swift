#if canImport(AppKit)
import Foundation
import AppKit

enum PDFExporter {
    static func generatePDF(tables: [GuestTable], eventName: String, date: Date?) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return Data() }

        func beginPage() {
            var mediaBox = pageRect
            context.beginPage(mediaBox: &mediaBox)
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
        }

        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = .labelColor) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            (text as NSString).draw(at: point, withAttributes: attrs)
        }

        beginPage()
        var y: CGFloat = 40

        drawText("Sitzplan: \(eventName)", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 24))
        y += 35

        if let date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.locale = Locale(identifier: "de_DE")
            drawText(fmt.string(from: date), at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
            y += 25
        }
        y += 15

        for table in tables.sorted(by: { $0.name < $1.name }) {
            if y > pageRect.height - 100 { context.endPage(); beginPage(); y = 40 }
            drawText("\(table.name) (\(table.shape.rawValue), \(table.guests.count)/\(table.capacity) Plätze)", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16))
            y += 22
            if table.guests.isEmpty {
                drawText("Keine Gäste zugewiesen", at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12)); y += 18
            } else {
                for guest in table.guests.sorted(by: { $0.fullName < $1.fullName }) {
                    var line = "\u{2022} \(guest.fullName)"
                    if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
                    if guest.hasIntolerances { line += " \u{26A0}\u{FE0F} \(guest.intolerances.joined(separator: ", "))" }
                    if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
                    drawText(line, at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12)); y += 18
                }
            }
            y += 10
        }

        context.endPage()
        beginPage()
        y = 40
        drawText("Übersicht für den Caterer", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 24)); y += 35

        let allGuests = tables.flatMap(\.guests)
        let counts = Dictionary(grouping: allGuests, by: \.dietaryChoice).mapValues(\.count)
        for (choice, count) in counts.sorted(by: { $0.key < $1.key }) {
            drawText("\(choice): \(count)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12)); y += 20
        }
        let childCount = allGuests.filter { $0.ageCategory != .adult }.count
        drawText("Kinder: \(childCount)", at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12)); y += 30

        let withIntolerances = allGuests.filter(\.hasIntolerances)
        if !withIntolerances.isEmpty {
            drawText("Unverträglichkeiten:", at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 16)); y += 22
            for guest in withIntolerances.sorted(by: { $0.fullName < $1.fullName }) {
                drawText("  \(guest.fullName): \(guest.intolerances.joined(separator: ", "))", at: CGPoint(x: 60, y: y), font: .systemFont(ofSize: 12)); y += 18
            }
        }

        context.endPage()
        context.closePDF()
        return pdfData as Data
    }
}
#endif
