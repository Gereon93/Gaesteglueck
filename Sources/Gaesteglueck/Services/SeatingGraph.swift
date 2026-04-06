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

    init(guests: [Guest], tags: [Tag], constraints: [Constraint]) {
        self.nodes = guests.map(\.id)
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

        for tag in tags {
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

        let families = Dictionary(grouping: guests.filter { $0.familyID != nil }, by: { $0.familyID! })
        for (_, members) in families {
            for i in members.indices {
                for j in (i+1)..<members.count {
                    let exists = edges.contains {
                        ($0.from == members[i].id && $0.to == members[j].id) || ($0.from == members[j].id && $0.to == members[i].id)
                    }
                    if !exists {
                        let isChildPair = members[i].ageCategory != .adult || members[j].ageCategory != .adult
                        edges.append(Edge(from: members[i].id, to: members[j].id, weight: isChildPair ? 100 : 70, isHardConstraint: isChildPair))
                    }
                }
            }
        }

        self.edges = edges
    }

    func edges(for nodeID: UUID) -> [Edge] {
        edges.filter { $0.from == nodeID || $0.to == nodeID }
    }

    func weight(between a: UUID, and b: UUID) -> Double {
        edges.first { ($0.from == a && $0.to == b) || ($0.from == b && $0.to == a) }?.weight ?? 0
    }
}
