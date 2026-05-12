#if canImport(AppKit)
import Foundation
import AppKit

/// Tent-Card-Tischkarten als A4-PDF: 4 pro Seite, untere Haelfte normal,
/// obere Haelfte um 180° gedreht — nach Falten entlang der Mittellinie
/// steht die Karte mit Namen auf beiden Seiten lesbar.
enum TableCardExporter {
    static func sortedByFullName(_ guests: [Guest]) -> [Guest] {
        guests.sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
    }

    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let cols: Int = 2
    private static let rows: Int = 2
    private static let cardsPerPage: Int = 4
    private static let marginX: CGFloat = 30
    private static let marginY: CGFloat = 40
    private static let gutter: CGFloat = 14

    private static var cardSize: CGSize {
        let w = (pageRect.width - 2 * marginX - CGFloat(cols - 1) * gutter) / CGFloat(cols)
        let h = (pageRect.height - 2 * marginY - CGFloat(rows - 1) * gutter) / CGFloat(rows)
        return CGSize(width: w, height: h)
    }

    static func generatePDF(guests: [Guest], eventName: String, withTitle: Bool = false) -> Data {
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
                    drawCard(context: context, guest: sortedGuests[i], slotIndex: i - index,
                             eventName: eventName, withTitle: withTitle)
                }
                endPage(context: context)
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
        // NSGraphicsContext mit flipped:true — sonst zeichnet NSString.draw
        // ins Leere (System-Default ist nil-Graphics-Context).
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    }

    private static func endPage(context: CGContext) {
        NSGraphicsContext.restoreGraphicsState()
        context.endPage()
    }

    private static func drawCoverPage(context: CGContext, eventName: String, message: String) {
        beginPage(context: context)
        drawText(eventName, at: CGPoint(x: marginX, y: 80), font: .boldSystemFont(ofSize: 24))
        drawText(message, at: CGPoint(x: marginX, y: 120), font: .systemFont(ofSize: 14), color: PDFColors.secondary)
        endPage(context: context)
    }

    private static func drawCard(context: CGContext, guest: Guest, slotIndex: Int,
                                 eventName: String, withTitle: Bool) {
        let col = slotIndex % cols
        let row = slotIndex / cols
        let size = cardSize
        let originX = marginX + CGFloat(col) * (size.width + gutter)
        let originY = marginY + CGFloat(row) * (size.height + gutter)

        drawCropMarks(context: context, origin: CGPoint(x: originX, y: originY), size: size)

        let title = guest.title.trimmingCharacters(in: .whitespaces)
        let name: String = (withTitle && !title.isEmpty)
            ? "\(title) \(guest.fullName)"
            : guest.fullName

        let halfHeight = size.height / 2
        let foldY = originY + halfHeight

        let bottomHalf = CGRect(x: originX, y: foldY, width: size.width, height: halfHeight)
        drawCardFace(context: context, name: name, in: bottomHalf)

        let topHalf = CGRect(x: originX, y: originY, width: size.width, height: halfHeight)
        context.saveGState()
        context.translateBy(x: topHalf.midX, y: topHalf.midY)
        context.rotate(by: .pi)
        let rotatedFrame = CGRect(x: -topHalf.width / 2, y: -topHalf.height / 2,
                                  width: topHalf.width, height: topHalf.height)
        drawCardFace(context: context, name: name, in: rotatedFrame)
        context.restoreGState()

        drawFoldLine(context: context, from: CGPoint(x: originX + 8, y: foldY),
                     to: CGPoint(x: originX + size.width - 8, y: foldY))
    }

    private static func drawCardFace(context: CGContext, name: String, in rect: CGRect) {
        let nameFont = NSFont.systemFont(ofSize: 26, weight: .semibold)
        let nameSize = (name as NSString).size(withAttributes: [.font: nameFont])
        let nameX = rect.minX + (rect.width - nameSize.width) / 2
        let nameY = rect.minY + (rect.height - nameSize.height) / 2 - 6
        drawText(name, at: CGPoint(x: nameX, y: nameY), font: nameFont)

        let accentLength: CGFloat = 44
        let accentY = nameY + nameSize.height + 12
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1).cgColor)
        context.setLineWidth(1.2)
        context.move(to: CGPoint(x: rect.midX - accentLength / 2, y: accentY))
        context.addLine(to: CGPoint(x: rect.midX + accentLength / 2, y: accentY))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawFoldLine(context: CGContext, from start: CGPoint, to end: CGPoint) {
        context.saveGState()
        context.setStrokeColor(PDFColors.tertiary.cgColor)
        context.setLineWidth(0.4)
        context.setLineDash(phase: 0, lengths: [3, 3])
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        context.restoreGState()
    }

    private static func drawCropMarks(context: CGContext, origin: CGPoint, size: CGSize) {
        let length: CGFloat = 6
        context.saveGState()
        context.setStrokeColor(PDFColors.tertiary.cgColor)
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

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = PDFColors.primary) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
