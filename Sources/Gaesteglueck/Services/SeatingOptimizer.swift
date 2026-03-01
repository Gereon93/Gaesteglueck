import Foundation

enum SeatingOptimizer {
    /// Solve the seating assignment problem.
    /// Returns a mapping of guestID -> tableID.
    static func solve(
        guests: [Guest],
        tables: [GuestTable],
        relationships: [Relationship],
        iterations: Int = 5000
    ) -> [UUID: UUID] {
        guard !guests.isEmpty, !tables.isEmpty else { return [:] }

        let graph = SeatingGraph(guests: guests, relationships: relationships)
        let tableIDs = tables.map(\.id)
        let tableCapacities = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.capacity) })

        // Phase 1: Initialize — respect pinned guests, then greedy assign
        var assignment: [UUID: UUID] = [:]

        // Pinned guests first (immovable)
        let pinnedGuests = guests.filter { $0.isPinned && $0.table != nil }
        for guest in pinnedGuests {
            assignment[guest.id] = guest.table!.id
        }

        // Group hard-constraint clusters (partners, children)
        let hardClusters = buildHardClusters(guests: guests, graph: graph)

        // Assign clusters greedily to tables with most affinity
        for cluster in hardClusters {
            if cluster.allSatisfy({ assignment[$0] != nil }) { continue }

            let bestTable = tableIDs.max { a, b in
                affinityScore(cluster: cluster, table: a, assignment: assignment, graph: graph) <
                affinityScore(cluster: cluster, table: b, assignment: assignment, graph: graph)
            } ?? tableIDs[0]

            // Check capacity
            let currentCount = assignment.values.filter { $0 == bestTable }.count
            let clusterSize = cluster.filter { assignment[$0] == nil }.count
            if currentCount + clusterSize <= (tableCapacities[bestTable] ?? 0) {
                for guestID in cluster where assignment[guestID] == nil {
                    assignment[guestID] = bestTable
                }
            } else {
                // Find table with space
                for tid in tableIDs {
                    let count = assignment.values.filter { $0 == tid }.count
                    if count + clusterSize <= (tableCapacities[tid] ?? 0) {
                        for guestID in cluster where assignment[guestID] == nil {
                            assignment[guestID] = tid
                        }
                        break
                    }
                }
            }
        }

        // Assign remaining unassigned guests
        for guest in guests where assignment[guest.id] == nil {
            let bestTable = tableIDs
                .filter { tid in
                    assignment.values.filter { $0 == tid }.count < (tableCapacities[tid] ?? 0)
                }
                .max { a, b in
                    affinityScore(cluster: [guest.id], table: a, assignment: assignment, graph: graph) <
                    affinityScore(cluster: [guest.id], table: b, assignment: assignment, graph: graph)
                }
            if let tid = bestTable {
                assignment[guest.id] = tid
            }
        }

        // Phase 2: Simulated annealing — swap non-pinned guests to improve score
        let pinnedIDs = Set(pinnedGuests.map(\.id))
        var bestAssignment = assignment
        var bestScore = totalScore(assignment: assignment, graph: graph)
        var temperature = 1.0

        for _ in 0..<iterations {
            var candidate = bestAssignment

            // Pick a random non-pinned guest and swap to a different table
            let movableGuests = guests.filter { !pinnedIDs.contains($0.id) }
            guard let guest = movableGuests.randomElement(),
                  let currentTable = candidate[guest.id] else { continue }

            let otherTables = tableIDs.filter { $0 != currentTable }
            guard let newTable = otherTables.randomElement() else { continue }

            // Check capacity
            let newTableCount = candidate.values.filter { $0 == newTable }.count
            guard newTableCount < (tableCapacities[newTable] ?? 0) else { continue }

            // Check hard constraints
            let hardEdges = graph.edges(for: guest.id).filter(\.isHardConstraint)
            let wouldViolate = hardEdges.contains { edge in
                let otherID = edge.from == guest.id ? edge.to : edge.from
                guard let otherTable = candidate[otherID] else { return false }
                if edge.weight > 0 {
                    return otherTable != newTable // Positive hard constraint: must be same table
                } else {
                    return otherTable == newTable // Negative hard constraint: must be different table
                }
            }
            guard !wouldViolate else { continue }

            candidate[guest.id] = newTable
            let candidateScore = totalScore(assignment: candidate, graph: graph)

            // Accept if better, or probabilistically if worse (annealing)
            let delta = candidateScore - bestScore
            if delta > 0 || Double.random(in: 0...1) < exp(delta / temperature) {
                bestAssignment = candidate
                bestScore = candidateScore
            }

            temperature *= 0.999
        }

        return bestAssignment
    }

    // MARK: - Private

    /// Build clusters of guests connected by hard constraints.
    private static func buildHardClusters(guests: [Guest], graph: SeatingGraph) -> [[UUID]] {
        var visited: Set<UUID> = []
        var clusters: [[UUID]] = []

        for guest in guests {
            guard !visited.contains(guest.id) else { continue }
            var cluster: [UUID] = []
            var queue: [UUID] = [guest.id]

            while let current = queue.popLast() {
                guard !visited.contains(current) else { continue }
                visited.insert(current)
                cluster.append(current)

                let hardNeighbors = graph.edges(for: current)
                    .filter { $0.isHardConstraint && $0.weight > 0 }
                    .map { $0.from == current ? $0.to : $0.from }
                queue.append(contentsOf: hardNeighbors)
            }

            clusters.append(cluster)
        }

        // Sort: largest clusters first (they're hardest to place)
        return clusters.sorted { $0.count > $1.count }
    }

    /// Score how well a cluster fits at a specific table given current assignment.
    private static func affinityScore(cluster: [UUID], table: UUID, assignment: [UUID: UUID], graph: SeatingGraph) -> Double {
        var score: Double = 0
        let tableGuests = assignment.filter { $0.value == table }.map(\.key)

        for guestID in cluster {
            for tableGuestID in tableGuests {
                score += graph.weight(between: guestID, and: tableGuestID)
            }
        }
        return score
    }

    /// Total score of an assignment.
    private static func totalScore(assignment: [UUID: UUID], graph: SeatingGraph) -> Double {
        var score: Double = 0
        let byTable = Dictionary(grouping: assignment, by: \.value).mapValues { $0.map(\.key) }

        for (_, guestIDs) in byTable {
            for i in guestIDs.indices {
                for j in (i+1)..<guestIDs.count {
                    score += graph.weight(between: guestIDs[i], and: guestIDs[j])
                }
            }
        }
        return score
    }
}
