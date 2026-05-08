#if canImport(AppKit)
import Foundation
import AppKit

/// Erzeugt druckfertige Tischkarten als A4-PDF — 8 Karten pro Seite,
/// 2 Spalten × 4 Reihen. Pro Karte: Vor- und Nachname groß, optional
/// Fun Fact darunter in kleinerer kursiver Schrift. Eckmarken zum
/// Schneiden mit Cuttermesser oder Papierschneider.
enum TableCardExporter {
    static func sortedByFullName(_ guests: [Guest]) -> [Guest] {
        guests.sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
    }

    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let cols: Int = 2
    private static let rows: Int = 4
    private static let cardsPerPage: Int = 8
    private static let marginX: CGFloat = 30
    private static let marginY: CGFloat = 40
    private static let gutter: CGFloat = 10

    private static var cardSize: CGSize {
        let w = (pageRect.width - 2 * marginX - CGFloat(cols - 1) * gutter) / CGFloat(cols)
        let h = (pageRect.height - 2 * marginY - CGFloat(rows - 1) * gutter) / CGFloat(rows)
        return CGSize(width: w, height: h)
    }

    static func generatePDF(guests: [Guest], eventName: String) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        let sortedGuests = Self.sortedByFullName(guests)

        if sortedGuests.isEmpty {
            drawCoverPage(context: context, eventName: eventName, message: "Keine Gäste — füge erst Gäste hinzu, dann sind die Tischkarten in einem Klick fertig.")
        } else {
            var index = 0
            while index < sortedGuests.count {
                beginPage(context: context)
                let pageEnd = min(index + cardsPerPage, sortedGuests.count)
                for i in index..<pageEnd {
                    drawCard(context: context, guest: sortedGuests[i], slotIndex: i - index, eventName: eventName)
                }
                context.endPage()
                index = pageEnd
            }
        }

        context.closePDF()
        return pdfData as Data
    }

    private static func beginPage(context: CGContext) {
        var box = pageRect
        context.beginPage(mediaBox: &box)
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
    }

    private static func drawCoverPage(context: CGContext, eventName: String, message: String) {
        beginPage(context: context)
        drawText(eventName, at: CGPoint(x: marginX, y: 80), font: .boldSystemFont(ofSize: 24))
        drawText(message, at: CGPoint(x: marginX, y: 120), font: .systemFont(ofSize: 14), color: .secondaryLabelColor)
        context.endPage()
    }

    private static func drawCard(context: CGContext, guest: Guest, slotIndex: Int, eventName: String) {
        let col = slotIndex % cols
        let row = slotIndex / cols
        let size = cardSize
        let originX = marginX + CGFloat(col) * (size.width + gutter)
        let originY = marginY + CGFloat(row) * (size.height + gutter)

        drawCropMarks(context: context, origin: CGPoint(x: originX, y: originY), size: size)

        let name = guest.fullName
        let nameFont = NSFont.systemFont(ofSize: 22, weight: .semibold)
        let nameSize = (name as NSString).size(withAttributes: [.font: nameFont])
        let nameX = originX + (size.width - nameSize.width) / 2
        let nameY = originY + size.height / 2 - nameSize.height
        drawText(name, at: CGPoint(x: nameX, y: nameY), font: nameFont)

        let accentY = nameY + nameSize.height + 12
        let accentLineLength: CGFloat = 40
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1).cgColor)
        context.setLineWidth(1.2)
        context.move(to: CGPoint(x: originX + (size.width - accentLineLength) / 2, y: accentY))
        context.addLine(to: CGPoint(x: originX + (size.width + accentLineLength) / 2, y: accentY))
        context.strokePath()
        context.restoreGState()

        let funFact = guest.funFact
        if !funFact.isEmpty {
            let factFont = NSFont(descriptor: NSFont.systemFont(ofSize: 11).fontDescriptor.withSymbolicTraits(.italic), size: 11) ?? NSFont.systemFont(ofSize: 11)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: factFont,
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let factRect = CGRect(
                x: originX + 16,
                y: accentY + 8,
                width: size.width - 32,
                height: size.height - (accentY - originY) - 24
            )
            let para = NSMutableParagraphStyle()
            para.alignment = .center
            para.lineBreakMode = .byTruncatingTail
            var combined = attrs
            combined[.paragraphStyle] = para
            (funFact as NSString).draw(in: factRect, withAttributes: combined)
        }

        let footerFont = NSFont.systemFont(ofSize: 7)
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let footerSize = (eventName as NSString).size(withAttributes: footerAttrs)
        (eventName as NSString).draw(
            at: CGPoint(x: originX + (size.width - footerSize.width) / 2, y: originY + size.height - 14),
            withAttributes: footerAttrs
        )
    }

    private static func drawCropMarks(context: CGContext, origin: CGPoint, size: CGSize) {
        let length: CGFloat = 6
        context.saveGState()
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(0.4)
        let corners = [
            origin,
            CGPoint(x: origin.x + size.width, y: origin.y),
            CGPoint(x: origin.x, y: origin.y + size.height),
            CGPoint(x: origin.x + size.width, y: origin.y + size.height)
        ]
        for corner in corners {
            // Horizontal tick
            context.move(to: CGPoint(x: corner.x - length, y: corner.y))
            context.addLine(to: CGPoint(x: corner.x + length, y: corner.y))
            // Vertical tick
            context.move(to: CGPoint(x: corner.x, y: corner.y - length))
            context.addLine(to: CGPoint(x: corner.x, y: corner.y + length))
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = .labelColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
