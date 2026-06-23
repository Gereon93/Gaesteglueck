#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Structured plan logic

extension KIWizardView {
    // MARK: - Structured plan request

    /// Baut aus den Brauttafel-Toggles eine konkrete Anweisung für den LLM.
    /// Der User sagt z.B. "Trauzeugen + Eltern" — das wird zu einem Hard-Hint
    /// im Prompt: "Brautpaar + Trauzeugen + Eltern müssen am Brauttisch sitzen,
    /// nicht andere Gäste, solange Brauttisch nicht voll".
    private func computeBridalRule() -> String? {
        if bridalManualMode { return nil }
        var groups: [String] = []
        if bridalIncludeTrauzeugen { groups.append("Trauzeugen / Brautjungfern") }
        if bridalIncludeEltern { groups.append("Eltern beider Brautpaar-Seiten") }
        if bridalIncludeGeschwister { groups.append("Geschwister beider Brautpaar-Seiten") }
        guard !groups.isEmpty else {
            return "Nur das Brautpaar selbst sitzt am Brauttisch — keine weiteren Gäste."
        }
        let primary = groups.joined(separator: ", ")
        var rule = "Am Brauttisch sitzen: das Brautpaar plus \(primary). Andere Gäste dort nur wenn Brauttisch noch frei und alle obigen Personen platziert sind."
        // Soft-Fill-Hinweis für nicht-gewählte Kategorien
        var fillCandidates: [String] = []
        if !bridalIncludeEltern { fillCandidates.append("Eltern") }
        if !bridalIncludeGeschwister { fillCandidates.append("Geschwister") }
        if !fillCandidates.isEmpty {
            rule += " Falls dort noch Plätze frei sind, fülle sie BEVORZUGT mit \(fillCandidates.joined(separator: ", ")) auf, nicht mit Freunden/Aktivitäts-Gruppen."
        }
        return rule
    }

    func requestStructuredPlan() {
        guard !guests.isEmpty, !tables.isEmpty else { return }
        isRequestingPlan = true
        errorMessage = nil

        let bridalRule = computeBridalRule()

        // KI plant nur die noch UNPLATZIERTEN Gäste. Bereits gesetzte (manuell
        // oder gepinnt) bleiben unangetastet. Restkapazität pro Tisch wird
        // entsprechend reduziert übergeben.
        let unplacedGuests = guests.filter(\.awaitsSeating)
        let placedCounts: [UUID: Int] = Dictionary(uniqueKeysWithValues: tables.map { table in
            (table.id, table.attendingGuests.filter { $0.needsSeat }.count)
        })
        let remainingCapacity: [UUID: Int] = Dictionary(uniqueKeysWithValues: tables.map { table in
            (table.id, max(0, table.effectiveCapacity - (placedCounts[table.id] ?? 0)))
        })

        guard !unplacedGuests.isEmpty else {
            errorMessage = "Alle Gäste sind bereits platziert. Mit 'Zuweisungen löschen' leeren falls du neu planen willst."
            isRequestingPlan = false
            return
        }

        // Constraints, die einen bereits-platzierten Gast referenzieren, kann
        // die KI nicht mehr beeinflussen — schicken wir gar nicht erst rein,
        // sonst wuerden sie gegen Pinned/Placed-Gaeste verletzt ohne Warnung.
        let unplacedIDs = Set(unplacedGuests.map(\.id))
        let actionableConstraints = constraints.filter { c in
            c.guestIDs.allSatisfy { unplacedIDs.contains($0) }
        }

        let context = LLMSeatingPlanner.PlannerContext(
            guests: unplacedGuests,
            tables: Array(tables),
            tags: Array(tags),
            constraints: actionableConstraints,
            bridalRule: bridalRule,
            tableRemainingCapacity: remainingCapacity
        )
        let (userPrompt, guestMap, tableMap) = LLMSeatingPlanner.buildPrompt(from: context)
        let systemPrompt = LLMSeatingPlanner.systemPrompt

        // Snapshot guest/table IDs for post-response validation on the main actor.
        let allGuestIDs = Set(unplacedGuests.map(\.id))
        let tableCapacities: [UUID: Int] = remainingCapacity
        let tableNames: [UUID: String] = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.name) })
        let guestNames: [UUID: String] = Dictionary(uniqueKeysWithValues: guests.map { ($0.id, $0.fullName) })
        let hardConstraints: [(type: ConstraintType, guestIDs: [UUID], reason: String)] = actionableConstraints.map {
            ($0.type, $0.guestIDs, $0.reason)
        }

        Task { @Sendable in
            let client = LLMClientFactory.makeClient(for: .seating)
            do {
                let raw = try await client.prompt(system: systemPrompt, user: userPrompt, temperature: 0.2)
                let plan = try LLMSeatingPlanner.parseRawResponse(
                    raw,
                    guestIDMap: guestMap,
                    tableIDMap: tableMap,
                    allGuestIDs: allGuestIDs,
                    tableCapacities: tableCapacities,
                    tableNames: tableNames,
                    guestNames: guestNames,
                    hardConstraints: hardConstraints
                )
                await MainActor.run {
                    proposedPlan = plan
                    planApplied = false
                    isRequestingPlan = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Konnte Plan nicht erstellen: \(error.localizedDescription)"
                    isRequestingPlan = false
                }
            }
        }
    }

    func applyProposedPlan(_ plan: LLMSeatingPlanner.ProposedAssignment) {
        // Map UUID → real table and assign each guest. Bereits platzierte
        // Gäste (table != nil) und gepinnte Gäste werden NICHT angefasst —
        // der KI-Plan ist nur für die zuvor-unplatzierten gedacht.
        let tablesByID = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0) })
        let guestsByID = Dictionary(uniqueKeysWithValues: guests.map { ($0.id, $0) })

        let rules = events.first?.seatingRules ?? .default
        var nextSeatByTable: [UUID: Int] = [:]
        for table in tables {
            let used = Set(table.guests.compactMap(\.seatIndex))
            let cap = table.capacity(rules: rules)
            let disabled = table.disabledSeatIndices.filter { $0 < cap }
            let firstFree = (0..<cap).first { !used.contains($0) && !disabled.contains($0) }
            nextSeatByTable[table.id] = firstFree ?? 0
        }

        for (guestID, tableID) in plan.assignments {
            guard let guest = guestsByID[guestID], let table = tablesByID[tableID] else { continue }
            if guest.isPinned { continue }
            if guest.table != nil { continue }
            guest.table = table

            let cap = table.capacity(rules: rules)
            let disabled = Set(table.disabledSeatIndices.filter { $0 < cap })
            let used = Set(table.guests.compactMap(\.seatIndex))
            var idx = nextSeatByTable[tableID] ?? 0
            while idx < cap, used.contains(idx) || disabled.contains(idx) { idx += 1 }
            if idx < cap {
                guest.seatIndex = idx
                nextSeatByTable[tableID] = idx + 1
            }
        }
        do {
            try modelContext.save()
            planApplied = true
        } catch {
            errorMessage = "Konnte Plan nicht speichern: \(error.localizedDescription)"
        }
    }
}
#endif
