#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

extension TagGeneratorView {
    // MARK: Generate

    @MainActor
    func generate() async {
        errorMessage = nil
        rawDebugResponse = nil
        isGenerating = true
        defer { isGenerating = false }

        // Schritt 1: lokal aus dem Freitext Tags ableiten — sofort, ohne KI.
        // Family-Begriffe werden bewusst übersprungen weil sie schon über
        // Guest.familyRole modelliert sind — sonst hätten wir 22 Tags von
        // denen 8 redundant wären.
        let snapshotsForLocal = guests.map { g in
            GuestSnapshot(
                id: g.id,
                fullName: g.fullName,
                partnerAssignment: g.partnerAssignment,
                registrationGroup: g.registrationGroup,
                funFact: g.funFact,
                notes: g.notes,
                profession: g.profession,
                hobbies: g.hobbies,
                familyRole: g.familyRole,
                familyRolePartner: g.familyRolePartner
            )
        }
        let derivation = LocalTagDeriver.derive(
            partner1Name: partner1Name,
            partner2Name: partner2Name,
            partner1Hint: partner1Hint,
            partner2Hint: partner2Hint,
            guests: snapshotsForLocal
        )
        let localResult = derivation.proposals
        skippedFamilyTerms = derivation.skippedFamilyTerms
        guard !localResult.isEmpty else {
            errorMessage = "Keine Tags aus dem Freitext erkannt — bitte mit Komma-getrennten Begriffen probieren."
            return
        }

        // Schritt 2 (optional): KI nutzt die Tags + Gästeliste um Mitglieder zuzuordnen
        if useAIForAssignment, !guests.isEmpty {
            let client = LLMClientFactory.makeClient(for: .tags)
            if let lm = client.lmStudioClient {
                do {
                    _ = try await lm.checkConnection()
                } catch {
                    proposals = localResult
                    hasGenerated = true
                    errorMessage = "Tags lokal erstellt — KI-Zuordnung übersprungen (LM Studio nicht erreichbar)."
                    return
                }
            }
            let service = TagSuggestionService(client: client)
            let snapshots = snapshotsForLocal
            do {
                let aiResult = try await service.generateWithRaw(
                    partner1Name: partner1Name,
                    partner2Name: partner2Name,
                    partner1Hint: partner1Hint,
                    partner2Hint: partner2Hint,
                    guests: snapshots
                )
                if aiResult.proposals.isEmpty {
                    proposals = localResult
                    errorMessage = "Tags lokal erstellt — KI-Zuordnung lieferte kein verwertbares JSON. Empfehlung: gemma-3-12b verwenden."
                    rawDebugResponse = aiResult.rawResponse
                } else {
                    // Lokal-Tags mit KI-Vorschlägen verheiraten: gleiche
                    // Namen → guestIDs der KI übernehmen.
                    var merged = localResult
                    for ai in aiResult.proposals {
                        if let idx = merged.firstIndex(where: { $0.name.lowercased() == ai.name.lowercased() }) {
                            merged[idx].guestIDs = ai.guestIDs
                        }
                    }
                    proposals = merged
                }
                hasGenerated = true
            } catch {
                proposals = localResult
                errorMessage = "Tags lokal erstellt — KI-Schritt fehlgeschlagen: \(error.localizedDescription)"
                hasGenerated = true
            }
        } else {
            proposals = localResult
            hasGenerated = true
        }
    }

    // MARK: Apply

    func applyProposals() {
        var affectedTags: [Tag] = []
        for proposal in proposals where proposal.accepted {
            affectedTags.append(applyOne(proposal))
        }
        modelContext.saveOrLog()
        derivePartnerSidesAfterApply(affectedTags: affectedTags)
        dismiss()
    }

    func derivePartnerSidesAfterApply(affectedTags: [Tag]) {
        let touchedIDs = Set(proposals.filter(\.accepted).flatMap(\.guestIDs))
        let mergedTags = mergeTagSnapshots(existingTags, affectedTags)
        for id in touchedIDs {
            if let g = guests.first(where: { $0.id == id }) {
                PartnerSideDeriver.applyIfUnassigned(g, in: mergedTags, allGuests: guests)
            }
        }
    }

    func mergeTagSnapshots(_ a: [Tag], _ b: [Tag]) -> [Tag] {
        var seen = Set<UUID>()
        var result: [Tag] = []
        for tag in a + b where !seen.contains(tag.id) {
            seen.insert(tag.id)
            result.append(tag)
        }
        return result
    }

    @discardableResult
    func applyOne(_ proposal: ProposedTag) -> Tag {
        if let existing = mergeIntoExistingTagIfMatching(proposal) {
            return existing
        }
        return insertNewTag(from: proposal)
    }

    func mergeIntoExistingTagIfMatching(_ proposal: ProposedTag) -> Tag? {
        guard let existing = existingTags.first(where: {
            $0.name.lowercased() == proposal.name.lowercased()
                && $0.partnerAssignment == proposal.partnerAssignment
        }) else { return nil }
        var union = Set(existing.guestIDs)
        for id in proposal.guestIDs { union.insert(id) }
        existing.guestIDs = Array(union)
        return existing
    }

    func insertNewTag(from proposal: ProposedTag) -> Tag {
        let tag = Tag(
            name: proposal.name,
            category: proposal.category,
            partnerAssignment: proposal.partnerAssignment
        )
        tag.guestIDs = proposal.guestIDs
        modelContext.insert(tag)
        return tag
    }
}
#endif
