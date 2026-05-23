#if canImport(SwiftUI) && canImport(SwiftData)
import Testing
import Foundation
import CoreGraphics
@testable import Gaesteglueck

/// Verifiziert, dass die Namens-Innenkante (die zum Chip zeigt) stets
/// `chipRadius + gap` vom Chip-Zentrum entfernt liegt — auch bei gedrehten
/// Tischen. Bug-Historie: drei Anläufe, weil rotierte Tische die Layout-Box
/// nicht mit-rotieren. Diese Tests sichern die Geometrie ab.
@Suite("Seat name offset")
@MainActor
struct SeatNameOffsetTests {
    let chip: CGFloat = 22
    let gap: CGFloat = 6
    // Typisches Label (Name liest horizontal): breit, niedrig.
    let label = CGSize(width: 50, height: 12)

    /// Innenkante des Labels (zur Chip-Seite) — Distanz vom Chip-Zentrum
    /// entlang der Bildschirm-Achse, auf der das Label vom Chip weg zeigt.
    private func innerEdgeDistance(
        side: SeatNameSide, rotation: Double
    ) -> CGFloat {
        let off = SeatChipView.nameOffset(
            side: side, tableRotationDegrees: rotation,
            nameSize: label, chipSize: chip, gap: gap
        )
        // Bildschirm-Offset = lokaler Offset um die Tisch-Rotation gedreht.
        // Math explizit in Double (sonst cos/sin bei CGFloat×Double mehrdeutig).
        let r = rotation * .pi / 180
        let c = cos(r), s = sin(r)
        let screenX = CGFloat(Double(off.width) * c - Double(off.height) * s)
        let screenY = CGFloat(Double(off.width) * s + Double(off.height) * c)
        // Bildschirm-Richtung der Seite.
        let dir = side.localUnitVector
        let sdx = CGFloat(Double(dir.dx) * c - Double(dir.dy) * s)
        let sdy = CGFloat(Double(dir.dx) * s + Double(dir.dy) * c)
        // Label-Zentrum-Distanz entlang der Bildschirm-Richtung.
        let centerDist = abs(sdx) * abs(screenX) + abs(sdy) * abs(screenY)
        // Halbe Label-Ausdehnung entlang derselben Richtung (Label liest horizontal).
        let halfExtent = abs(sdx) * label.width / 2 + abs(sdy) * label.height / 2
        return centerDist - halfExtent
    }

    @Test("Ungedrehter Tisch: alle Seiten halten chipRadius + gap")
    func unrotatedAllSides() {
        for side in [SeatNameSide.left, .right, .top, .bottom] {
            let d = innerEdgeDistance(side: side, rotation: 0)
            #expect(abs(d - (chip / 2 + gap)) < 0.01)
        }
    }

    @Test("90°-gedrehter Tisch: Innenkante bleibt chipRadius + gap (der Bug-Fall)")
    func rotated90() {
        for side in [SeatNameSide.left, .right, .top, .bottom] {
            let d = innerEdgeDistance(side: side, rotation: 90)
            #expect(abs(d - (chip / 2 + gap)) < 0.01)
        }
    }

    @Test("270°-gedrehter Tisch: Innenkante bleibt chipRadius + gap")
    func rotated270() {
        for side in [SeatNameSide.left, .right, .top, .bottom] {
            let d = innerEdgeDistance(side: side, rotation: 270)
            #expect(abs(d - (chip / 2 + gap)) < 0.01)
        }
    }

    @Test("Längere Namen schieben weiter raus, Innenkante-Abstand bleibt gleich")
    func longerNamesKeepGap() {
        let shortOff = SeatChipView.nameOffset(
            side: .left, tableRotationDegrees: 0,
            nameSize: CGSize(width: 30, height: 12), chipSize: chip, gap: gap
        )
        let longOff = SeatChipView.nameOffset(
            side: .left, tableRotationDegrees: 0,
            nameSize: CGSize(width: 80, height: 12), chipSize: chip, gap: gap
        )
        // Längerer Name → größerer Betrag (Zentrum weiter weg) …
        #expect(abs(longOff.width) > abs(shortOff.width))
        // … aber Innenkante (Zentrum - halbe Breite) identisch.
        let shortInner = abs(shortOff.width) - CGFloat(30) / 2
        let longInner = abs(longOff.width) - CGFloat(80) / 2
        #expect(abs(shortInner - longInner) < 0.01)
        #expect(abs(shortInner - (chip / 2 + gap)) < 0.01)
    }
}
#endif
