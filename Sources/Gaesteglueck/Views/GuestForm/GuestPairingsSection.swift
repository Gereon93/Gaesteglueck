#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Pflicht-Verknüpfungen (mustSitTogether) im Gast-Formular. Wird nur
/// gerendert wenn ein bestehender Gast bearbeitet wird; die Add-Form-Felder
/// (`newPairGuestID`/`newPairReason`) leben daher lokal als @State.
struct GuestPairingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var allGuests: [Guest]
    @Query private var allConstraints: [Constraint]

    let guest: Guest?
    let firstName: String

    @State private var newPairGuestID: UUID? = nil
    @State private var newPairReason: String = ""

    // MARK: - Pairings (mustSitTogether)

    /// Constraints vom Typ mustSitTogether die diesen Gast referenzieren UND
    /// nicht aus einer registrationGroup-Auto-Erstellung stammen. Eine
    /// Anmeldungs-Gruppe-Constraint hat den Reason-Prefix "Gemeinsame Anmeldung —"
    /// und wird nicht als manuelle Pairing angezeigt — sonst blendet die UI
    /// die Familie selbst doppelt rein.
    private var pairingsForThisGuest: [Constraint] {
        guard let g = guest else { return [] }
        return allConstraints.filter {
            $0.type == .mustSitTogether
                && $0.guestIDs.contains(g.id)
                && !$0.reason.hasPrefix("Gemeinsame Anmeldung")
        }
    }

    /// Alle anderen Gäste — Basis für die Picker-Auswahl.
    private var otherGuests: [Guest] {
        allGuests.filter { $0.id != guest?.id }
    }

    private var eligiblePairingTargets: [Guest] {
        let alreadyPaired = Set(pairingsForThisGuest.flatMap { $0.guestIDs })
        return otherGuests.filter { !alreadyPaired.contains($0.id) }
    }

    @ViewBuilder
    var body: some View {
        Section {
            if pairingsForThisGuest.isEmpty {
                Text("Niemand fest mit \(firstName.isEmpty ? "diesem Gast" : firstName) verknüpft. Anmeldungs-Gruppen werden automatisch zusammengehalten — hier sind nur zusätzliche Pflicht-Verknüpfungen sichtbar (z.B. 'Manuel muss zu Karen').")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(pairingsForThisGuest) { c in
                    let otherID = c.guestIDs.first { $0 != guest?.id }
                    let other = otherID.flatMap { id in allGuests.first(where: { $0.id == id }) }
                    HStack(spacing: 8) {
                        Image(systemName: "link.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(other?.fullName ?? "—")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                            if !c.reason.isEmpty {
                                Text(c.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            modelContext.delete(c)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Picker("Pflicht-Nachbar", selection: $newPairGuestID) {
                    Text("Gast wählen …").tag(nil as UUID?)
                    ForEach(eligiblePairingTargets) { g in
                        Text(g.fullName).tag(g.id as UUID?)
                    }
                }
                LabeledContent("Beziehung (optional)") {
                    TextField("z.B. Mann von Karen, Plus-1, …", text: $newPairReason)
                }
                HStack {
                    Spacer()
                    Button("Pflicht-Verknüpfung hinzufügen") {
                        addPairing()
                    }
                    .disabled(newPairGuestID == nil || guest == nil)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Muss zusammen sitzen mit")
        } footer: {
            Text("Der Sitzplaner platziert diese beiden Gäste garantiert am gleichen Tisch — auch wenn sie nicht in der gleichen Anmeldung sind. Spiegelt sich beidseitig (öffnest du den anderen Gast, ist die Verknüpfung dort auch sichtbar).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func addPairing() {
        guard let g = guest, let otherID = newPairGuestID else { return }
        let constraint = Constraint(
            type: .mustSitTogether,
            guestIDs: [g.id, otherID],
            reason: newPairReason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(constraint)
        newPairGuestID = nil
        newPairReason = ""
    }
}
#endif
