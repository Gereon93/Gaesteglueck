import Foundation

enum HappinessScorer {
    static func scoreTable(_ table: GuestTable, tags: [Tag], constraints: [Constraint]) -> Double {
        let guests = table.guests
        let guestIDs = Set(guests.map(\.id))
        guard !guestIDs.isEmpty else { return 0 }
        var score: Double = 0

        // Tag cohesion: guests sharing a tag at the same table.
        for tag in tags {
            let atTable = tag.guestIDs.filter { guestIDs.contains($0) }
            if atTable.count >= 2 {
                let weight: Double = tag.category == .family ? 70 : 40
                score += Double(atTable.count) * weight
            }
        }

        // Partner mix: both sides represented → +10.
        let assignments = Set(guests.map(\.partnerAssignment))
        if assignments.count > 1 { score += 10 }

        // Near-full bonus (80 %+ fill) — no malus for small honor tables.
        if table.capacity > 0 {
            let ratio = Double(guests.count) / Double(table.capacity)
            if ratio >= 0.8 && ratio <= 1.0 { score += 15 }
            else if ratio >= 0.6 && ratio <= 1.0 { score += 5 }
        }

        // Bridge persons: guest at this table with 2+ tags connects groups → +15 each.
        let bridgeCount = guests.filter { guest in
            tags.filter { $0.guestIDs.contains(guest.id) }.count >= 2
        }.count
        score += Double(bridgeCount) * 15

        // Generation mix: reward at least one adult at a table with children.
        let hasChild = guests.contains { $0.ageCategory != .adult }
        let hasAdult = guests.contains { $0.ageCategory == .adult }
        if hasChild && hasAdult && !table.isChildTable { score += 20 }

        // Child table bonus: mostly children at child table.
        if table.isChildTable {
            let childFraction = Double(guests.filter { $0.ageCategory != .adult }.count) / Double(max(guests.count, 1))
            score += childFraction * 30
        }

        // Dietary cluster: if vegan/vegetarian guests cluster at one table, kitchen wins.
        let dietGroups = Dictionary(grouping: guests, by: \.dietaryChoice)
        for (diet, members) in dietGroups where diet != "Fleisch" && members.count >= 2 {
            score += Double(members.count) * 3
        }

        return score
    }

    /// Grade (0-100) for UI display. Derived from the raw per-table score.
    static func gradeTable(_ table: GuestTable, tags: [Tag], constraints: [Constraint]) -> Double {
        let raw = scoreTable(table, tags: tags, constraints: constraints)
        // Cap at 200 for display: anything above is "perfect".
        return min(100, max(0, raw / 2))
    }

    static func scoreAllTables(_ tables: [GuestTable], tags: [Tag], constraints: [Constraint]) -> Double {
        tables.reduce(0) { $0 + scoreTable($1, tags: tags, constraints: constraints) }
    }

    static func findViolations(tables: [GuestTable], constraints: [Constraint]) -> [Violation] {
        var violations: [Violation] = []
        var guestToTable: [UUID: UUID] = [:]
        for table in tables {
            for guest in table.guests { guestToTable[guest.id] = table.id }
        }

        for constraint in constraints {
            let ids = constraint.guestIDs
            guard ids.count >= 2 else { continue }
            let tables = ids.compactMap { guestToTable[$0] }
            let unique = Set(tables)

            switch constraint.type {
            case .mustSitTogether:
                if unique.count > 1 {
                    violations.append(Violation(type: .constraintViolated, guestIDs: ids, description: "Müssen zusammen sitzen: \(constraint.reason)"))
                }
            case .mustNotSitTogether:
                if unique.count == 1 && !tables.isEmpty {
                    violations.append(Violation(type: .constraintViolated, guestIDs: ids, description: "Dürfen nicht zusammen sitzen: \(constraint.reason)"))
                }
            }
        }
        // Over-capacity check
        for table in tables {
            if table.guests.count > table.capacity {
                violations.append(Violation(
                    type: .tableOverCapacity,
                    guestIDs: table.guests.map(\.id),
                    description: "\(table.name) ist überbelegt (\(table.guests.count)/\(table.capacity))"
                ))
            }
        }

        return violations
    }

}

struct Violation: Identifiable, Equatable {
    let id = UUID()
    let type: ViolationType
    let guestIDs: [UUID]
    let description: String

    static func == (lhs: Violation, rhs: Violation) -> Bool {
        lhs.type == rhs.type && lhs.guestIDs == rhs.guestIDs
    }
}

enum ViolationType: Equatable {
    case constraintViolated
    case tableOverCapacity
}
