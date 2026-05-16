#if canImport(AppKit)
import Foundation
import AppKit
import CoreText

/// Erzeugt PDF mit anonymen FunFact-Spielkarten für ein Hochzeits-
/// Kennenlern-Spiel. 8 Karten pro A4-Seite (2x4), jede Karte zeigt:
/// - "FunFact" in kleiner gedämpfter Schrift oben
/// - Den FunFact-Text mittig groß
/// - Kleine Schnitt-Eckmarken
/// - KEIN Name (das ist die Pointe — Gäste sollen raten)
///
/// Am Ende des PDFs: Lösungsblatt mit FunFact ↔ Name-Mapping
/// (alphabetisch nach FunFact, damit der Moderator schnell nachschauen kann).
enum FunFactGameCardsExporter {
    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)
    private static let cols = 2
    private static let rows = 4
    private static let cardsPerPage = 8
    private static let marginX: CGFloat = 30
    private static let marginY: CGFloat = 40
    private static let gutter: CGFloat = 10

    private static var cardSize: CGSize {
        let w = (pageRect.width - 2 * marginX - CGFloat(cols - 1) * gutter) / CGFloat(cols)
        let h = (pageRect.height - 2 * marginY - CGFloat(rows - 1) * gutter) / CGFloat(rows)
        return CGSize(width: w, height: h)
    }

    /// Nur Gäste mit nicht-leerem FunFact bekommen eine Karte.
    /// (Ob approved oder nicht ist egal — du druckst was du hast.)
    static func generatePDF(guests: [Guest], eventName: String) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        let withFunFact = guests
            .filter { !$0.funFactDisplay.trimmingCharacters(in: .whitespaces).isEmpty }
            .sorted { lhs, rhs in
                lhs.funFactDisplay.localizedCompare(rhs.funFactDisplay) == .orderedAscending
            }

        if withFunFact.isEmpty {
            beginPage(context: context)
            drawText("FunFact-Spielkarten", at: CGPoint(x: marginX, y: 80), font: .boldSystemFont(ofSize: 22))
            drawText("Noch keine FunFacts erfasst — bitte erst FunFacts ergänzen.",
                     at: CGPoint(x: marginX, y: 120), font: .systemFont(ofSize: 13),
                     color: PDFColors.secondary)
            endPage(context: context)
            context.closePDF()
            return pdfData as Data
        }

        var index = 0
        while index < withFunFact.count {
            beginPage(context: context)
            let pageEnd = min(index + cardsPerPage, withFunFact.count)
            for i in index..<pageEnd {
                drawCard(context: context, guest: withFunFact[i], slotIndex: i - index)
            }
            endPage(context: context)
            index = pageEnd
        }

        // Lösungsblatt
        drawSolutionPage(context: context, guests: withFunFact, eventName: eventName)

        context.closePDF()
        return pdfData as Data
    }

    private static func beginPage(context: CGContext) {
        var box = pageRect
        context.beginPage(mediaBox: &box)
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
    }

    private static func endPage(context: CGContext) {
        NSGraphicsContext.restoreGraphicsState()
        context.endPage()
    }

    private static func drawCard(context: CGContext, guest: Guest, slotIndex: Int) {
        let col = slotIndex % cols
        let row = slotIndex / cols
        let size = cardSize
        let originX = marginX + CGFloat(col) * (size.width + gutter)
        let originY = marginY + CGFloat(row) * (size.height + gutter)

        // Schnitt-Eckmarken
        drawCropMarks(context: context, origin: CGPoint(x: originX, y: originY), size: size)

        // "FunFact"-Caption oben
        let captionFont = NSFont.systemFont(ofSize: 9, weight: .semibold)
        let caption = "FUNFACT"
        let captionAttrs: [NSAttributedString.Key: Any] = [
            .font: captionFont,
            .foregroundColor: PDFColors.tertiary,
            .kern: 1.5
        ]
        let captionStr = NSAttributedString(string: caption, attributes: captionAttrs)
        let captionSize = captionStr.size()
        captionStr.draw(at: CGPoint(x: originX + (size.width - captionSize.width) / 2, y: originY + 16))

        // Akzent-Linie unter Caption
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1).cgColor)
        context.setLineWidth(1)
        let accentY = originY + 30
        context.move(to: CGPoint(x: originX + (size.width - 30) / 2, y: accentY))
        context.addLine(to: CGPoint(x: originX + (size.width + 30) / 2, y: accentY))
        context.strokePath()
        context.restoreGState()

        // FunFact-Text mittig
        let funFactFont = NSFont.systemFont(ofSize: 14, weight: .medium)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        let funFactAttrs: [NSAttributedString.Key: Any] = [
            .font: funFactFont,
            .foregroundColor: PDFColors.primary,
            .paragraphStyle: para
        ]
        let textRect = CGRect(
            x: originX + 16,
            y: originY + 44,
            width: size.width - 32,
            height: size.height - 60
        )
        (guest.funFactDisplay as NSString).draw(in: textRect, withAttributes: funFactAttrs)
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
            context.move(to: CGPoint(x: corner.x - length, y: corner.y))
            context.addLine(to: CGPoint(x: corner.x + length, y: corner.y))
            context.move(to: CGPoint(x: corner.x, y: corner.y - length))
            context.addLine(to: CGPoint(x: corner.x, y: corner.y + length))
        }
        context.strokePath()
        context.restoreGState()
    }

    private static func drawSolutionPage(context: CGContext, guests: [Guest], eventName: String) {
        beginPage(context: context)
        drawText("Lösungsblatt — \(eventName)",
                 at: CGPoint(x: marginX, y: 50),
                 font: .boldSystemFont(ofSize: 18))
        drawText("Welcher FunFact gehört zu wem (für Moderator/Brautpaar)",
                 at: CGPoint(x: marginX, y: 75),
                 font: .systemFont(ofSize: 11),
                 color: PDFColors.secondary)

        var y: CGFloat = 110
        for guest in guests {
            if y > pageRect.height - 60 {
                endPage(context: context)
                beginPage(context: context)
                y = 50
            }
            let funFactFont = NSFont.systemFont(ofSize: 11)
            drawText("• \(guest.funFactDisplay)",
                     at: CGPoint(x: marginX, y: y),
                     font: funFactFont)
            y += 16
            drawText("    → \(guest.fullName)",
                     at: CGPoint(x: marginX, y: y),
                     font: .boldSystemFont(ofSize: 11),
                     color: NSColor(calibratedRed: 0.5, green: 0.3, blue: 0.4, alpha: 1))
            y += 22
        }

        endPage(context: context)
    }

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = PDFColors.primary) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
