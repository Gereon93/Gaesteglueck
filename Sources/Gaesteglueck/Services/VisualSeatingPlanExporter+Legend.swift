#if os(macOS)
import Foundation
import AppKit
import CoreText

extension VisualSeatingPlanExporter {
    // MARK: - Header

    static func drawHeader(context: CGContext, eventName: String, date: Date?) {
        PDFDrawing.drawText(
            "Sitzplan: \(eventName)",
            at: CGPoint(x: canvasMargin, y: 32),
            font: .boldSystemFont(ofSize: 28)
        )
        if let date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.locale = Locale(identifier: "de_DE")
            PDFDrawing.drawText(
                fmt.string(from: date),
                at: CGPoint(x: canvasMargin, y: 60),
                font: .systemFont(ofSize: 13),
                color: PDFColors.secondary
            )
        }
        context.saveGState()
        context.setStrokeColor(accentLine.cgColor)
        context.setLineWidth(2)
        let lineY = titleAreaHeight + 4
        context.move(to: CGPoint(x: canvasMargin, y: lineY))
        context.addLine(to: CGPoint(x: pageWidth - canvasMargin, y: lineY))
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Legend

    /// Höhe des Legenden-Blocks abhängig von der Anzahl Allergen-Einträge.
    /// Wird oben in den Generatoren verwendet, um Platz unten zu reservieren.
    static func legendBlockHeight(
        legend: SeatingLegend,
        scale: CGFloat = 1.0,
        availableWidth: CGFloat = 0
    ) -> CGFloat {
        var h: CGFloat = 26 // Header + Diät-Zeile
        // Spalten-Logik IDENTISCH zu drawLegend, damit die Reserve nicht
        // pauschal zu hoch ist (z.B. auf A3 mehr Spalten möglich = weniger Zeilen).
        let entryWidth: CGFloat = 130 * scale
        let cols = max(3, availableWidth > 0 ? Int(availableWidth / entryWidth) : 3)
        if !legend.isEmpty {
            let rows = (legend.entries.count + cols - 1) / cols
            h += CGFloat(rows) * 14 + 16
        }
        if legend.hasAgeMarkers {
            let rows = (legend.ageCategories.count + cols - 1) / cols
            h += CGFloat(rows) * 14 + 16
        }
        return h * scale
    }

