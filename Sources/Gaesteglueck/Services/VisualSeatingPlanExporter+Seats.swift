#if os(macOS)
import Foundation
import AppKit
import CoreText

extension VisualSeatingPlanExporter {
    // MARK: - Seat drawing

    static func drawSeat(
        context: CGContext,
        ctx: RenderContext,
        position: CGPoint,
        tableCenter: CGPoint,
        guest: Guest?,
        isDisabled: Bool,
        shape: TableShape,
        displayName: String? = nil,
        counterRotation: Double = 0
    ) {
        let r = ctx.seatDotDiameter / 2
        let dotRect = CGRect(x: position.x - r, y: position.y - r, width: ctx.seatDotDiameter, height: ctx.seatDotDiameter)

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
            let dr = ctx.dietDotDiameter / 2
            let dietRect = CGRect(
                x: position.x + r - dr * 0.8,
                y: position.y - r - dr * 0.8,
                width: ctx.dietDotDiameter,
                height: ctx.dietDotDiameter
            )
            context.setFillColor(dotColor.cgColor)
            context.fillEllipse(in: dietRect)
        }

        // Age badge bottom-left (Kind/Baby/…) — Symbol auf blauem Punkt.
        if guest.ageCategory.isMarkedAge {
            let d = ctx.dietDotDiameter * 1.25
            let badge = CGRect(
                x: position.x - r - d * 0.2,
                y: position.y + r - d * 0.8,
                width: d, height: d
            )
            context.setFillColor(ageColor.cgColor)
            context.fillEllipse(in: badge)
            drawSymbol(guest.ageCategory.iconName,
                       in: badge.insetBy(dx: d * 0.22, dy: d * 0.22),
                       color: .white)
        }

        context.restoreGState()

        // Guest name — positioned radially outward from table center,
        // counter-rotated damit der Name lesbar bleibt wenn der Tisch
        // gedreht ist.
        drawGuestName(
            context: context,
            ctx: ctx,
            guest: guest,
            seatPosition: position,
            tableCenter: tableCenter,
            shape: shape,
            displayName: displayName,
            counterRotation: counterRotation
        )
    }

    // MARK: - Guest name placement

    static func drawGuestName(
        context: CGContext,
        ctx: RenderContext,
        guest: Guest,
        seatPosition: CGPoint,
        tableCenter: CGPoint,
        shape: TableShape,
        displayName: String? = nil,
        counterRotation: Double = 0
    ) {
        let font = NSFont.systemFont(ofSize: ctx.nameFontSize)
        let allergyFont = NSFont.boldSystemFont(ofSize: ctx.nameFontSize)
        let name = displayName ?? ctx.displayNames[guest.id] ?? guest.firstName
        let nameAttr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: PDFColors.primary]
        let nameSize = (name as NSString).size(withAttributes: nameAttr)

        let dx = seatPosition.x - tableCenter.x
        let dy = seatPosition.y - tableCenter.y
        let r = ctx.seatDotDiameter / 2

        let anchorOffset: CGPoint
        if shape == .round {
            anchorOffset = nameAnchorRadiallyOutward(
                fromTableCenterDx: dx, dy: dy,
                textSize: nameSize, seatRadius: r, gap: ctx.nameOffset
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
                anchorOffset = CGPoint(x: -nameSize.width / 2, y: -r - ctx.nameOffset - nameSize.height)
            case .bottom:
                anchorOffset = CGPoint(x: -nameSize.width / 2, y: r + ctx.nameOffset)
            case .left:
                anchorOffset = CGPoint(x: -r - ctx.nameOffset - nameSize.width, y: -nameSize.height / 2)
            case .right:
                anchorOffset = CGPoint(x: r + ctx.nameOffset, y: -nameSize.height / 2)
            }
        }

        context.saveGState()
        context.translateBy(x: seatPosition.x, y: seatPosition.y)
        context.rotate(by: CGFloat(counterRotation) * .pi / 180)
        (name as NSString).draw(at: anchorOffset, withAttributes: nameAttr)

        if guest.hasIntolerances {
            let marker = intoleranceMarkerText(for: guest, ctx: ctx)
            let markerAttr: [NSAttributedString.Key: Any] = [.font: allergyFont, .foregroundColor: allergyColor]
            let markerOrigin = CGPoint(x: anchorOffset.x + nameSize.width + 3, y: anchorOffset.y)
            (marker as NSString).draw(at: markerOrigin, withAttributes: markerAttr)
        }
        context.restoreGState()
    }

    /// Zeichnet ein (template-getöntes) SF-Symbol in `rect`. Funktioniert im
    /// geflippten Export-Context, weil `NSImage.draw` die Flipped-ness des
    /// aktuellen `NSGraphicsContext` respektiert.
    static func drawSymbol(_ name: String, in rect: CGRect, color: NSColor) {
        let config = NSImage.SymbolConfiguration(pointSize: rect.height, weight: .bold)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let tinted = NSImage(size: rect.size)
        tinted.lockFocus()
        color.set()
        let r = NSRect(origin: .zero, size: rect.size)
        // Symbol zentriert ins Quadrat einpassen (Aspect-Fit).
        let aspect = base.size.width / max(base.size.height, 1)
        var drawRect = r
        if aspect > 1 {
            let h = rect.width / aspect
            drawRect = NSRect(x: 0, y: (rect.height - h) / 2, width: rect.width, height: h)
        } else {
            let w = rect.height * aspect
            drawRect = NSRect(x: (rect.width - w) / 2, y: 0, width: w, height: rect.height)
        }
        base.draw(in: drawRect)
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()
        tinted.draw(in: rect)
    }

    /// Komma-getrennte Nummern aus der aktuellen Render-Legende. Fallback "!"
    /// wenn ein Gast irgendwie keine aufgelösten Nummern hat (defensive — sollte
    /// nicht passieren, da die Legende aus *allen* Gästen gebaut wird).
    static func intoleranceMarkerText(for guest: Guest, ctx: RenderContext) -> String {
        let numbers = ctx.legend.numbers(for: guest)
        guard !numbers.isEmpty else { return "!" }
        return numbers.map(String.init).joined(separator: ",")
    }

    /// Liefert den Text-Origin so, dass die zur Tischmitte zugewandte Kante
    /// der Text-BBox am Sitz-Außenrand + `gap` sitzt — das Label "fließt"
    /// vom Sitz radial nach außen.
    static func nameAnchorRadiallyOutward(
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
    static func drawCenteredText(
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

}
#endif
