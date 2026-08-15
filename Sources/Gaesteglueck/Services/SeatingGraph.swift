import Foundation

struct SeatingGraph: Sendable {
    struct Edge: Sendable {
        let from: UUID
        let to: UUID
        let weight: Double
        let isHardConstraint: Bool
    }

    let nodes: [UUID]
    let edges: [Edge]
    /// Per-guest per-table weight modifiers (e.g. child-table bonus/malus).
    let tableBonuses: [UUID: [UUID: Double]]
    /// Child-table IDs (cached for optimizer lookup).
    let childTableIDs: Set<UUID>

    init(guests: [Guest], tags: [Tag], constraints: [Constraint], tables: [GuestTable] = []) {
        self.nodes = guests.map(\.id)
        self.childTableIDs = Set(tables.filter(\.isChildTable).map(\.id))
        let hasChildTable = !childTableIDs.isEmpty

        let activeTags = tags.filter(\.isActive)
        var edges: [Edge] = []

        for constraint in constraints {
            let ids = constraint.guestIDs
            for i in ids.indices {
                for j in (i+1)..<ids.count {
                    let weight: Double = constraint.type == .mustSitTogether ? 100 : -500
                    edges.append(Edge(from: ids[i], to: ids[j], weight: weight, isHardConstraint: true))
                }
            }
        }

        for tag in activeTags {
            let ids = tag.guestIDs
            let weight: Double = tag.category == .family ? 70 : 40
            for i in ids.indices {
                for j in (i+1)..<ids.count {
                    let exists = edges.contains {
                        ($0.from == ids[i] && $0.to == ids[j]) || ($0.from == ids[j] && $0.to == ids[i])
                    }
                    if !exists {
                        edges.append(Edge(from: ids[i], to: ids[j], weight: weight, isHardConstraint: false))
                    }
                }
            }
        }

        var families: [UUID: [Guest]] = [:]
        for guest in guests {
            guard let familyID = guest.familyID else { continue }
            families[familyID, default: []].append(guest)
        }
        for (_, members) in families {
            // Detect adult partner pair: exactly two adults in a family (no kids bundled in).
            let adults = members.filter { $0.ageCategory == .adult }
            let kids = members.filter { $0.ageCategory != .adult }
            let isPurePartnerPair = adults.count == 2 && kids.isEmpty

            for i in members.indices {
                for j in (i+1)..<members.count {
                    let a = members[i]
                    let b = members[j]
                    let exists = edges.contains {
                        ($0.from == a.id && $0.to == b.id) || ($0.from == b.id && $0.to == a.id)
                    }
                    guard !exists else { continue }

                    let isChildPair = a.ageCategory != .adult || b.ageCategory != .adult
                    if isChildPair {
                        // Child-parent edge: hard unless a child table exists (then child may leave).
                        if hasChildTable {
                            edges.append(Edge(from: a.id, to: b.id, weight: 30, isHardConstraint: false))
                        } else {
                            edges.append(Edge(from: a.id, to: b.id, weight: 100, isHardConstraint: true))
                        }
                    } else if isPurePartnerPair {
                        // Adult-adult partner edge: extra strong so SA keeps couples together.
                        edges.append(Edge(from: a.id, to: b.id, weight: 150, isHardConstraint: false))
                    } else {
                        edges.append(Edge(from: a.id, to: b.id, weight: 70, isHardConstraint: false))
                    }
                }
            }
        }

        // Bridge-person boost: guests with 2+ tags connect groups, so any edge
        // they participate in is worth slightly more (encourages SA to keep them
        // close to their strongest group rather than scattering them).
        var tagCountPerGuest: [UUID: Int] = [:]
        for tag in activeTags {
            for gid in tag.guestIDs {
                tagCountPerGuest[gid, default: 0] += 1
            }
        }
        edges = edges.map { edge in
            guard !edge.isHardConstraint else { return edge }
            let fromBridge = (tagCountPerGuest[edge.from] ?? 0) >= 2
            let toBridge = (tagCountPerGuest[edge.to] ?? 0) >= 2
            if fromBridge || toBridge {
                return Edge(from: edge.from, to: edge.to, weight: edge.weight + 10, isHardConstraint: false)
            }
            return edge
        }

        // Table bonuses: child-table preference/penalty.
        var bonuses: [UUID: [UUID: Double]] = [:]
        if hasChildTable {
            for guest in guests {
                var perTable: [UUID: Double] = [:]
                for table in tables where table.isChildTable {
                    if guest.ageCategory != .adult {
                        perTable[table.id] = 200
                    } else {
                        perTable[table.id] = -200
                    }
                }
                if !perTable.isEmpty { bonuses[guest.id] = perTable }
            }
        }
        self.tableBonuses = bonuses
        self.edges = edges
    }

    func edges(for nodeID: UUID) -> [Edge] {
        edges.filter { $0.from == nodeID || $0.to == nodeID }
    }

    func weight(between a: UUID, and b: UUID) -> Double {
        edges.first { ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a) }?.weight ?? 0
    }

    func tableBonus(guest: UUID, table: UUID) -> Double {
        tableBonuses[guest]?[table] ?? 0
    }
}