    /// Voll-formatierter Legenden-Block: Diät-Farben + nummerierte
    /// Allergen-Liste. `area` ist der gesamte zur Verfügung stehende Bereich
    /// (z.B. der untere Streifen unter dem Tisch-Canvas). Alle Größen
    /// skalieren mit `currentRenderScale`, damit die Legende auf high-res
    /// PNGs proportional zur Tisch-Beschriftung mitwächst.
    static func drawLegend(context: CGContext, ctx: RenderContext, in area: CGRect) {
        let s = ctx.renderScale
        let headerFont = NSFont.boldSystemFont(ofSize: 9 * s)
        let font = NSFont.systemFont(ofSize: 9 * s)
        let numberFont = NSFont.boldSystemFont(ofSize: 9 * s)

        // Trenner-Linie oben über dem Legenden-Bereich.
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedWhite: 0.85, alpha: 1).cgColor)
        context.setLineWidth(0.5 * s)
        context.move(to: CGPoint(x: area.minX, y: area.minY))
        context.addLine(to: CGPoint(x: area.maxX, y: area.minY))
        context.strokePath()
        context.restoreGState()

        var y = area.minY + 12 * s
        PDFDrawing.drawText("LEGENDE", at: CGPoint(x: area.minX, y: y - 5 * s),
                 font: headerFont, color: PDFColors.secondary)
        y += 12 * s

        // Diät-Swatches in einer Zeile (Kreise mit farbigem Rand wie die Chips).
        let swatch: CGFloat = 8 * s
        func dietSwatch(_ x: CGFloat, fill: NSColor, label: String) {
            let rect = CGRect(x: x, y: y - 5 * s, width: swatch, height: swatch)
            context.saveGState()
            context.setFillColor(fill.withAlphaComponent(0.20).cgColor)
            context.fillEllipse(in: rect)
            context.setStrokeColor(fill.cgColor)
            context.setLineWidth(1.2 * s)
            context.strokeEllipse(in: rect.insetBy(dx: 0.6 * s, dy: 0.6 * s))
            context.restoreGState()
            PDFDrawing.drawText(label, at: CGPoint(x: x + swatch + 4 * s, y: y - 5 * s),
                     font: font, color: PDFColors.primary)
        }
        dietSwatch(area.minX, fill: mealColor, label: "Fleisch")
        dietSwatch(area.minX + 64 * s, fill: veganColor, label: "Vegan")
        dietSwatch(area.minX + 128 * s, fill: vegColor, label: "Vegetarisch")

        // Spalten verteilen über die volle Breite. Mindestens 3 Spalten;
        // bei vielen Einträgen mehr, sodass nichts überläuft.
        let legend = ctx.legend
        let entryWidth: CGFloat = 130 * s
        let columns = max(3, Int(area.width / entryWidth))
        let columnWidth = area.width / CGFloat(columns)

        // Unverträglichkeiten-Sektion — nur wenn Einträge vorhanden.
        if !legend.entries.isEmpty {
            y += 16 * s
            PDFDrawing.drawText("UNVERTRÄGLICHKEITEN", at: CGPoint(x: area.minX, y: y - 5 * s),
                     font: headerFont, color: PDFColors.secondary)
            y += 12 * s

            for (idx, entry) in legend.entries.enumerated() {
                let col = idx % columns
                let row = idx / columns
                let cx = area.minX + CGFloat(col) * columnWidth
                let cy = y + CGFloat(row) * 14 * s

                // Nummer als rote Kapsel.
                let numStr = "\(entry.number)"
                let numAttr: [NSAttributedString.Key: Any] = [
                    .font: numberFont, .foregroundColor: NSColor.white
                ]
                let numSize = (numStr as NSString).size(withAttributes: numAttr)
                let pillWidth = max(14 * s, numSize.width + 8 * s)
                let pillHeight = 11 * s
                let pillRect = CGRect(x: cx, y: cy - 7 * s, width: pillWidth, height: pillHeight)
                context.saveGState()
                context.setFillColor(allergyColor.cgColor)
                let pillPath = CGPath(roundedRect: pillRect,
                                      cornerWidth: pillHeight / 2, cornerHeight: pillHeight / 2,
                                      transform: nil)
                context.addPath(pillPath)
                context.fillPath()
                context.restoreGState()
                let numX = cx + (pillWidth - numSize.width) / 2
                (numStr as NSString).draw(at: CGPoint(x: numX, y: cy - 7 * s),
                                          withAttributes: numAttr)

                // Allergen-Name daneben.
                PDFDrawing.drawText(entry.name,
                         at: CGPoint(x: cx + pillWidth + 5 * s, y: cy - 5 * s),
                         font: font, color: PDFColors.primary)
            }
            let rows = (legend.entries.count + columns - 1) / columns
            y += CGFloat(rows) * 14 * s
        }

        // Alters-Sektion — unabhängig von Unverträglichkeiten.
        guard legend.hasAgeMarkers else { return }
        y += 4 * s
        PDFDrawing.drawText("ALTER", at: CGPoint(x: area.minX, y: y - 5 * s),
                 font: headerFont, color: PDFColors.secondary)
        y += 12 * s

        for (idx, age) in legend.ageCategories.enumerated() {
            let col = idx % columns
            let row = idx / columns
            let cx = area.minX + CGFloat(col) * columnWidth
            let cy = y + CGFloat(row) * 14 * s

            let badge = 11 * s
            let badgeRect = CGRect(x: cx, y: cy - 7 * s, width: badge, height: badge)
            context.setFillColor(ageColor.cgColor)
            context.fillEllipse(in: badgeRect)
            drawSymbol(age.iconName,
                       in: badgeRect.insetBy(dx: badge * 0.22, dy: badge * 0.22),
                       color: .white)

            PDFDrawing.drawText(age.rawValue,
                     at: CGPoint(x: cx + badge + 5 * s, y: cy - 5 * s),
                     font: font, color: PDFColors.primary)
        }
    }
}
#endif
