#if os(macOS)
import Foundation
import AppKit
import CoreText

extension VisualSeatingPlanExporter {
    // MARK: - Canvas layout

    static func drawCanvas(context: CGContext, ctx: RenderContext, tables: [GuestTable], in area: CGRect) {
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
                    ctx: ctx,
                    ownerTable: table,
                    group: group,
                    toCanvas: toCanvas,
                    scale: scale
                )
            } else {
                // Solo table rendering
                drawSoloTable(
                    context: context,
                    ctx: ctx,
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

    static func drawSoloTable(
        context: CGContext,
        ctx: RenderContext,
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
            let guest = table.attendingGuests.first { $0.seatIndex == idx }
            let isDisabled = table.disabledSeatIndices.contains(idx)
            drawSeat(
                context: context,
                ctx: ctx,
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

    static func drawTafelTable(
        context: CGContext,
        ctx: RenderContext,
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

        let totalGuests = group.flatMap(\.attendingGuests).count
        let totalCap = geometry.capacity - group.reduce(0) { $0 + $1.disabledSeatIndices.count }
        let countFont = NSFont.systemFont(ofSize: max(8, min(11, scaledWidth / 14)))
        drawCenteredText("\(totalGuests)/\(totalCap) Plätze", at: .zero, offsetY: 8, font: countFont, color: PDFColors.secondary)

        // Draw seats using TafelLayout seat positions (already in global canvas coords)
        // We need them relative to the rotated local frame of this table center
        let cosR = cos(-geometry.rotation * .pi / 180)
        let sinR = sin(-geometry.rotation * .pi / 180)

        for seat in geometry.seats {
            guard let table = group.first(where: { $0.id == seat.tableID }) else { continue }
            let guest = table.attendingGuests.first { $0.seatIndex == seat.localSeatIndex }
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
                ctx: ctx,
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

    static func drawTableShape(
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

    static func drawTableLabel(
        context: CGContext,
        table: GuestTable,
        scaledWidth: CGFloat,
        scaledDepth: CGFloat,
        scaledDiameter: CGFloat
    ) {
        let refSize: CGFloat = table.shape == .round ? scaledDiameter : max(scaledWidth, scaledDepth)
        let nameFont = NSFont.systemFont(ofSize: max(8, min(13, refSize / 8)), weight: .semibold)
        let occupancy = "\(table.attendingGuests.count)/\(table.effectiveCapacity) Plätze"
        let countFont = NSFont.systemFont(ofSize: max(7, min(11, refSize / 11)))

        // Counter-rotate damit das Label aufrecht bleibt wenn der Tisch
        // gedreht ist — sonst muss man den Plan zum Lesen drehen.
        context.saveGState()
        context.rotate(by: -CGFloat(table.rotation) * .pi / 180)
        drawCenteredText(table.name, at: .zero, offsetY: -8, font: nameFont)
        drawCenteredText(occupancy, at: .zero, offsetY: 8, font: countFont, color: PDFColors.secondary)
        context.restoreGState()
    }
}
#endif
