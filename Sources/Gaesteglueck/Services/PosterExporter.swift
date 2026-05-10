#if canImport(AppKit)
import Foundation
import AppKit

/// Druckfertiges Plakat im A3-Querformat. Tische werden an den Positionen
/// gezeichnet, an denen sie auch im Raumplan stehen — Gäste finden so direkt
/// "ihren" Tisch wieder. Nicht zugewiesene Gäste werden in einer separaten
/// Liste rechts unten gesammelt, damit sich keiner suchen muss.
enum PosterExporter {
    private static let pageWidth: CGFloat = 1191   // A3 landscape
    private static let pageHeight: CGFloat = 842
    private static let titleAreaHeight: CGFloat = 80
    private static let unassignedAreaWidth: CGFloat = 240
    private static let canvasMargin: CGFloat = 40

    static func generatePDF(
        tables: [GuestTable],
        unassignedGuests: [Guest],
        eventName: String,
        date: Date?
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        var box = pageRect
        context.beginPage(mediaBox: &box)
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
        // NSGraphicsContext mit flipped:true — sonst zeichnet NSString.draw
        // ins Leere (System-Default-Graphics-Context ist nil).
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer {
            NSGraphicsContext.restoreGraphicsState()
        }

        drawHeader(context: context, eventName: eventName, date: date)

        let canvasArea = CGRect(
            x: canvasMargin,
            y: titleAreaHeight + canvasMargin,
            width: pageWidth - 2 * canvasMargin - (unassignedGuests.isEmpty ? 0 : unassignedAreaWidth + 20),
            height: pageHeight - titleAreaHeight - 2 * canvasMargin
        )

        if tables.isEmpty {
            drawText(
                "Noch keine Tische platziert.",
                at: CGPoint(x: canvasArea.midX - 80, y: canvasArea.midY),
                font: .systemFont(ofSize: 14),
                color: .tertiaryLabelColor
            )
        } else {
            drawTables(context: context, tables: tables, in: canvasArea)
        }

        if !unassignedGuests.isEmpty {
            let unassignedRect = CGRect(
                x: pageWidth - canvasMargin - unassignedAreaWidth,
                y: titleAreaHeight + canvasMargin,
                width: unassignedAreaWidth,
                height: pageHeight - titleAreaHeight - 2 * canvasMargin
            )
            drawUnassignedList(context: context, guests: unassignedGuests, in: unassignedRect)
        }

        context.endPage()
        context.closePDF()
        return pdfData as Data
    }

    private static func drawHeader(context: CGContext, eventName: String, date: Date?) {
        drawText(
            "Sitzplan: \(eventName)",
            at: CGPoint(x: canvasMargin, y: 32),
            font: .boldSystemFont(ofSize: 28)
        )
        if let date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.locale = Locale(identifier: "de_DE")
            drawText(
                fmt.string(from: date),
                at: CGPoint(x: canvasMargin, y: 64),
                font: .systemFont(ofSize: 13),
                color: pdfSecondary
            )
        }

