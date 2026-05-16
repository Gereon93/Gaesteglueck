#if canImport(AppKit)
import Foundation
import AppKit

/// Druckfertiges Plakat im A3-Querformat. Delegiert an den Canvas-Renderer
/// (`VisualSeatingPlanExporter`), damit das Plakat 1:1 wie der App-Saalplan
/// aussieht — Tische an ihrer Raum-Position, Sitze als Kreise, Namen außen.
/// `unassignedGuests` wird ignoriert: das Plakat zeigt nur das räumliche Bild,
/// nicht-zugewiesene Gäste gehören nicht in den Saal.
enum PosterExporter {
    static func generatePDF(
        tables: [GuestTable],
        unassignedGuests: [Guest],
        eventName: String,
        date: Date?
    ) -> Data {
        _ = unassignedGuests
        return VisualSeatingPlanExporter.generatePDF(
            tables: tables,
            eventName: eventName,
            date: date,
            nameStyle: .full
        )
    }
}
#endif
