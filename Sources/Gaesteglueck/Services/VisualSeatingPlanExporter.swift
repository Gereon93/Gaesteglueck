#if canImport(AppKit)
import Foundation
import AppKit
import CoreText

/// Bildlicher Sitzplan als A3-Querformat-PDF: jeder Tisch wird als echte
/// Form (Rechteck/Kreis) an seiner Position auf dem Saalplan gezeichnet,
/// mit Namen direkt an den Sitzpositionen. Diätwahl wird als kleiner
/// farbiger Punkt angezeigt; Allergien als roter "!" am Sitz.
enum VisualSeatingPlanExporter {
    private static let pageWidth: CGFloat = 1191   // A3 landscape
    private static let pageHeight: CGFloat = 842
    private static let titleAreaHeight: CGFloat = 80
    private static let canvasMargin: CGFloat = 40

    private static let baseSeatDotDiameter: CGFloat = 8
    private static let baseDietDotDiameter: CGFloat = 5
    private static let baseNameFontSize: CGFloat = 9
    private static let baseNameOffset: CGFloat = 6

    // Colors
    private static let veganColor   = NSColor(srgbRed: 0.35, green: 0.54, blue: 0.29, alpha: 1)
    private static let vegColor     = NSColor(srgbRed: 0.48, green: 0.54, blue: 0.42, alpha: 1)
    private static let allergyColor = NSColor(srgbRed: 0.77, green: 0.29, blue: 0.29, alpha: 1)
    private static let bridalFill   = NSColor(srgbRed: 0.99, green: 0.93, blue: 0.94, alpha: 1)
    private static let tableFill    = NSColor(calibratedWhite: 0.97, alpha: 1)
    private static let accentLine   = NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1)

    nonisolated(unsafe) private static var currentDisplayNames: [UUID: String] = [:]
    nonisolated(unsafe) private static var currentRenderScale: CGFloat = 1.0
    /// `currentDisplayNames`/`currentRenderScale` werden während eines Renders
    /// von Helfern tief im Call-Stack gelesen. Damit parallele Aufrufe nicht
    /// die Werte gegenseitig überschreiben (race → falsche Skalierung im PNG),
    /// serialisieren wir die beiden Generate-Methoden über diesen Lock.
    private static let renderLock = NSLock()

    private static var seatDotDiameter: CGFloat { baseSeatDotDiameter * currentRenderScale }
    private static var dietDotDiameter: CGFloat { baseDietDotDiameter * currentRenderScale }
    private static var nameFontSize: CGFloat    { baseNameFontSize * currentRenderScale }
    private static var nameOffset: CGFloat      { baseNameOffset * currentRenderScale }

    /// Erzeugt eine PNG des reinen Sitzplan-Canvas — ohne Header oder
    /// Legende, in hoher Aufloesung. Ideal wenn der User selbst auf
    /// einen Druckbogen weiterskalieren will. Wenn `roomBackground` und
    /// `roomCMSize` gesetzt sind, wird der Saalplan als Hintergrund
    /// gerendert und Tische werden auf dieser Hintergrundkarte platziert.
    static func generatePNG(
        tables: [GuestTable],
        labels: [CanvasLabel] = [],
        roomBackground: NSImage? = nil,
        roomCMSize: CGSize? = nil,
        nameStyle: NameStyle = .smartDeduped,
        pixelsPerCM: CGFloat = 4
    ) -> Data? {
        renderLock.lock()
        defer { renderLock.unlock() }
        let allGuests = tables.flatMap(\.guests)
        currentDisplayNames = displayNames(for: allGuests, style: nameStyle)
        currentRenderScale = max(1.0, pixelsPerCM / 2)
        defer {
            currentDisplayNames = [:]
            currentRenderScale = 1.0
        }

        let canvasSize = canvasPixelSize(
            tables: tables,
            roomCMSize: roomCMSize,
            pixelsPerCM: pixelsPerCM
        )
        let pixelW = Int(canvasSize.width)
        let pixelH = Int(canvasSize.height)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // Weisser Hintergrund — falls kein Bild geladen wird.
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelW, height: pixelH))

        // CGContext ist bottom-up. Wir flippen damit alle Helper (NSString.draw,
        // Tisch-Layout etc.) wie im PDF-Pfad in Top-Down-Koordinaten arbeiten.
        context.translateBy(x: 0, y: CGFloat(pixelH))
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        defer { NSGraphicsContext.restoreGraphicsState() }

        let canvasRect = CGRect(x: 0, y: 0, width: CGFloat(pixelW), height: CGFloat(pixelH))

        // Saalplan-Bild als Hintergrund (gestreckt auf full canvas — Saalplan-
        // Maße bestimmen ohnehin die Canvas-Aufloesung, also passt das).
        if let bg = roomBackground, let cgImage = bg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            context.draw(cgImage, in: canvasRect)
            context.restoreGState()
        }

        if !tables.isEmpty {
            drawCanvas(context: context, tables: tables, in: canvasRect.insetBy(dx: 20, dy: 20))
        }

        for label in labels {
            drawLabel(context: context, label: label, in: canvasRect, tables: tables, roomCMSize: roomCMSize)
        }

        guard let cgImage = context.makeImage() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func canvasPixelSize(
        tables: [GuestTable],
        roomCMSize: CGSize?,
        pixelsPerCM: CGFloat
    ) -> CGSize {
        if let size = roomCMSize, size.width > 0, size.height > 0 {
            return CGSize(width: size.width * pixelsPerCM, height: size.height * pixelsPerCM)
        }
        // Fallback: aus Tisch-Bounding-Box + 200cm Padding ableiten.
        guard !tables.isEmpty else {
            return CGSize(width: 1600, height: 1200)
        }
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for table in tables {
            let hw = table.shape == .round ? CGFloat(table.diameter) / 2 : CGFloat(table.width) / 2
            let hd = table.shape == .round ? CGFloat(table.diameter) / 2 : CGFloat(table.depth) / 2
            let cx = CGFloat(table.positionX)
            let cy = CGFloat(table.positionY)
            minX = min(minX, cx - hw)
            maxX = max(maxX, cx + hw)
            minY = min(minY, cy - hd)
            maxY = max(maxY, cy + hd)
        }
        let widthCM = maxX - minX + 200
        let heightCM = maxY - minY + 200
        return CGSize(width: widthCM * pixelsPerCM, height: heightCM * pixelsPerCM)
    }

    private static func drawLabel(
        context: CGContext,
        label: CanvasLabel,
        in canvasRect: CGRect,
        tables: [GuestTable],
        roomCMSize: CGSize?
    ) {
        let pos = canvasPosition(forCM: CGPoint(x: label.positionX, y: label.positionY),
                                 canvasRect: canvasRect, tables: tables, roomCMSize: roomCMSize)
        context.saveGState()
        context.translateBy(x: pos.x, y: pos.y)
        context.rotate(by: CGFloat(label.rotation) * .pi / 180)
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: PDFColors.secondary
        ]
        let size = (label.text as NSString).size(withAttributes: attrs)
        (label.text as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2),
                                      withAttributes: attrs)
        context.restoreGState()
    }

    private static func canvasPosition(
        forCM cm: CGPoint,
        canvasRect: CGRect,
        tables: [GuestTable],
        roomCMSize: CGSize?
    ) -> CGPoint {
        if let size = roomCMSize, size.width > 0, size.height > 0 {
            let scaleX = canvasRect.width / size.width
            let scaleY = canvasRect.height / size.height
            return CGPoint(x: canvasRect.minX + cm.x * scaleX,
                           y: canvasRect.minY + cm.y * scaleY)
        }
        return CGPoint(x: canvasRect.midX + cm.x, y: canvasRect.midY + cm.y)
    }

    /// Wie soll der Name jedes Gastes auf dem Sitzplan angezeigt werden?
    enum NameStyle: String, CaseIterable, Identifiable, Sendable {
        /// Vorname + voller Nachname für jeden Gast.
        case full = "Voller Name"
        /// Nur Vorname.
        case firstOnly = "Nur Vorname"
        /// Vorname + Initial (z.B. "Anna B.") für jeden Gast.
        case firstWithInitial = "Vorname + Initial"
        /// Vorname allein wenn eindeutig, sonst + Initial. Bei Restdoppel
        /// fällt auf vollen Nachnamen zurück. (Default — am kürzesten lesbar.)
        case smartDeduped = "Vorname (Initial bei Doppelten)"

        public var id: String { rawValue }
    }

    /// Berechnet den Anzeige-Namen pro Gast nach gewähltem Stil.
    static func displayNames(for guests: [Guest], style: NameStyle = .smartDeduped) -> [UUID: String] {
        switch style {
        case .full:
            return Dictionary(uniqueKeysWithValues: guests.map {
                ($0.id, $0.lastName.isEmpty ? $0.firstName : "\($0.firstName) \($0.lastName)")
            })
        case .firstOnly:
            return Dictionary(uniqueKeysWithValues: guests.map { ($0.id, $0.firstName) })
        case .firstWithInitial:
            return Dictionary(uniqueKeysWithValues: guests.map { g in
                let initial = String(g.lastName.prefix(1)).uppercased()
                return (g.id, initial.isEmpty ? g.firstName : "\(g.firstName) \(initial).")
            })
        case .smartDeduped:
            return smartDedupedNames(for: guests)
        }
    }

    private static func smartDedupedNames(for guests: [Guest]) -> [UUID: String] {
        var byFirst: [String: [Guest]] = [:]
        for g in guests {
            byFirst[g.firstName, default: []].append(g)
        }
        var result: [UUID: String] = [:]
        for (first, group) in byFirst {
            if group.count == 1, let g = group.first {
                result[g.id] = first
                continue
            }
            var byInitial: [String: [Guest]] = [:]
            for g in group {
                let initial = String(g.lastName.prefix(1)).uppercased()
                byInitial[initial, default: []].append(g)
            }
            for (initial, subgroup) in byInitial {
                if subgroup.count == 1, let g = subgroup.first {
                    result[g.id] = initial.isEmpty ? first : "\(first) \(initial)."
                } else {
                    for g in subgroup {
                        result[g.id] = "\(first) \(g.lastName)"
                    }
                }
            }
        }
        return result
    }

    static func generatePDF(
        tables: [GuestTable],
        eventName: String,
        date: Date?,
        nameStyle: NameStyle = .smartDeduped
    ) -> Data {
        renderLock.lock()
        defer { renderLock.unlock() }
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        // Display-Names einmal pro Generate berechnen
        let allGuests = tables.flatMap(\.guests)
        currentDisplayNames = displayNames(for: allGuests, style: nameStyle)

        var box = pageRect
        context.beginPage(mediaBox: &box)
        // Flip coordinate system so y=0 is at top (NSString.draw expects this)
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

        drawHeader(context: context, eventName: eventName, date: date)

        let canvasArea = CGRect(
            x: canvasMargin,
            y: titleAreaHeight + canvasMargin,
            width: pageWidth - 2 * canvasMargin,
            height: pageHeight - titleAreaHeight - 2 * canvasMargin
        )

        if tables.isEmpty {
            drawText(
                "Noch keine Tische platziert.",
                at: CGPoint(x: canvasArea.midX - 80, y: canvasArea.midY),
                font: .systemFont(ofSize: 14),
                color: PDFColors.tertiary
            )
        } else {
            drawCanvas(context: context, tables: tables, in: canvasArea)
        }

        drawLegend(context: context, in: canvasArea)

        // WICHTIG: closePDF MUSS vor `return pdfData as Data` laufen.
        // Wenn closePDF in einem `defer` steht, passiert der NSData→Data
        // Snapshot vor dem Schreiben der schliessenden PDF-Bytes — das PDF
        // ist dann unvollstaendig und lässt sich nicht oeffnen.
        NSGraphicsContext.restoreGraphicsState()
        context.endPage()
        context.closePDF()
        currentDisplayNames = [:]

        return pdfData as Data
    }

    // MARK: - Header

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

    private static func drawLegend(context: CGContext, in area: CGRect) {
        let font = NSFont.systemFont(ofSize: 9)
        let y = area.maxY - 12

        var x = area.maxX - 280

        // Vegan dot
        context.saveGState()
        context.setFillColor(veganColor.cgColor)
        context.fillEllipse(in: CGRect(x: x, y: y - 4, width: 7, height: 7))
        context.restoreGState()
        x += 10
        drawText("Vegan", at: CGPoint(x: x, y: y - 5), font: font, color: PDFColors.secondary)
        x += 42

        // Vegetarian dot
        context.saveGState()
        context.setFillColor(vegColor.cgColor)
        context.fillEllipse(in: CGRect(x: x, y: y - 4, width: 7, height: 7))
        context.restoreGState()
        x += 10
        drawText("Vegetarisch", at: CGPoint(x: x, y: y - 5), font: font, color: PDFColors.secondary)
        x += 66

        // Allergy marker
        drawText("!", at: CGPoint(x: x, y: y - 5), font: .boldSystemFont(ofSize: 10), color: allergyColor)
        x += 10
        drawText("Allergie / Unverträglichkeit", at: CGPoint(x: x, y: y - 5), font: font, color: PDFColors.secondary)
    }

    // MARK: - Canvas layout

    private static func drawCanvas(context: CGContext, tables: [GuestTable], in area: CGRect) {
        // Compute bounding box of all table footprints (center ± half-size)
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        let seatPad: CGFloat = 40  // extra room for names around the outermost seats

        for table in tables {
            let hw = table.shape == .round ? CGFloat(table.diameter) / 2 : CGFloat(table.width) / 2
            let hd = table.shape == .round ? CGFloat(table.diameter) / 2 : CGFloat(table.depth) / 2
            let cx = CGFloat(table.positionX)
            let cy = CGFloat(table.positionY)
            minX = min(minX, cx - hw - seatPad)
            maxX = max(maxX, cx + hw + seatPad)
            minY = min(minY, cy - hd - seatPad)
            maxY = max(maxY, cy + hd + seatPad)
        }

        let srcW = max(maxX - minX, 1)
        let srcH = max(maxY - minY, 1)
        let scaleX = area.width / srcW
        let scaleY = area.height / srcH
        let scale = min(scaleX, scaleY)

        // Translation: centre the layout in the canvas area
        let scaledW = srcW * scale
        let scaledH = srcH * scale
        let offsetX = area.minX + (area.width - scaledW) / 2 - minX * scale
        let offsetY = area.minY + (area.height - scaledH) / 2 - minY * scale

        func toCanvas(_ pt: CGPoint) -> CGPoint {
            CGPoint(x: offsetX + pt.x * scale, y: offsetY + pt.y * scale)
        }

        // Identify tafel groups: group tables by combinationGroup
        var groupMap: [UUID: [GuestTable]] = [:]
        for table in tables {
            if let gid = table.combinationGroup {
                groupMap[gid, default: []].append(table)
            }
        }

        // Identify which tables are tafel-followers (not owners)
        // The "owner" is the table with the lowest combinationOrder (or the .head role)
        var tafelFollowerIDs: Set<UUID> = []
        for (_, group) in groupMap {
            let sorted = group.sorted { ($0.combinationOrder ?? 0) < ($1.combinationOrder ?? 0) }
            // Owner = first in sorted order; all others are followers for rendering purposes
            for follower in sorted.dropFirst() {
                tafelFollowerIDs.insert(follower.id)
            }
        }

        // Draw all tables
        for table in tables {
            if tafelFollowerIDs.contains(table.id) { continue }

            let cx = CGFloat(table.positionX)
            let cy = CGFloat(table.positionY)
            let center = toCanvas(CGPoint(x: cx, y: cy))
            let scaledDiameter = CGFloat(table.diameter) * scale
            let scaledWidth    = CGFloat(table.width)    * scale
            let scaledDepth    = CGFloat(table.depth)    * scale

            if let gid = table.combinationGroup, let group = groupMap[gid] {
                // Tafel (combined) rendering
                drawTafelTable(
                    context: context,
                    ownerTable: table,
                    group: group,
                    toCanvas: toCanvas,
                    scale: scale
                )
            } else {
                // Solo table rendering
                drawSoloTable(
                    context: context,
                    table: table,
                    center: center,
                    scaledDiameter: scaledDiameter,
                    scaledWidth: scaledWidth,
                    scaledDepth: scaledDepth,
                    scale: scale
                )
            }
        }
    }

    // MARK: - Solo table

    private static func drawSoloTable(
        context: CGContext,
        table: GuestTable,
        center: CGPoint,
        scaledDiameter: CGFloat,
        scaledWidth: CGFloat,
        scaledDepth: CGFloat,
        scale: CGFloat
    ) {
        let cap = table.capacity(rules: GuestTable.activeRules)
        let seatPositions = SeatLayout.positions(
            shape: table.shape,
            capacity: cap,
            scaledDiameter: scaledDiameter,
            scaledWidth: scaledWidth,
            scaledDepth: scaledDepth
        )

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(table.rotation) * .pi / 180)

        // Draw table shape
        drawTableShape(context: context, table: table, scaledWidth: scaledWidth, scaledDepth: scaledDepth, scaledDiameter: scaledDiameter)

        // Draw table label (name + occupancy) — in rotated coordinate system
        drawTableLabel(context: context, table: table, scaledWidth: scaledWidth, scaledDepth: scaledDepth, scaledDiameter: scaledDiameter)

        // Draw seats (positions are relative to table center, already in rotated space)
        for (idx, seatPos) in seatPositions.enumerated() {
            let guest = table.guests.first { $0.seatIndex == idx }
            let isDisabled = table.disabledSeatIndices.contains(idx)
            drawSeat(
                context: context,
                position: seatPos,
                tableCenter: .zero,
                guest: guest,
                isDisabled: isDisabled,
                shape: table.shape,
                counterRotation: -table.rotation
            )
        }

        context.restoreGState()
    }

    // MARK: - Tafel (combined) table

    private static func drawTafelTable(
        context: CGContext,
        ownerTable: GuestTable,
        group: [GuestTable],
        toCanvas: (CGPoint) -> CGPoint,
        scale: CGFloat
    ) {
        let geometry = TafelLayout.geometry(of: group, rules: GuestTable.activeRules)
        let center = toCanvas(geometry.center)

        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: CGFloat(geometry.rotation) * .pi / 180)

        let scaledWidth = geometry.totalWidth * scale
        let scaledDepth = geometry.depth * scale

        // Draw the tafel as a single rectangle
        let fill = group.contains(where: \.isBridalTable) ? bridalFill : tableFill
        context.setFillColor(fill.cgColor)
        context.setStrokeColor(PDFColors.primary.cgColor)
        context.setLineWidth(1)
        let tableRect = CGRect(x: -scaledWidth / 2, y: -scaledDepth / 2, width: scaledWidth, height: scaledDepth)
        let path = CGPath(roundedRect: tableRect, cornerWidth: 6, cornerHeight: 6, transform: nil)
        context.addPath(path)
        context.drawPath(using: .fillStroke)

        // Tafel name from the owner table
        let nameFont = NSFont.systemFont(ofSize: max(10, min(13, scaledWidth / 10)), weight: .semibold)
        let ownerName = group.sorted { ($0.combinationOrder ?? 0) < ($1.combinationOrder ?? 0) }.first?.name ?? ownerTable.name
        drawCenteredText(ownerName, at: .zero, offsetY: -8, font: nameFont)

        let totalGuests = group.flatMap(\.guests).count
        let totalCap = geometry.capacity - group.reduce(0) { $0 + $1.disabledSeatIndices.count }
        let countFont = NSFont.systemFont(ofSize: max(8, min(11, scaledWidth / 14)))
        drawCenteredText("\(totalGuests)/\(totalCap) Plätze", at: .zero, offsetY: 8, font: countFont, color: PDFColors.secondary)

        // Draw seats using TafelLayout seat positions (already in global canvas coords)
        // We need them relative to the rotated local frame of this table center
        let cosR = cos(-geometry.rotation * .pi / 180)
        let sinR = sin(-geometry.rotation * .pi / 180)

        for seat in geometry.seats {
            guard let table = group.first(where: { $0.id == seat.tableID }) else { continue }
            let guest = table.guests.first { $0.seatIndex == seat.localSeatIndex }
            let isDisabled = table.disabledSeatIndices.contains(seat.localSeatIndex)

            // Convert global seat position to local (relative to tafel center, pre-rotation)
            let globalSeat = toCanvas(seat.position)
            let dx = globalSeat.x - center.x
            let dy = globalSeat.y - center.y
            // Un-rotate to get local seat position in the rotated draw context
            let localX = dx * cosR - dy * sinR
            let localY = dx * sinR + dy * cosR

            let localSeatPos = CGPoint(x: localX, y: localY)
            drawSeat(
                context: context,
                position: localSeatPos,
                tableCenter: .zero,
                guest: guest,
                isDisabled: isDisabled,
                shape: .rectangular
            )
        }

        context.restoreGState()
    }

    // MARK: - Table shape drawing

    private static func drawTableShape(
        context: CGContext,
        table: GuestTable,
        scaledWidth: CGFloat,
        scaledDepth: CGFloat,
        scaledDiameter: CGFloat
    ) {
        let fill = table.isBridalTable ? bridalFill : tableFill
        context.setFillColor(fill.cgColor)
        context.setStrokeColor(PDFColors.primary.cgColor)
        context.setLineWidth(1)

        switch table.shape {
        case .round:
            let r = scaledDiameter / 2
            context.fillEllipse(in: CGRect(x: -r, y: -r, width: scaledDiameter, height: scaledDiameter))
            context.strokeEllipse(in: CGRect(x: -r, y: -r, width: scaledDiameter, height: scaledDiameter))
        case .rectangular:
            let rect = CGRect(x: -scaledWidth / 2, y: -scaledDepth / 2, width: scaledWidth, height: scaledDepth)
            let path = CGPath(roundedRect: rect, cornerWidth: 6, cornerHeight: 6, transform: nil)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        case .square:
            let side = scaledWidth
            let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
            let path = CGPath(roundedRect: rect, cornerWidth: 8, cornerHeight: 8, transform: nil)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
        }
    }

    // MARK: - Table label

    private static func drawTableLabel(
        context: CGContext,
        table: GuestTable,
        scaledWidth: CGFloat,
        scaledDepth: CGFloat,
        scaledDiameter: CGFloat
    ) {
        let refSize: CGFloat = table.shape == .round ? scaledDiameter : max(scaledWidth, scaledDepth)
        let nameFont = NSFont.systemFont(ofSize: max(8, min(13, refSize / 8)), weight: .semibold)
        let occupancy = "\(table.guests.count)/\(table.effectiveCapacity) Plätze"
        let countFont = NSFont.systemFont(ofSize: max(7, min(11, refSize / 11)))

        // Counter-rotate damit das Label aufrecht bleibt wenn der Tisch
        // gedreht ist — sonst muss man den Plan zum Lesen drehen.
        context.saveGState()
        context.rotate(by: -CGFloat(table.rotation) * .pi / 180)
        drawCenteredText(table.name, at: .zero, offsetY: -8, font: nameFont)
        drawCenteredText(occupancy, at: .zero, offsetY: 8, font: countFont, color: PDFColors.secondary)
        context.restoreGState()
    }

    // MARK: - Seat drawing

    private static func drawSeat(
        context: CGContext,
        position: CGPoint,
        tableCenter: CGPoint,
        guest: Guest?,
        isDisabled: Bool,
        shape: TableShape,
        displayName: String? = nil,
        counterRotation: Double = 0
    ) {
        let r = seatDotDiameter / 2
        let dotRect = CGRect(x: position.x - r, y: position.y - r, width: seatDotDiameter, height: seatDotDiameter)

        context.saveGState()

        if isDisabled {
            context.setFillColor(PDFColors.tertiary.cgColor)
            context.setStrokeColor(NSColor.separatorColor.cgColor)
            context.setLineWidth(0.5)
            context.fillEllipse(in: dotRect)
            context.strokeEllipse(in: dotRect)
            // Strikethrough line across the dot
            context.setStrokeColor(PDFColors.primary.cgColor)
            context.setLineWidth(1)
            context.move(to: CGPoint(x: position.x - r, y: position.y))
            context.addLine(to: CGPoint(x: position.x + r, y: position.y))
            context.strokePath()
            context.restoreGState()
            return
        }

        // Seat circle fill: white with border
        context.setFillColor(NSColor.white.cgColor)
        context.setStrokeColor(NSColor(calibratedWhite: 0.6, alpha: 1).cgColor)
        context.setLineWidth(0.75)
        context.fillEllipse(in: dotRect)
        context.strokeEllipse(in: dotRect)

        guard let guest else {
            context.restoreGState()
            return
        }

        // Diet dot in top-right corner of the seat circle
        let diet = guest.dietaryChoice
        if diet == "Vegan" || diet == "Vegetarisch" {
            let dotColor = diet == "Vegan" ? veganColor : vegColor
            let dr = dietDotDiameter / 2
            let dietRect = CGRect(
                x: position.x + r - dr * 0.8,
                y: position.y - r - dr * 0.8,
                width: dietDotDiameter,
                height: dietDotDiameter
            )
            context.setFillColor(dotColor.cgColor)
            context.fillEllipse(in: dietRect)
        }

        context.restoreGState()

        // Guest name — positioned radially outward from table center,
        // counter-rotated damit der Name lesbar bleibt wenn der Tisch
        // gedreht ist.
        drawGuestName(
            context: context,
            guest: guest,
            seatPosition: position,
            tableCenter: tableCenter,
            shape: shape,
            displayName: displayName,
            counterRotation: counterRotation
        )
    }

    // MARK: - Guest name placement

    private static func drawGuestName(
        context: CGContext,
        guest: Guest,
        seatPosition: CGPoint,
        tableCenter: CGPoint,
        shape: TableShape,
        displayName: String? = nil,
        counterRotation: Double = 0
    ) {
        let font = NSFont.systemFont(ofSize: nameFontSize)
        let allergyFont = NSFont.boldSystemFont(ofSize: nameFontSize)
        let name = displayName ?? currentDisplayNames[guest.id] ?? guest.firstName
        let nameAttr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: PDFColors.primary]
        let nameSize = (name as NSString).size(withAttributes: nameAttr)

        let dx = seatPosition.x - tableCenter.x
        let dy = seatPosition.y - tableCenter.y
        let r = seatDotDiameter / 2

        let anchorOffset: CGPoint
        if shape == .round {
            anchorOffset = nameAnchorRadiallyOutward(
                fromTableCenterDx: dx, dy: dy,
                textSize: nameSize, seatRadius: r, gap: nameOffset
            )
        } else {
            enum Direction { case top, bottom, left, right }
            let threshold: CGFloat = 5
            let dir: Direction
            if abs(dy) > abs(dx) {
                dir = dy < -threshold ? .top : .bottom
            } else {
                dir = dx < -threshold ? .left : .right
            }
            switch dir {
            case .top:
                anchorOffset = CGPoint(x: -nameSize.width / 2, y: -r - nameOffset - nameSize.height)
            case .bottom:
                anchorOffset = CGPoint(x: -nameSize.width / 2, y: r + nameOffset)
            case .left:
                anchorOffset = CGPoint(x: -r - nameOffset - nameSize.width, y: -nameSize.height / 2)
            case .right:
                anchorOffset = CGPoint(x: r + nameOffset, y: -nameSize.height / 2)
            }
        }

        context.saveGState()
        context.translateBy(x: seatPosition.x, y: seatPosition.y)
        context.rotate(by: CGFloat(counterRotation) * .pi / 180)
        (name as NSString).draw(at: anchorOffset, withAttributes: nameAttr)

        if guest.hasIntolerances {
            let markerAttr: [NSAttributedString.Key: Any] = [.font: allergyFont, .foregroundColor: allergyColor]
            let markerOrigin = CGPoint(x: anchorOffset.x + nameSize.width + 2, y: anchorOffset.y)
            ("!" as NSString).draw(at: markerOrigin, withAttributes: markerAttr)
        }
        context.restoreGState()
    }

    /// Liefert den Text-Origin so, dass die zur Tischmitte zugewandte Kante
    /// der Text-BBox am Sitz-Außenrand + `gap` sitzt — das Label "fließt"
    /// vom Sitz radial nach außen.
    private static func nameAnchorRadiallyOutward(
        fromTableCenterDx dx: CGFloat,
        dy: CGFloat,
        textSize: CGSize,
        seatRadius: CGFloat,
        gap: CGFloat
    ) -> CGPoint {
        let angle = atan2(dy, dx)
        let cosA = cos(angle)
        let sinA = sin(angle)
        let outerEdgeRadius = seatRadius + gap
        let halfW = textSize.width / 2
        let halfH = textSize.height / 2
        return CGPoint(
            x: cosA * (outerEdgeRadius + halfW) - halfW,
            y: sinA * (outerEdgeRadius + halfH) - halfH
        )
    }

    // MARK: - Helpers

    /// Draws horizontally centred text at an offset from a given origin (in current coordinate system).
    private static func drawCenteredText(
        _ text: String,
        at origin: CGPoint,
        offsetY: CGFloat,
        font: NSFont,
        color: NSColor = PDFColors.primary
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attrs)
        let pt = CGPoint(x: origin.x - size.width / 2, y: origin.y + offsetY - size.height / 2)
        (text as NSString).draw(at: pt, withAttributes: attrs)
    }

    private static func drawText(_ text: String, at point: CGPoint, font: NSFont, color: NSColor = PDFColors.primary) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
