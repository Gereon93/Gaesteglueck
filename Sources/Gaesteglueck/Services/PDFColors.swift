#if canImport(AppKit)
import AppKit

/// Zentrale Farbpalette für PDF-Exporter.
/// Hintergrund: NSColor.labelColor / .secondaryLabelColor / .tertiaryLabelColor
/// sind dynamisch und werden im Off-Screen-PDF-Context oft als transparent
/// oder sehr hell gerendert. Die Konstanten hier sind explizite sRGB-Werte.
enum PDFColors {
    static let primary = NSColor(srgbRed: 0.10, green: 0.10, blue: 0.10, alpha: 1)
    static let secondary = NSColor(srgbRed: 0.40, green: 0.40, blue: 0.40, alpha: 1)
    static let tertiary = NSColor(srgbRed: 0.60, green: 0.60, blue: 0.60, alpha: 1)
    static let allergy = NSColor(srgbRed: 0.77, green: 0.29, blue: 0.29, alpha: 1)
    static let accent = NSColor(srgbRed: 0.78, green: 0.47, blue: 0.55, alpha: 1)
}
#endif
