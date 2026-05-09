#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Kleiner Sitz-Punkt um den Tisch herum. Empty = grau-gestrichelt; Occupied
/// = farbig mit Initialen + ggf. Allergie-Indikator. Drop-Ziel für Guest-IDs
/// und draggable wenn besetzt — beides läuft über den `String`-Pasteboard,
/// genau wie bei der Gäste-Liste.
struct SeatChipView: View {
    let seatIndex: Int
    let occupant: Guest?
    /// Wird gerufen wenn ein Gast (per UUID-String) auf diesen Sitz gedroppt wird.
    let onDrop: (UUID) -> Bool
    /// Wird gerufen wenn der User den Sitz leert (Doppelklick / Context-Menü).
    let onClear: () -> Void

    @State private var isDropTargeted: Bool = false

    private var initials: String {
        guard let g = occupant else { return "" }
        let first = g.firstName.prefix(1)
        let last = g.lastName.prefix(1)
        return (first + last).uppercased()
    }

    private var fillColor: Color {
        if isDropTargeted { return Tokens.Colors.accentSoft }
        return occupant == nil ? Tokens.Colors.surface : Tokens.Colors.accentTint
    }

    private var strokeColor: Color {
        if isDropTargeted { return Tokens.Colors.accent }
        return occupant == nil ? Tokens.Colors.line2 : Tokens.Colors.accent.opacity(0.7)
    }

    private var tooltip: String {
        if let g = occupant {
            var t = "Sitz \(seatIndex + 1) — \(g.fullName)"
            if g.hasIntolerances {
                t += " ⚠️ \(g.intolerances.joined(separator: ", "))"
            }
            return t
        }
        return "Sitz \(seatIndex + 1) — frei. Gast hierher ziehen."
    }

    var body: some View {
        ZStack {
            Circle().fill(fillColor)
            Circle().strokeBorder(strokeColor, lineWidth: occupant == nil ? 1 : 1.5)
            if !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .monospacedDigit()
            }
            if let g = occupant, g.hasIntolerances {
                Circle()
                    .fill(Tokens.Colors.error)
                    .frame(width: 6, height: 6)
                    .offset(x: 7, y: -7)
            }
        }
        .frame(width: 22, height: 22)
        .help(tooltip)
        .contentShape(Circle())
        .conditionalDraggable(occupant: occupant)
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            return onDrop(id)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .contextMenu {
            if occupant != nil {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label("Sitzplatz leeren", systemImage: "person.fill.xmark")
                }
            }
        }
    }
}

private extension View {
    /// Macht den Sitz nur draggable wenn besetzt — leerer Sitz verschluckt sonst
    /// den Drag-Start und wirkt wie ein nicht-funktionaler Button.
    @ViewBuilder
    func conditionalDraggable(occupant: Guest?) -> some View {
        if let g = occupant {
            self.draggable(g.id.uuidString)
        } else {
            self
        }
    }
}
#endif
