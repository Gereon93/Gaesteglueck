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
                color: .secondaryLabelColor
            )
        }

        // Accent line
        context.saveGState()
        context.setStrokeColor(NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: canvasMargin, y: titleAreaHeight - 8))
        context.addLine(to: CGPoint(x: pageWidth - canvasMargin, y: titleAreaHeight - 8))
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
        context.setStrokeColor(NSColor.labelColor.cgColor)
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

        // Gästenamen darunter (max 8 Zeilen — Plakat braucht Platz)
        let listFont = NSFont.systemFont(ofSize: 8)
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byTruncatingTail
        let attrs: [NSAttributedString.Key: Any] = [
            .font: listFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: para
        ]
        let visibleGuests = table.guests.prefix(8)
        let hidden = max(0, table.guests.count - visibleGuests.count)
        var lines = visibleGuests.map(\.fullName)
        if hidden > 0 { lines.append("… +\(hidden) weitere") }
        let listText = lines.joined(separator: "\n")
        let listRect = CGRect(
            x: center.x - size / 2 - 20,
            y: center.y - size / 2 + 6,
            width: size + 40,
            height: size - 12
        )
        (listText as NSString).draw(in: listRect, withAttributes: attrs)
    }

    private static func drawUnassignedList(context: CGContext, guests: [Guest], in rect: CGRect) {
        context.saveGState()
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
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
            .foregroundColor: NSColor.labelColor
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

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = .labelColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
