#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Platzierungs-Logik für Drag-&-Drop von Gästen auf Tische/Sitze. Reines
/// Modell-Verhalten ohne UI — daher als Helper ausgelagert und gut testbar.
enum TableCanvasPlacement {
    /// Findet alle Begleiter eines Gastes: identische Anmeldegruppe oder
    /// gemeinsamer mustSitTogether-Constraint. Filtert isPinned.
    static func companions(
        of guest: Guest,
        allGuests: [Guest],
        allConstraints: [Constraint]
    ) -> [Guest] {
        var companionIDs = Set<UUID>()

        if let group = guest.registrationGroup {
            for g in allGuests where g.id != guest.id && g.registrationGroup == group {
                companionIDs.insert(g.id)
            }
        }

        for c in allConstraints where c.type == .mustSitTogether && c.guestIDs.contains(guest.id) {
            for id in c.guestIDs where id != guest.id {
                companionIDs.insert(id)
            }
        }

        return allGuests.filter { companionIDs.contains($0.id) && !$0.isPinned }
    }

    /// Platziert einen Gast (plus Begleiter) auf dem Tisch. Wenn `primarySeatIndex`
    /// gesetzt: der Gast nimmt diesen konkreten Sitz; Begleiter werden räumlich
    /// nächst-möglich daneben platziert. Sonst bekommt der primäre Gast den
    /// ersten freien Sitz, Begleiter folgen räumlich daneben.
    @discardableResult
    static func placeGuestWithCompanions(
        guest: Guest,
        on target: GuestTable,
        primarySeatIndex: Int?,
        allGuests: [Guest],
        allConstraints: [Constraint],
        rules: SeatingRules
    ) -> Bool {
        let peerList = companions(of: guest, allGuests: allGuests, allConstraints: allConstraints)
        let toPlace = [guest] + peerList.filter { $0.table?.id != target.id }
        let cap = target.capacity(rules: rules)
        let disabled = target.disabledSeatIndices.filter { $0 < cap }

        var used: Set<Int> = Set(target.guests.compactMap { g in
            toPlace.contains(where: { $0.id == g.id }) ? nil : g.seatIndex
        })

        let positions = SeatLayout.positions(
            shape: target.shape,
            capacity: cap,
            scaledDiameter: CGFloat(target.diameter),
            scaledWidth: CGFloat(target.width),
            scaledDepth: CGFloat(target.depth)
        )

        func position(of idx: Int) -> CGPoint? {
            guard idx >= 0 && idx < positions.count else { return nil }
            return positions[idx]
        }

        func nearestFree(to anchor: CGPoint?) -> Int? {
            let candidates = (0..<cap).filter { !used.contains($0) && !disabled.contains($0) }
            guard !candidates.isEmpty else { return nil }
            guard let anchor = anchor else { return candidates.first }
            return candidates.min { a, b in
                let pa = position(of: a) ?? .zero
                let pb = position(of: b) ?? .zero
                let dxA = pa.x - anchor.x, dyA = pa.y - anchor.y
                let dxB = pb.x - anchor.x, dyB = pb.y - anchor.y
                return (dxA*dxA + dyA*dyA) < (dxB*dxB + dyB*dyB)
            }
        }

        var anchor: CGPoint?

        if let primary = primarySeatIndex, !disabled.contains(primary) {
            if let prior = target.guests.first(where: { $0.seatIndex == primary && $0.id != guest.id }) {
                prior.seatIndex = guest.table?.id == target.id ? guest.seatIndex : nil
            }
            guest.table = target
            guest.seatIndex = primary
            used.insert(primary)
            anchor = position(of: primary)
        } else if primarySeatIndex != nil {
            // Drop landete auf einem gesperrten Sitz — Fallback auf nächsten freien.
            guard let first = nearestFree(to: nil) else { return false }
            guest.table = target
            guest.seatIndex = first
            used.insert(first)
            anchor = position(of: first)
        } else {
            guard let first = nearestFree(to: nil) else { return false }
            guest.table = target
            guest.seatIndex = first
            used.insert(first)
            anchor = position(of: first)
        }

        for peer in toPlace where peer.id != guest.id {
            guard let chosen = nearestFree(to: anchor) else {
                return true
            }
            peer.table = target
            peer.seatIndex = chosen
            used.insert(chosen)
            // Anker bleibt am Primärgast — alle Begleiter clustern sich um ihn
        }
        return true
    }
}
#endif
