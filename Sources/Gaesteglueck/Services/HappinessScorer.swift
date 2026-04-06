import Foundation

enum HappinessScorer {
    static func scoreTable(_ table: GuestTable, tags: [Tag], constraints: [Constraint]) -> Double {
        let guestIDs = Set(table.guests.map(\.id))
        guard !guestIDs.isEmpty else { return 0 }
        var score: Double = 0

        for tag in tags {
            let atTable = tag.guestIDs.filter { guestIDs.contains($0) }
            if atTable.count >= 2 {
                let weight: Double = tag.category == .family ? 70 : 40
                score += Double(atTable.count) * weight
            }
        }

        let assignments = Set(table.guests.map(\.partnerAssignment))
        if assignments.count > 1 { score += 10 }

        return score
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
