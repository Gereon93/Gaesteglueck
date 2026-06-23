#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Allergie-Badge: Anzahl Gäste mit Unverträglichkeiten am Tisch.
/// `@AppStorage` mit identischem Key — bleibt automatisch mit dem Parent synchron.
struct TableCanvasAllergyBadge: View {
    @Bindable var table: GuestTable
    @AppStorage("canvasShowTableWarnings") private var showTableWarnings = true

    private var allergyCount: Int {
        table.attendingGuests.filter(\.hasIntolerances).count
    }

    private var allergyTooltip: String {
        let names = table.attendingGuests.filter(\.hasIntolerances).map(\.fullName).sorted().joined(separator: ", ")
        return "\(allergyCount) Gast\(allergyCount == 1 ? "" : "ä")ste mit Unverträglichkeiten: \(names)"
    }

    var body: some View {
        if showTableWarnings, allergyCount > 0 {
            HStack(spacing: 2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8, weight: .bold))
                Text("\(allergyCount)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color(hex: "#c44a4a"))
            .clipShape(Capsule())
            .help(allergyTooltip)
        }
    }
}

/// Späte-Absage-Badge: Anzahl Geister-Gäste (Platz frei, Catering bestellt).
struct TableCanvasLateCancellationBadge: View {
    @Bindable var table: GuestTable
    @AppStorage("canvasShowTableWarnings") private var showTableWarnings = true

    private var lateCancellationTooltip: String {
        let ghosts = table.ghostGuests
        let names = ghosts.map(\.fullName).sorted().joined(separator: ", ")
        return "\(ghosts.count) späte Absage\(ghosts.count == 1 ? "" : "n") – Platz frei, Catering ist bestellt: \(names)"
    }

    var body: some View {
        let ghosts = table.ghostGuests
        if showTableWarnings, !ghosts.isEmpty {
            HStack(spacing: 2) {
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 8, weight: .bold))
                Text("\(ghosts.count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Tokens.Colors.ink3)
            .clipShape(Capsule())
            .help(lateCancellationTooltip)
        }
    }
}

/// Eck-Overlay oben rechts: Herz (Brauttisch) bzw. Pin (gepinnter Gast).
struct TableCanvasBadgeOverlay: View {
    @Bindable var table: GuestTable

    private var hasPinnedGuest: Bool {
        table.guests.contains(where: { $0.isPinned })
    }

    var body: some View {
        if table.isBridalTable {
            ZStack {
                Circle().fill(Tokens.Colors.accent)
                Image(systemName: "heart.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            .offset(x: 6, y: -6)
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        } else if hasPinnedGuest {
            ZStack {
                Circle().fill(Tokens.Colors.accent)
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.white)
            }
            .frame(width: 18, height: 18)
            .offset(x: 6, y: -6)
            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
        }
    }
}
#endif
