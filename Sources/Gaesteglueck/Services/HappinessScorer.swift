import Foundation

enum HappinessScorer {
    /// Score a single table based on who sits there and their relationships.
    static func scoreTable(_ table: GuestTable, relationships: [Relationship]) -> Double {
        let guestIDs = Set(table.guests.map(\.id))
        guard !guestIDs.isEmpty else { return 0 }

        var score: Double = 0

        // 1. Relationship scores: pairs at this table
        for rel in relationships {
            if guestIDs.contains(rel.personAID) && guestIDs.contains(rel.personBID) {
                score += rel.type.weight * 100
            }
        }

        // 2. Mixed-side bonus: encourages mingling
        let sides = Set(table.guests.map(\.side))
        if sides.count > 1 {
            score += 10
        }

        return score
    }

    /// Sum scores across all tables.
    static func scoreAllTables(_ tables: [GuestTable], relationships: [Relationship]) -> Double {
        tables.reduce(0) { $0 + scoreTable($1, relationships: relationships) }
    }

    /// Find hard constraint violations.
    static func findViolations(tables: [GuestTable], relationships: [Relationship]) -> [Violation] {
        var violations: [Violation] = []

        // Build lookup: guestID -> table
        var guestToTable: [UUID: GuestTable] = [:]
        for table in tables {
            for guest in table.guests {
                guestToTable[guest.id] = table
            }
        }

        for rel in relationships {
            let tableA = guestToTable[rel.personAID]
            let tableB = guestToTable[rel.personBID]

            switch rel.type {
            case .partner:
                if let tA = tableA, let tB = tableB, tA.id != tB.id {
                    violations.append(Violation(
                        type: .partnersSeparated,
                        personAID: rel.personAID,
                        personBID: rel.personBID,
                        description: "Partner sitzen an verschiedenen Tischen"
                    ))
                }
            case .toxic:
                if let tA = tableA, let tB = tableB, tA.id == tB.id {
                    violations.append(Violation(
                        type: .toxicAtSameTable,
                        personAID: rel.personAID,
                        personBID: rel.personBID,
                        description: "Konflikt-Gäste sitzen am selben Tisch"
                    ))
                }
            default:
                break
            }
        }

        return violations
    }
}

struct Violation: Identifiable, Equatable {
    let id = UUID()
    let type: ViolationType
    let personAID: UUID
    let personBID: UUID
    let description: String

    static func == (lhs: Violation, rhs: Violation) -> Bool {
        lhs.type == rhs.type && lhs.personAID == rhs.personAID && lhs.personBID == rhs.personBID
    }
}

enum ViolationType: Equatable {
    case partnersSeparated
    case toxicAtSameTable
    case tableOverCapacity
}
