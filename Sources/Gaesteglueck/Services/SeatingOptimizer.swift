import Foundation

enum SeatingOptimizer {
    /// Solve the seating assignment problem.
    /// Returns a mapping of guestID -> tableID.
    static func solve(
        guests: [Guest],
        tables: [GuestTable],
        tags: [Tag],
        constraints: [Constraint],
        iterations: Int = 6000
    ) -> [UUID: UUID] {
        let guests = guests.filter(\.countsForSeating)
        guard !guests.isEmpty, !tables.isEmpty else { return [:] }

        let graph = SeatingGraph(guests: guests, tags: tags, constraints: constraints, tables: tables)
        let tableIDs = tables.map(\.id)
        let tableCapacities = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.effectiveCapacity) })
        // Phase 1: Initialize — respect pinned guests, then greedy assign
        var assignment: [UUID: UUID] = [:]
        // CR#1: Track table counts in O(1) instead of filtering assignment.values.
        var tableCounts: [UUID: Int] = Dictionary(uniqueKeysWithValues: tableIDs.map { ($0, 0) })

        // Pinned guests first (immovable)
        let pinnedGuests = guests.filter { $0.isPinned && $0.table != nil }
        for guest in pinnedGuests {
            guard let tid = guest.table?.id else { continue }
            assignment[guest.id] = tid
            tableCounts[tid, default: 0] += 1
        }

        // Group hard-constraint clusters (partners, children without child-table)
        let hardClusters = buildHardClusters(guests: guests, graph: graph)

        // CR#2: Precompute assigned guests per table for affinityScore.
        var guestsByTable: [UUID: [UUID]] = Dictionary(uniqueKeysWithValues: tableIDs.map { ($0, []) })
        for (gid, tid) in assignment { guestsByTable[tid, default: []].append(gid) }

        // Assign clusters greedily, sorted by affinity for the best-fit table.
        for cluster in hardClusters {
            if cluster.allSatisfy({ assignment[$0] != nil }) { continue }

            let clusterSize = cluster.filter { assignment[$0] == nil }.count
            let rankedTables = tableIDs
                .map { tid -> (UUID, Double) in
                    let fit = affinityScore(
                        cluster: cluster, table: tid,
                        tableGuests: guestsByTable[tid] ?? [],
                        graph: graph, capacity: tableCapacities[tid] ?? 0
                    )
                    return (tid, fit)
                }
                .sorted { $0.1 > $1.1 }

            // CR#6: Keep hard clusters atomic — don't split them across tables.
            var placed = false
            for (tid, _) in rankedTables {
                if (tableCounts[tid] ?? 0) + clusterSize <= (tableCapacities[tid] ?? 0) {
                    for guestID in cluster where assignment[guestID] == nil {
                        assignment[guestID] = tid
                        tableCounts[tid, default: 0] += 1
                        guestsByTable[tid, default: []].append(guestID)
                    }
                    placed = true
                    break
                }
            }
            // If no single table fits the entire hard cluster, leave members unassigned
            // rather than splitting a hard constraint group. They'll be placed individually
            // in the "remaining unassigned" pass below (with a soft best-effort).
            if !placed && cluster.count > 1 {
                // Skip — don't break hard-constraint semantics by splitting.
            }
        }

        // Assign remaining unassigned guests (including any from oversized hard clusters).
        for guest in guests where assignment[guest.id] == nil {
            let bestTable = tableIDs
                .filter { (tableCounts[$0] ?? 0) < (tableCapacities[$0] ?? 0) }
                .max { a, b in
                    affinityScore(
                        cluster: [guest.id], table: a,
                        tableGuests: guestsByTable[a] ?? [],
                        graph: graph, capacity: tableCapacities[a] ?? 0
                    ) <
                    affinityScore(
                        cluster: [guest.id], table: b,
                        tableGuests: guestsByTable[b] ?? [],
                        graph: graph, capacity: tableCapacities[b] ?? 0
                    )
                }
            if let tid = bestTable {
                assignment[guest.id] = tid
                tableCounts[tid, default: 0] += 1
                guestsByTable[tid, default: []].append(guest.id)
            }
        }

        // Phase 2: Simulated annealing — swap + move non-pinned guests.
        let pinnedIDs = Set(pinnedGuests.map(\.id))
        var bestAssignment = assignment
        var bestScore = totalScore(assignment: assignment, graph: graph, tableCapacities: tableCapacities)
        var current = assignment
        var currentScore = bestScore
        var currentCounts = tableCounts

        // Temperature calibrated to realistic deltas: partner +150, constraints +100.
        var temperature = 60.0
        let cooling = pow(0.05 / 60.0, 1.0 / Double(max(iterations, 1)))
        let movable = guests.filter { !pinnedIDs.contains($0.id) }

        for _ in 0..<iterations {
            guard let guest = movable.randomElement(),
                  let fromTable = current[guest.id] else { continue }

            // Randomly choose between move and swap.
            let doSwap = Bool.random() && movable.count > 1
            var candidate = current
            var candidateCounts = currentCounts

            if doSwap {
                // Pick another movable guest at a different table.
                guard let other = movable.randomElement(),
                      other.id != guest.id,
                      let toTable = current[other.id],
                      toTable != fromTable else { continue }

                candidate[guest.id] = toTable
                candidate[other.id] = fromTable

                if violatesHard(guest: guest.id, newTable: toTable, assignment: candidate, graph: graph) { continue }
                if violatesHard(guest: other.id, newTable: fromTable, assignment: candidate, graph: graph) { continue }
            } else {
                // Move to a random other table with capacity.
                let otherTables = tableIDs.filter { $0 != fromTable }
                guard let newTable = otherTables.randomElement() else { continue }
                guard (candidateCounts[newTable] ?? 0) < (tableCapacities[newTable] ?? 0) else { continue }

                candidate[guest.id] = newTable
                candidateCounts[fromTable, default: 0] -= 1
                candidateCounts[newTable, default: 0] += 1

                if violatesHard(guest: guest.id, newTable: newTable, assignment: candidate, graph: graph) { continue }
            }

            let candidateScore = totalScore(assignment: candidate, graph: graph, tableCapacities: tableCapacities)
            let delta = candidateScore - currentScore

            if delta > 0 || Double.random(in: 0...1) < exp(delta / max(temperature, 0.01)) {
                current = candidate
                currentScore = candidateScore
                currentCounts = candidateCounts
                if candidateScore > bestScore {
                    bestAssignment = candidate
                    bestScore = candidateScore
                }
            }

            temperature *= cooling
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
    /// CR#2: Takes precomputed tableGuests + capacity instead of scanning assignment/tables.
    private static func affinityScore(
        cluster: [UUID],
        table: UUID,
        tableGuests: [UUID],
        graph: SeatingGraph,
        capacity: Int
    ) -> Double {
        var score: Double = 0

        for guestID in cluster {
            score += graph.tableBonus(guest: guestID, table: table)
            for tableGuestID in tableGuests {
                score += graph.weight(between: guestID, and: tableGuestID)
            }
        }

        let projectedCount = tableGuests.count + cluster.count
        score += sweetSpotBonus(count: projectedCount, capacity: capacity)
        return score
    }

    /// Total score of an assignment.
    private static func totalScore(
        assignment: [UUID: UUID],
        graph: SeatingGraph,
        tableCapacities: [UUID: Int]
    ) -> Double {
        var score: Double = 0
        let byTable = Dictionary(grouping: assignment, by: \.value).mapValues { $0.map(\.key) }

        for (tableID, guestIDs) in byTable {
            for i in guestIDs.indices {
                score += graph.tableBonus(guest: guestIDs[i], table: tableID)
                for j in (i+1)..<guestIDs.count {
                    score += graph.weight(between: guestIDs[i], and: guestIDs[j])
                }
            }
            score += sweetSpotBonus(count: guestIDs.count, capacity: tableCapacities[tableID] ?? 0)
        }
        return score
    }

    private static func sweetSpotBonus(count: Int, capacity: Int) -> Double {
        guard capacity > 0 else { return 0 }
        let ratio = Double(count) / Double(capacity)
        switch ratio {
        case 0.8...1.0: return 15
        case 0.6..<0.8: return 5
        case 0..<0.3: return -20
        default: return 0
        }
    }

    private static func violatesHard(
        guest: UUID,
        newTable: UUID,
        assignment: [UUID: UUID],
        graph: SeatingGraph
    ) -> Bool {
        let hardEdges = graph.edges(for: guest).filter(\.isHardConstraint)
        for edge in hardEdges {
            let otherID = edge.from == guest ? edge.to : edge.from
            guard let otherTable = assignment[otherID] else { continue }
            if edge.weight > 0 && otherTable != newTable { return true }
            if edge.weight < 0 && otherTable == newTable { return true }
        }
        return false
    }
}
