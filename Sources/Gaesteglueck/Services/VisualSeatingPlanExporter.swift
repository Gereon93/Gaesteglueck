import Foundation
#if os(macOS)
import AppKit
import CoreText
#endif

/// Bildlicher Sitzplan als A3-Querformat-PDF: jeder Tisch wird als echte
/// Form (Rechteck/Kreis) an seiner Position auf dem Saalplan gezeichnet,
/// mit Namen direkt an den Sitzpositionen. Diätwahl wird als kleiner
/// farbiger Punkt angezeigt; Allergien als roter "!" am Sitz.
///
/// `NameStyle` + `displayNames` sind plattformneutral, weil das Canvas sie
/// auch für die On-Screen-Anzeige nutzt; das eigentliche Zeichnen (PDF/PNG)
/// ist macOS-only.
enum VisualSeatingPlanExporter {
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

    static func smartDedupedNames(for guests: [Guest]) -> [UUID: String] {
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
                        result[g.id] = g.lastName.isEmpty ? first : "\(first) \(g.lastName)"
                    }
                }
            }
        }
        return result
    }
}

#if os(macOS)
extension VisualSeatingPlanExporter {
    static let pageWidth: CGFloat = 1191   // A3 landscape
    static let pageHeight: CGFloat = 842
    static let titleAreaHeight: CGFloat = 80
    static let canvasMargin: CGFloat = 40

    static let baseSeatDotDiameter: CGFloat = 8
    static let baseDietDotDiameter: CGFloat = 5
    static let baseNameFontSize: CGFloat = 9
    static let baseNameOffset: CGFloat = 6

    // Colors
    // Vegan = Gold (#c9a227), Vegetarisch = Grün (#3f7a30) — kanonisch wie
    // Tokens.Colors.dietVegan/dietVegetarian, hier als NSColor gespiegelt.
    static let veganColor   = NSColor(srgbRed: 0.788, green: 0.635, blue: 0.153, alpha: 1)
    static let vegColor     = NSColor(srgbRed: 0.247, green: 0.478, blue: 0.188, alpha: 1)
    static let allergyColor = NSColor(srgbRed: 0.77, green: 0.29, blue: 0.29, alpha: 1)
    // Alter (#6e8aab = Tokens.Colors.tagActivity) — Blau, klar abgesetzt von
    // Diät (Gold/Grün) und Allergie (Rot).
    static let ageColor     = NSColor(srgbRed: 0.431, green: 0.541, blue: 0.671, alpha: 1)
    // Fleisch/„isst alles" = Standard-Chip-Rosa (#c8788c = Tokens.Colors.accent).
    static let mealColor    = NSColor(srgbRed: 0.784, green: 0.471, blue: 0.549, alpha: 1)
    static let bridalFill   = NSColor(srgbRed: 0.99, green: 0.93, blue: 0.94, alpha: 1)
    static let tableFill    = NSColor(calibratedWhite: 0.97, alpha: 1)
    static let accentLine   = NSColor(calibratedRed: 0.78, green: 0.47, blue: 0.55, alpha: 1)

    /// Render-Kontext eines einzelnen Export-Laufs. Ersetzt die früheren
    /// `nonisolated(unsafe)` static vars: wird von den Generate-Methoden
    /// gebaut und durch alle Draw-Helfer gereicht, sodass parallele Exporte
    /// sich keinen mutablen Zustand mehr teilen — kein Data-Race, kein Lock.
    struct RenderContext {
        let displayNames: [UUID: String]
        let renderScale: CGFloat
        let legend: SeatingLegend

        var seatDotDiameter: CGFloat { baseSeatDotDiameter * renderScale }
        var dietDotDiameter: CGFloat { baseDietDotDiameter * renderScale }
        var nameFontSize: CGFloat    { baseNameFontSize * renderScale }
        var nameOffset: CGFloat      { baseNameOffset * renderScale }
    }

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
        let allGuests = tables.flatMap(\.attendingGuests)
        let ctx = RenderContext(
            displayNames: displayNames(for: allGuests, style: nameStyle),
            renderScale: max(1.0, pixelsPerCM / 2),
            legend: SeatingLegend(guests: allGuests)
        )

