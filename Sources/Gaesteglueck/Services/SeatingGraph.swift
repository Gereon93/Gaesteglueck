import Foundation

/// Represents the social graph as an adjacency-weighted structure.
/// Guests are nodes, relationships and group memberships are edges.
struct SeatingGraph {
    struct Edge {
        let from: UUID
        let to: UUID
        let weight: Double // positive = attract, negative = repel
        let isHardConstraint: Bool
    }

    let nodes: [UUID]
    let edges: [Edge]

    /// Build graph from guests and relationships.
    init(guests: [Guest], relationships: [Relationship]) {
        self.nodes = guests.map(\.id)
        var edges: [Edge] = []

        // 1. Explicit relationships
        for rel in relationships {
            edges.append(Edge(
                from: rel.personAID,
                to: rel.personBID,
                weight: rel.type.weight * 100,
                isHardConstraint: rel.type.isHardConstraint
            ))
        }

        // 2. Family bonds (implicit edges from shared familyID)
        let families = Dictionary(grouping: guests.filter { $0.familyID != nil }, by: { $0.familyID! })
        for (_, members) in families {
            for i in members.indices {
                for j in (i+1)..<members.count {
                    let alreadyHasEdge = edges.contains { e in
                        (e.from == members[i].id && e.to == members[j].id) ||
                        (e.from == members[j].id && e.to == members[i].id)
                    }
                    if !alreadyHasEdge {
                        // Children with parents = hard constraint
                        let isChildPair = members[i].isChild || members[j].isChild
                        edges.append(Edge(
                            from: members[i].id,
                            to: members[j].id,
                            weight: isChildPair ? 100 : 70,
                            isHardConstraint: isChildPair
                        ))
                    }
                }
            }
        }

        // 3. Group cohesion (implicit edges from shared groupType)
        let groups = Dictionary(grouping: guests.filter { $0.groupType != nil }, by: { g in
            "\(g.groupType!.rawValue)_\(g.customGroupName ?? "")"
        })
        for (_, members) in groups {
            let weight = members.first?.groupType?.cohesionWeight ?? 0.3
            for i in members.indices {
                for j in (i+1)..<members.count {
                    let alreadyHasEdge = edges.contains { e in
                        (e.from == members[i].id && e.to == members[j].id) ||
                        (e.from == members[j].id && e.to == members[i].id)
                    }
                    if !alreadyHasEdge {
                        edges.append(Edge(
                            from: members[i].id,
                            to: members[j].id,
                            weight: weight * 40,
                            isHardConstraint: false
                        ))
                    }
                }
            }
        }

        self.edges = edges
    }

    /// Get all edges involving a specific node.
    func edges(for nodeID: UUID) -> [Edge] {
        edges.filter { $0.from == nodeID || $0.to == nodeID }
    }

    /// Get the attraction weight between two nodes. 0 if no edge.
    func weight(between a: UUID, and b: UUID) -> Double {
        edges.first { ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a) }?.weight ?? 0
    }
}
