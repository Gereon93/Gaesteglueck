#if os(macOS)
#if canImport(SwiftUI) && canImport(AppKit) && canImport(SwiftData)
import SwiftUI
import AppKit

/// Rendert den echten Sitzplan-Canvas (`SeatingPlanRenderView`) via
/// `ImageRenderer` zu PNG. Ein einziger Renderer — das Bild ist per
/// Definition exakt das was im Canvas zu sehen ist.
enum CanvasImageExporter {
    @MainActor
    static func generatePNG(
        tables: [GuestTable],
        displayNames: [UUID: String],
        rules: SeatingRules,
        scale: CGFloat,
        labels: [CanvasLabel] = [],
        background: NSImage? = nil,
        showSeatNames: Bool = true,
        infoDisplay: SeatInfoDisplay = .none,
        showAgeMarkers: Bool = false,
        chipContent: SeatChipContent = .initials,
        showTableWarnings: Bool = true,
        showRoomLabels: Bool = true,
        showLegend: Bool = true,
        legend: SeatingLegend = SeatingLegend(guests: []),
        nameFontSize: CGFloat = 9,
        showCoupleMarker: Bool = false,
        coupleNames: [String] = [],
        renderScale: CGFloat = 3
    ) -> Data? {
        let view = SeatingPlanRenderView(
            tables: tables,
            displayNames: displayNames,
            rules: rules,
            scale: scale,
            labels: labels,
            background: background,
            showSeatNames: showSeatNames,
            infoDisplay: infoDisplay,
            showAgeMarkers: showAgeMarkers,
            chipContent: chipContent,
            showTableWarnings: showTableWarnings,
            showRoomLabels: showRoomLabels,
            showLegend: showLegend,
            legend: legend,
            nameFontSize: nameFontSize,
            showCoupleMarker: showCoupleMarker,
            coupleNames: coupleNames
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = renderScale
        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:])
        else { return nil }
        return png
    }
}
#endif
#endif