        let canvasSize = canvasPixelSize(
            tables: tables,
            roomCMSize: roomCMSize,
            pixelsPerCM: pixelsPerCM
        )
        // Legenden-Streifen unten anhängen — Skalierung mit pixelsPerCM, damit
        // die Schrift mitwächst und bei high-res PNGs nicht winzig wirkt.
        let legendScale: CGFloat = max(1.0, pixelsPerCM / 2)
        // availableWidth = legendRect-Innenbreite (pixelW - 32) — derselbe
        // Bereich, in den drawLegend rendert, sodass Reserve & Render synchron sind.
        let pngLegendHeight = legendBlockHeight(legend: ctx.legend, scale: legendScale,
                                                availableWidth: canvasSize.width - 32) + 24
        let pixelW = Int(canvasSize.width)
        let pixelH = Int(canvasSize.height + pngLegendHeight)
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

        // Tisch-Canvas füllt nur den oberen Bereich; der untere Streifen ist
        // für die Legende reserviert (außerhalb der Saalplan-Skala).
        let canvasRect = CGRect(x: 0, y: 0, width: CGFloat(pixelW), height: CGFloat(canvasSize.height))

        // Saalplan-Bild als Hintergrund (nur im oberen Bereich — der Legenden-
        // Streifen bleibt weiß und außerhalb der Saalplan-Skala).
        if let bg = roomBackground, let cgImage = bg.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.saveGState()
            context.draw(cgImage, in: canvasRect)
            context.restoreGState()
        }

        if !tables.isEmpty {
            drawCanvas(context: context, ctx: ctx, tables: tables, in: canvasRect.insetBy(dx: 20, dy: 20))
        }

        for label in labels {
            drawLabel(context: context, label: label, in: canvasRect, tables: tables, roomCMSize: roomCMSize)
        }

        // Legenden-Streifen unten.
        let legendRect = CGRect(
            x: 16,
            y: canvasRect.maxY + 12,
            width: CGFloat(pixelW) - 32,
            height: pngLegendHeight - 12
        )
        drawLegend(context: context, ctx: ctx, in: legendRect)

        guard let cgImage = context.makeImage() else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    static func canvasPixelSize(
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

    static func drawLabel(
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

    static func canvasPosition(
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

    static func generatePDF(
        tables: [GuestTable],
        eventName: String,
        date: Date?,
        nameStyle: NameStyle = .smartDeduped
    ) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
            return Data()
        }

        // Display-Names + Legende einmal pro Generate berechnen
        let allGuests = tables.flatMap(\.attendingGuests)
        let ctx = RenderContext(
            displayNames: displayNames(for: allGuests, style: nameStyle),
            renderScale: 1.0,
            legend: SeatingLegend(guests: allGuests)
        )

        var box = pageRect
        context.beginPage(mediaBox: &box)
        // Flip coordinate system so y=0 is at top (NSString.draw expects this)
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

        drawHeader(context: context, eventName: eventName, date: date)

        let reservedLegendHeight = legendBlockHeight(
            legend: ctx.legend,
            availableWidth: pageWidth - 2 * canvasMargin
        )
        let fullCanvasHeight = pageHeight - titleAreaHeight - 2 * canvasMargin
        let canvasArea = CGRect(
            x: canvasMargin,
            y: titleAreaHeight + canvasMargin,
            width: pageWidth - 2 * canvasMargin,
            height: fullCanvasHeight - reservedLegendHeight - 12
        )

        if tables.isEmpty {
            drawText(
                "Noch keine Tische platziert.",
                at: CGPoint(x: canvasArea.midX - 80, y: canvasArea.midY),
                font: .systemFont(ofSize: 14),
                color: PDFColors.tertiary
            )
        } else {
            drawCanvas(context: context, ctx: ctx, tables: tables, in: canvasArea)
        }

        let legendArea = CGRect(
            x: canvasMargin,
            y: canvasArea.maxY + 12,
            width: pageWidth - 2 * canvasMargin,
            height: reservedLegendHeight
        )
        drawLegend(context: context, ctx: ctx, in: legendArea)

        // WICHTIG: closePDF MUSS vor `return pdfData as Data` laufen.
        // Wenn closePDF in einem `defer` steht, passiert der NSData→Data
        // Snapshot vor dem Schreiben der schliessenden PDF-Bytes — das PDF
        // ist dann unvollstaendig und lässt sich nicht oeffnen.
        NSGraphicsContext.restoreGraphicsState()
        context.endPage()
        context.closePDF()
        return pdfData as Data
    }
}
#endif