        context.saveGState()
        context.setStrokeColor(NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1).cgColor)
        context.setLineWidth(2)
        let lineY = titleAreaHeight + 4
        context.move(to: CGPoint(x: canvasMargin, y: lineY))
        context.addLine(to: CGPoint(x: pageWidth - canvasMargin, y: lineY))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawTables(context: CGContext, tables: [GuestTable], in area: CGRect) {
        let bounds = tableBounds(tables: tables)
        let tableSize: CGFloat = 90  // diameter for round, side for rect — visualization only

        let scaleX = bounds.width > 0 ? (area.width - tableSize) / bounds.width : 1
        let scaleY = bounds.height > 0 ? (area.height - tableSize) / bounds.height : 1
        let scale = min(scaleX, scaleY, 1.5)  // don't blow up tiny rooms

        for table in tables {
            let canvasX = table.positionX
            let canvasY = table.positionY
            let centerX = area.minX + tableSize / 2 + (canvasX - bounds.minX) * scale
            let centerY = area.minY + tableSize / 2 + (canvasY - bounds.minY) * scale
            drawTable(context: context, table: table, center: CGPoint(x: centerX, y: centerY), size: tableSize)
        }
    }

    private static func tableBounds(tables: [GuestTable]) -> CGRect {
        guard !tables.isEmpty else { return .zero }
        let xs = tables.map(\.positionX)
        let ys = tables.map(\.positionY)
        let minX = xs.min() ?? 0
        let maxX = xs.max() ?? 0
        let minY = ys.min() ?? 0
        let maxY = ys.max() ?? 0
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func drawTable(context: CGContext, table: GuestTable, center: CGPoint, size: CGFloat) {
        context.saveGState()
        context.setStrokeColor(pdfPrimary.cgColor)
        context.setFillColor(NSColor(calibratedWhite: 0.97, alpha: 1).cgColor)
        context.setLineWidth(1)

        let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
        switch table.shape {
        case .round:
            context.fillEllipse(in: rect)
            context.strokeEllipse(in: rect)
        case .rectangular, .square:
            context.fill(rect)
            context.stroke(rect)
        }
        context.restoreGState()

        let nameFont = NSFont.boldSystemFont(ofSize: 11)
        let nameSize = (table.name as NSString).size(withAttributes: [.font: nameFont])
        drawText(
            table.name,
            at: CGPoint(x: center.x - nameSize.width / 2, y: center.y - size / 2 - 16),
            font: nameFont
        )

        // Gästenamen — alle in Sitz-Reihenfolge (von oben nach unten, wie sie
        // am Tisch sitzen). Höhe wächst mit der Anzahl Gäste; Schrift wird
        // kleiner wenn viele Namen rein müssen.
        let count = table.guests.count
        let listFontSize: CGFloat = count > 16 ? 6 : (count > 12 ? 7 : (count > 8 ? 7.5 : 8))
        let listFont = NSFont.systemFont(ofSize: listFontSize)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byTruncatingTail
        para.lineSpacing = 0
        let attrs: [NSAttributedString.Key: Any] = [
            .font: listFont,
            .foregroundColor: pdfPrimary,
            .paragraphStyle: para
        ]
        let sortedGuests = table.guests.sorted { lhs, rhs in
            switch (lhs.seatIndex, rhs.seatIndex) {
            case let (l?, r?): return l < r
            case (_?, nil): return true
            case (nil, _?): return false
            default: return lhs.fullName < rhs.fullName
            }
        }
        let lines = sortedGuests.map(\.fullName)
        let listText = lines.joined(separator: "\n")
        // Höhe basierend auf Anzahl Zeilen + Font-Höhe, statt fixer size.
        let lineHeight = listFontSize + 2
        let listHeight = max(size - 12, CGFloat(lines.count) * lineHeight + 8)
        let listRect = CGRect(
            x: center.x - size / 2 - 30,
            y: center.y - size / 2 + 6,
            width: size + 60,
            height: listHeight
        )
        (listText as NSString).draw(in: listRect, withAttributes: attrs)
    }

    private static func drawUnassignedList(context: CGContext, guests: [Guest], in rect: CGRect) {
        context.saveGState()
        context.setStrokeColor(pdfTertiary.cgColor)
        context.setLineWidth(0.6)
        context.stroke(rect)
        context.restoreGState()

        drawText(
            "Noch nicht zugewiesen",
            at: CGPoint(x: rect.minX + 12, y: rect.minY + 14),
            font: .boldSystemFont(ofSize: 13)
        )

        let listFont = NSFont.systemFont(ofSize: 11)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: listFont,
            .foregroundColor: pdfPrimary
        ]
        let names = guests
            .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
            .map(\.fullName)
            .joined(separator: "\n")
        let textRect = CGRect(
            x: rect.minX + 12,
            y: rect.minY + 36,
            width: rect.width - 24,
            height: rect.height - 48
        )
        (names as NSString).draw(in: textRect, withAttributes: attrs)
    }

    /// PDF-safe: NSColor.labelColor wird im PDF-Off-Screen-Context oft als
    /// transparent gerendert. Wir nutzen explizite RGB-Werte als Default.
    private static let pdfPrimary = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1)
    private static let pdfSecondary = NSColor(srgbRed: 0.40, green: 0.40, blue: 0.40, alpha: 1)
    private static let pdfTertiary = NSColor(srgbRed: 0.60, green: 0.60, blue: 0.60, alpha: 1)

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor? = nil) {
        let resolved = color ?? pdfPrimary
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: resolved]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
