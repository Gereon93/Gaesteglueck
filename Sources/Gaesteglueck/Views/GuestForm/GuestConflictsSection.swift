#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Tabus (mustNotSitTogether) im Gast-Formular. Wird nur gerendert wenn ein
/// bestehender Gast bearbeitet wird; die Add-Form-Felder
/// (`newConflictGuestID`/`newConflictReason`) leben daher lokal als @State.
struct GuestConflictsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var allGuests: [Guest]
    @Query private var allConstraints: [Constraint]

    let guest: Guest?
    let firstName: String

    @State private var newConflictGuestID: UUID? = nil
    @State private var newConflictReason: String = ""

    // MARK: - Konflikte (mustNotSitTogether)

    /// Constraints vom Typ mustNotSitTogether, in denen dieser Gast vorkommt.
    private var conflictsForThisGuest: [Constraint] {
        guard let g = guest else { return [] }
        return allConstraints.filter {
            $0.type == .mustNotSitTogether && $0.guestIDs.contains(g.id)
        }
    }

    /// Alle anderen Gäste — für den Picker beim Hinzufügen eines Konflikts.
    private var otherGuests: [Guest] {
        allGuests.filter { $0.id != guest?.id }
    }

    @ViewBuilder
    var body: some View {
        Section {
            if conflictsForThisGuest.isEmpty {
                Text("Keine Tabus für \(firstName.isEmpty ? "diesen Gast" : firstName).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(conflictsForThisGuest) { c in
                    let otherID = c.guestIDs.first { $0 != guest?.id }
                    let other = otherID.flatMap { id in allGuests.first(where: { $0.id == id }) }
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
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

            // Add-Form
            VStack(alignment: .leading, spacing: 6) {
                Picker("Tabu mit", selection: $newConflictGuestID) {
                    Text("Gast wählen …").tag(nil as UUID?)
                    ForEach(eligibleConflictTargets) { g in
                        Text(g.fullName).tag(g.id as UUID?)
                    }
                }
                LabeledContent("Grund (optional)") {
                    TextField("z.B. Streit auf der letzten Familienfeier", text: $newConflictReason)
                }
                HStack {
                    Spacer()
                    Button("Tabu hinzufügen") {
                        addConflict()
                    }
                    .disabled(newConflictGuestID == nil || guest == nil)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Tabus — sollte NICHT zusammen sitzen")
        } footer: {
            Text("Der Sitzplaner stellt sicher, dass diese beiden Gäste an unterschiedlichen Tischen platziert werden.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Filter aus dem Picker: keine Selbst-Referenz, kein bereits bestehender
    /// Tabu-Eintrag (sonst hätte man Duplikate).
    private var eligibleConflictTargets: [Guest] {
        let alreadyConflicting = Set(conflictsForThisGuest.flatMap { $0.guestIDs })
        return otherGuests.filter { !alreadyConflicting.contains($0.id) }
    }

    private func addConflict() {
        guard let g = guest, let otherID = newConflictGuestID else { return }
        let constraint = Constraint(
            type: .mustNotSitTogether,
            guestIDs: [g.id, otherID],
            reason: newConflictReason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(constraint)
        newConflictGuestID = nil
        newConflictReason = ""
    }
}
#endif
