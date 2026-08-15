#if os(macOS)
#if canImport(AppKit)
import AppKit
import CoreGraphics
import CoreText
import Foundation

/// Seitenmaße der PDF-Exporte in PostScript-Punkten (72 dpi).
enum PDFPageSize {
    static let a4 = CGRect(x: 0, y: 0, width: 595, height: 842)
    static let a3Landscape = CGRect(x: 0, y: 0, width: 1191, height: 842)
}

/// Gemeinsame Zeichen-Primitiven der PDF-Exporter.
///
/// Es gibt zwei Text-Varianten, weil die Exporter in unterschiedlichen
/// Koordinatensystemen arbeiten: die AppKit-Variante zeichnet in einen
/// bereits geflippten `NSGraphicsContext`, die CoreText-Variante rechnet
/// die Top-Left-Position selbst in CoreGraphics' Bottom-Up-Y um.
enum PDFDrawing {
    /// Zeichnet Text im geflippten AppKit-Context (Top-Left-Ursprung).
    static func drawText(
        _ text: String,
        at point: CGPoint,
        font: NSFont,
        color: NSColor = PDFColors.primary
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }

    /// Zeichnet Text direkt via CoreText in einen `CGContext`.
    /// `point` ist Top-Left; `pageRect` liefert die Höhe für die Y-Umrechnung.
    static func drawText(
        _ text: String,
        at point: CGPoint,
        font: NSFont,
        color: CGColor,
        in context: CGContext,
        pageRect: CGRect
    ) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attrs))
        context.textPosition = CGPoint(x: point.x, y: pageRect.height - point.y - font.ascender)
        CTLineDraw(line, context)
    }
}
#endif
#endif
