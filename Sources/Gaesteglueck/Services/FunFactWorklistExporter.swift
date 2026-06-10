#if canImport(AppKit)
import Foundation
import AppKit
import CoreText

/// Erzeugt eine PDF-Liste der Gäste deren FunFact bearbeitet werden muss
/// (fehlt komplett oder noch nicht bestätigt). Pro Gast eine Zeile mit
/// Vor- und Nachname plus aktueller FunFact-Text (falls vorhanden) plus
/// Status-Hinweis. Alphabetisch sortiert.
enum FunFactWorklistExporter {
    private static let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842)

    static func generatePDF(guests: [Guest], title: String) -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return Data() }

        var pageNumber = 0
        var pageOpen = false

        func beginPage() {
            pageNumber += 1
            var box = pageRect
            context.beginPage(mediaBox: &box)
            pageOpen = true
        }

        func endPage() {
            guard pageOpen else { return }
            context.endPage()
            pageOpen = false
        }

        func drawText(_ text: String, at point: CGPoint, font: NSFont, color: CGColor = PDFColors.primary.cgColor) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
            let cgY = pageRect.height - point.y - font.ascender
            context.textPosition = CGPoint(x: point.x, y: cgY)
            CTLineDraw(line, context)
        }

        func drawWrappedText(_ text: String, in rect: CGRect, font: NSFont, color: CGColor = PDFColors.primary.cgColor) -> CGFloat {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let attributed = NSAttributedString(string: text, attributes: attrs)
            let framesetter = CTFramesetterCreateWithAttributedString(attributed)
            let path = CGMutablePath()
            // CG-Y ist bottom-up, das CGPath-Rect rechnet entsprechend
            let cgRect = CGRect(
                x: rect.origin.x,
                y: pageRect.height - rect.origin.y - rect.height,
                width: rect.width,
                height: rect.height
            )
            path.addRect(cgRect)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
            CTFrameDraw(frame, context)
            // Rückgabe: tatsächliche Höhe für nächste Zeile
            let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: 0),
                nil,
                CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                nil
            )
            return suggested.height
        }

        var y: CGFloat = 50

        beginPage()
        drawText(title, at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 22))
        y += 30
        drawText("\(guests.count) Gäste mit fehlendem oder unbestätigtem FunFact",
                 at: CGPoint(x: 40, y: y), font: .systemFont(ofSize: 12), color: PDFColors.secondary.cgColor)
        y += 26

        // Erklär-Block — was ist ein guter FunFact?
        drawText("Was ist ein guter FunFact?",
                 at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 12))
        y += 18
        let explanation = "Die FunFacts werden anonym auf den Tischen verteilt — als kleines Kennenlern-Spiel. Jeder Gast soll raten zu wem ein FunFact gehört, die Person finden und ein Foto mit ihr machen. Daher: Der FunFact MUSS DEM GAST SELBST GEHÖREN (eigene Erfahrung, eigenes Erlebnis), spezifisch genug damit man im Gespräch herausfinden kann ob's stimmt, aber OHNE den Namen zu verraten. Keine Beschreibungen von außen wie \"ist süß\" — die helfen beim Spiel nicht."
        let explainHeight = drawWrappedText(
            explanation,
            in: CGRect(x: 40, y: y, width: pageRect.width - 80, height: 50),
            font: NSFont.systemFont(ofSize: 11),
            color: PDFColors.secondary.cgColor
        )
        y += min(explainHeight, 50) + 8

        drawText("Beispiele (frei erfunden):",
                 at: CGPoint(x: 40, y: y), font: .boldSystemFont(ofSize: 11))
        y += 16
        let examples = [
            "Hat schon mal ein eigenes Gedicht im Gemeindeblatt veröffentlicht",
            "Hat das Brautpaar einst am selben Hotelpool kennengelernt",
            "Hat seine Frau im Schachverein kennengelernt",
            "Wird seit der Schulzeit von allen nur beim Spitznamen genannt",
            "Hat einmal versehentlich beim Pizza-Bestellen die Polizei angerufen",
            "Kann fließend Klingonisch — und das nicht aus Star Trek"
        ]
        for example in examples {
            drawText("• \(example)", at: CGPoint(x: 56, y: y),
                     font: NSFont.systemFont(ofSize: 11),
                     color: PDFColors.primary.cgColor)
            y += 16
        }
        y += 8

        // Trennlinie zur Liste
        context.saveGState()
        context.setStrokeColor(NSColor(white: 0.85, alpha: 1).cgColor)
        context.setLineWidth(0.5)
        context.move(to: CGPoint(x: 40, y: pageRect.height - y))
        context.addLine(to: CGPoint(x: pageRect.width - 40, y: pageRect.height - y))
        context.strokePath()
        context.restoreGState()
        y += 16

        for guest in guests {
            if y > pageRect.height - 80 {
                endPage()
                beginPage()
                y = 50
            }

            let nameFont = NSFont.boldSystemFont(ofSize: 13)
            drawText(guest.fullName, at: CGPoint(x: 40, y: y), font: nameFont)

            // Status-Tag rechts
            let trimmed = guest.funFactDisplay.trimmingCharacters(in: .whitespaces)
            let statusText: String
            let statusColor: CGColor
            if trimmed.isEmpty {
                statusText = "FEHLT"
                statusColor = NSColor(srgbRed: 0.65, green: 0.45, blue: 0.0, alpha: 1).cgColor
            } else if !guest.funFactApproved {
                statusText = "UNKLAR"
                statusColor = NSColor(srgbRed: 0.55, green: 0.55, blue: 0.55, alpha: 1).cgColor
            } else {
                statusText = "OK"
                statusColor = NSColor(srgbRed: 0.30, green: 0.55, blue: 0.30, alpha: 1).cgColor
            }
            drawText(statusText, at: CGPoint(x: pageRect.width - 100, y: y),
                     font: .boldSystemFont(ofSize: 10), color: statusColor)
            y += 18

            if !trimmed.isEmpty {
                let funFactRect = CGRect(x: 60, y: y, width: pageRect.width - 100, height: 60)
                let usedHeight = drawWrappedText(trimmed,
                                                 in: funFactRect,
                                                 font: NSFont.systemFont(ofSize: 11),
                                                 color: PDFColors.primary.cgColor)
                y += min(usedHeight, 60) + 6
            } else {
                drawText("(kein FunFact angegeben — bitte ergänzen)",
                         at: CGPoint(x: 60, y: y),
                         font: NSFont.systemFont(ofSize: 11),
                         color: PDFColors.tertiary.cgColor)
                y += 18
            }

            // Notiz-Zeile zum Ausfüllen (Druck-fertig)
            let lineY = y + 10
            context.saveGState()
            context.setStrokeColor(NSColor(white: 0.85, alpha: 1).cgColor)
            context.setLineWidth(0.5)
            context.move(to: CGPoint(x: 60, y: pageRect.height - lineY))
            context.addLine(to: CGPoint(x: pageRect.width - 60, y: pageRect.height - lineY))
            context.strokePath()
            context.restoreGState()
            y += 22
        }

        endPage()
        context.closePDF()
        return pdfData as Data
    }
}
#endif
