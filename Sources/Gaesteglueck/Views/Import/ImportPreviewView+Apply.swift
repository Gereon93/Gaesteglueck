#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

extension ImportPreviewView {
    // MARK: - Apply

    func updateGuests(at index: Int, with guests: [ImportedGuest]) {
        // Edits aus dem Card → State updaten. Wir bleiben im gleichen
        // Zustand-Bucket (parsed / fallback), nur die Liste tauscht.
        guard let current = rowStates[index] else { return }
        switch current {
        case .parsing:
            rowStates[index] = .parsed(guests)
        case .parsed:
            rowStates[index] = .parsed(guests)
        case .fallback(_, let reason):
            rowStates[index] = .fallback(guests, reason: reason)
        }
    }

    func applyRow(at index: Int) {
        guard let state = rowStates[index] else { return }
        let guests = state.guests
        guard !guests.isEmpty else { return }

        let row = rows[index]
        let registrationGroup = UUID()
        var insertedOrUpdatedGuests: [Guest] = []

        for ig in guests {
            if let existing = ImportMatcher.findExisting(guest: ig, in: row, among: existingGuests) {
                // Sicheres Match → Felder updaten
                existing.dietaryChoice = ig.dietaryChoice
                existing.intolerances = ig.intolerances
                existing.ageCategory = ig.ageCategory
                // funFact nur setzen wenn der bestehende Eintrag noch keinen hat —
                // manuelle Pflege gewinnt gegen Auto-Extraktion beim Re-Import.
                if existing.funFact.isEmpty, !ig.funFact.isEmpty {
                    existing.funFact = ig.funFact
                }
                if existing.registrationGroup == nil {
                    existing.registrationGroup = registrationGroup
                }
                if existing.sourceID.isEmpty {
                    existing.sourceID = row.sourceID
                    existing.sourceEmail = row.sourceEmail
                }
                for tagName in ig.tagNames {
                    attachTag(named: tagName, to: existing)
                }
                insertedOrUpdatedGuests.append(existing)
            } else {
                let guest = Guest(
                    firstName: ig.firstName,
                    lastName: ig.lastName,
                    ageCategory: ig.ageCategory,
                    dietaryChoice: ig.dietaryChoice,
                    intolerances: ig.intolerances,
                    funFact: ig.funFact,
                    notes: ig.notes,
                    registrationGroup: registrationGroup,
                    sourceID: row.sourceID,
                    sourceEmail: row.sourceEmail
                )
                modelContext.insert(guest)
                for tagName in ig.tagNames {
                    attachTag(named: tagName, to: guest)
                }
                insertedOrUpdatedGuests.append(guest)
            }
        }

        // Eine gemeinsame Anmeldung mit 2+ Personen → automatischer "muss
        // zusammen sitzen"-Constraint. Lou + Resi, ein Ehepaar oder eine
        // Familie mit Begleitung soll nicht von der KI getrennt werden.
        if insertedOrUpdatedGuests.count >= 2 {
            let groupIDs = insertedOrUpdatedGuests.map(\.id)
            let alreadyExists = existingConstraints.contains { c in
                c.type == .mustSitTogether && Set(c.guestIDs) == Set(groupIDs)
            }
            if !alreadyExists {
                let reason = "Gemeinsame Anmeldung — \(row.familyName)"
                let constraint = Constraint(type: .mustSitTogether, guestIDs: groupIDs, reason: reason)
                modelContext.insert(constraint)
            }
        }

        importedIndices.insert(index)
    }

    func persistSkip(rowIndex: Int) {
        let sourceID = rows[rowIndex].sourceID
        guard !sourceID.isEmpty, let event = currentEvent else { return }
        if !event.skippedSourceIDs.contains(sourceID) {
            event.skippedSourceIDs.append(sourceID)
        }
    }

    func attachTag(named name: String, to guest: Guest) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = existingTags.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            if !existing.guestIDs.contains(guest.id) {
                existing.guestIDs.append(guest.id)
            }
        } else {
            let category: TagCategory = trimmed.lowercased().contains("familie") ? .family : .custom
            let newTag = Tag(name: trimmed, category: category)
            newTag.guestIDs = [guest.id]
            modelContext.insert(newTag)
        }
    }

    func finalize() {
        let imported = importedIndices.reduce(0) { sum, i in
            sum + (rowStates[i]?.guests.count ?? 0)
        }
        onComplete(imported)
        dismiss()
    }
}
#endif
