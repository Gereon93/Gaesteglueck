import Foundation

/// Converts free-form LLM seating output into concrete guestID → tableID assignments.
///
/// Flow:
/// 1. We build a short, stable identifier map (G1, G2, … and T1, T2, …) so the
///    model doesn't have to handle UUIDs. UUIDs are extremely token-hungry and
///    small models mis-copy them constantly.
/// 2. System prompt forces a strict JSON output schema.
/// 3. Response is parsed, validated against capacity and constraints, and
///    translated back to real UUIDs.
enum LLMSeatingPlanner {
    struct PlannerContext {
        let guests: [Guest]
        let tables: [GuestTable]
        let tags: [Tag]
        let constraints: [Constraint]
    }

    struct ProposedAssignment: Sendable {
        /// Real guestID → real tableID.
        let assignments: [UUID: UUID]
        /// Optional per-table rationale from the model.
        let rationale: [UUID: String]
        /// Warnings/validation issues the parser detected.
        let warnings: [String]
    }

    // JSON envelope we ask the model for.
    struct LLMPlan: Codable, Sendable {
        struct TablePlan: Codable, Sendable {
            let table: String   // "T1"
            let guests: [String] // ["G3", "G7"]
            let reason: String?
        }
        let plan: [TablePlan]
    }

    // CR#4: Removed unused unknownGuest/unknownTable cases — unknown IDs are
    // handled via warnings, not thrown errors.
    enum PlannerError: Error, LocalizedError {
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .invalidJSON(let d): "KI-Antwort nicht als JSON lesbar: \(d)"
            }
        }
    }

    // MARK: - Prompt building

    static let systemPrompt = """
        Du bist ein Hochzeitsplaner-Solver. Du bekommst eine Liste Gäste (G1, G2, ...), \
        eine Liste Tische (T1, T2, ...) und deren Kapazitäten sowie Tags, Beziehungen \
        und harte Constraints.

        Deine Aufgabe: verteile ALLE Gäste auf die Tische. Beachte:
        - Harte Constraints (müssen/dürfen nicht zusammen) sind bindend.
        - Kapazitäten dürfen nicht überschritten werden.
        - Tag-Mitglieder sollen möglichst zusammen sitzen.
        - Kindertische bevorzugt für Kinder.
        - Paare (mit selber Familie, beide Erwachsene) bleiben zusammen.
        - Jeder Gast genau 1x.

        Antworte AUSSCHLIESSLICH mit JSON in genau diesem Schema, ohne Markdown, ohne Erklärungen:

        {
          "plan": [
            {
              "table": "T1",
              "guests": ["G1", "G2", "G3"],
              "reason": "Kurze Begründung"
            }
          ]
        }

        Keine Strings außerhalb des JSON. Keine zusätzlichen Felder.
        """

    /// Build the user prompt with stable G/T identifiers.
    static func buildPrompt(from context: PlannerContext) -> (prompt: String, guestIDMap: [String: UUID], tableIDMap: [String: UUID]) {
        var guestMap: [String: UUID] = [:]
        var tableMap: [String: UUID] = [:]

        var lines: [String] = []
        lines.append("## Gäste (\(context.guests.count))")
        for (i, guest) in context.guests.enumerated() {
            let key = "G\(i + 1)"
            guestMap[key] = guest.id
            var line = "- \(key): \(guest.fullName) [\(guest.partnerAssignment.rawValue)]"
            if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
            if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
            let guestTags = context.tags.filter { $0.guestIDs.contains(guest.id) }.map(\.name)
            if !guestTags.isEmpty { line += " Tags: \(guestTags.joined(separator: ", "))" }
            lines.append(line)
        }

        lines.append("")
        lines.append("## Tische (\(context.tables.count))")
        for (i, table) in context.tables.enumerated() {
            let key = "T\(i + 1)"
            tableMap[key] = table.id
            var line = "- \(key): \(table.name) | Kapazität \(table.capacity)"
            if table.isChildTable { line += " [KINDERTISCH]" }
            lines.append(line)
        }

        if !context.constraints.isEmpty {
            lines.append("")
            lines.append("## Harte Constraints")
            let reverseGuest = Dictionary(uniqueKeysWithValues: guestMap.map { ($0.value, $0.key) })
            for constraint in context.constraints {
                let keys = constraint.guestIDs.compactMap { reverseGuest[$0] }
                lines.append("- \(constraint.type.rawValue): \(keys.joined(separator: ", "))")
            }
        }

        lines.append("")
        lines.append("Gib jetzt den Plan als JSON zurück.")

        return (lines.joined(separator: "\n"), guestMap, tableMap)
    }

    // MARK: - Parsing & validation

    /// Extract the first `{…}` JSON object from a model response (may contain prose).
    static func extractJSONObject(from text: String) -> String {
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // CR#5: Single shared implementation — both parsePlan and parseRawResponse
    // delegate to this core helper that takes only Sendable primitives.

    /// Parse raw LLM text using only Sendable primitives. Safe to call from any actor.
    static func parseRawResponse(
        _ text: String,
        guestIDMap: [String: UUID],
        tableIDMap: [String: UUID],
        allGuestIDs: Set<UUID>,
        tableCapacities: [UUID: Int],
        tableNames: [UUID: String],
        hardConstraints: [(type: ConstraintType, guestIDs: [UUID], reason: String)]
    ) throws -> ProposedAssignment {
        let json = extractJSONObject(from: text)
        guard let data = json.data(using: .utf8) else {
            throw PlannerError.invalidJSON("kein UTF-8")
        }
        let plan: LLMPlan
        do {
            plan = try JSONDecoder().decode(LLMPlan.self, from: data)
        } catch {
            throw PlannerError.invalidJSON(error.localizedDescription)
        }

        var assignments: [UUID: UUID] = [:]
        var rationale: [UUID: String] = [:]
        var warnings: [String] = []
        var seenGuests = Set<UUID>()

        for entry in plan.plan {
            guard let tableUUID = tableIDMap[entry.table] else {
                warnings.append("Unbekannter Tisch \(entry.table) ignoriert")
                continue
            }
            for guestKey in entry.guests {
                guard let guestUUID = guestIDMap[guestKey] else {
                    warnings.append("Unbekannter Gast \(guestKey) ignoriert")
                    continue
                }
                if seenGuests.contains(guestUUID) {
                    warnings.append("Gast \(guestKey) doppelt im Plan")
                    continue
                }
                assignments[guestUUID] = tableUUID
                seenGuests.insert(guestUUID)
            }
            if let reason = entry.reason, !reason.isEmpty {
                rationale[tableUUID] = reason
            }
        }

        let missing = allGuestIDs.subtracting(seenGuests)
        if !missing.isEmpty {
            warnings.append("\(missing.count) Gäste wurden nicht platziert")
        }

        let countsByTable = Dictionary(grouping: assignments, by: \.value).mapValues(\.count)
        for (tableID, capacity) in tableCapacities {
            let count = countsByTable[tableID] ?? 0
            if count > capacity {
                let name = tableNames[tableID] ?? "Tisch"
                warnings.append("\(name) überbelegt: \(count)/\(capacity)")
            }
        }

        for constraint in hardConstraints {
            let placedTables = constraint.guestIDs.compactMap { assignments[$0] }
            let unique = Set(placedTables)
            switch constraint.type {
            case .mustSitTogether:
                if unique.count > 1 {
                    warnings.append("Constraint '\(constraint.reason)' verletzt: sitzen nicht zusammen")
                }
            case .mustNotSitTogether:
                if unique.count == 1 && !placedTables.isEmpty {
                    warnings.append("Constraint '\(constraint.reason)' verletzt: sitzen zusammen")
                }
            }
        }

        return ProposedAssignment(assignments: assignments, rationale: rationale, warnings: warnings)
    }

    /// Convenience: parse using a PlannerContext (adapts @Model → primitives).
    /// Must be called on the main actor since context holds @Model instances.
    static func parsePlan(
        from text: String,
        guestIDMap: [String: UUID],
        tableIDMap: [String: UUID],
        context: PlannerContext
    ) throws -> ProposedAssignment {
        try parseRawResponse(
            text,
            guestIDMap: guestIDMap,
            tableIDMap: tableIDMap,
            allGuestIDs: Set(context.guests.map(\.id)),
            tableCapacities: Dictionary(uniqueKeysWithValues: context.tables.map { ($0.id, $0.capacity) }),
            tableNames: Dictionary(uniqueKeysWithValues: context.tables.map { ($0.id, $0.name) }),
            hardConstraints: context.constraints.map { ($0.type, $0.guestIDs, $0.reason) }
        )
    }

    // MARK: - End-to-end

    /// Ask LM Studio for a seating plan and parse it.
    @MainActor
    static func requestPlan(
        client: LMStudioClient,
        context: PlannerContext
    ) async throws -> ProposedAssignment {
        let (userPrompt, guestMap, tableMap) = buildPrompt(from: context)
        let raw = try await client.prompt(system: systemPrompt, user: userPrompt, temperature: 0.2)
        return try parsePlan(from: raw, guestIDMap: guestMap, tableIDMap: tableMap, context: context)
    }
}
