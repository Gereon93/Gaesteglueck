import Foundation

enum GroupAnalyzer {
    struct Cluster: Sendable {
        let tagName: String
        let tagCategory: TagCategory
        let guestIDs: [UUID]
        let partnerAssignment: PartnerAssignment?
    }

    struct BridgePerson: Sendable {
        let guestID: UUID
        let guestName: String
        let sharedTags: [String]
    }

    static func detectClusters(guests: [Guest], tags: [Tag]) -> [Cluster] {
        tags.filter { !$0.guestIDs.isEmpty }
            .map { tag in
                Cluster(tagName: tag.name, tagCategory: tag.category, guestIDs: tag.guestIDs, partnerAssignment: tag.partnerAssignment)
            }
            .sorted { $0.guestIDs.count > $1.guestIDs.count }
    }

    static func findBridgePersons(guests: [Guest], tags: [Tag]) -> [BridgePerson] {
        var guestTagMap: [UUID: [String]] = [:]
        for tag in tags {
            for guestID in tag.guestIDs {
                guestTagMap[guestID, default: []].append(tag.name)
            }
        }
        return guestTagMap
            .filter { $0.value.count >= 2 }
            .compactMap { (guestID, tagNames) in
                guard let guest = guests.first(where: { $0.id == guestID }) else { return nil }
                return BridgePerson(guestID: guestID, guestName: guest.fullName, sharedTags: tagNames)
            }
            .sorted { $0.sharedTags.count > $1.sharedTags.count }
    }

    static func buildLLMContext(guests: [Guest], tags: [Tag], constraints: [Constraint], tables: [GuestTable]) -> String {
        var ctx = "# Gästeliste\n\nGesamt: \(guests.count) Gäste\n"
        ctx += "Erwachsene: \(guests.filter { $0.ageCategory == .adult }.count)\n"
        ctx += "Kinder: \(guests.filter { $0.ageCategory != .adult }.count)\n\n"

        ctx += "## Gäste\n\n"
        for guest in guests.sorted(by: { $0.fullName < $1.fullName }) {
            var line = "- \(guest.fullName) (\(guest.partnerAssignment.rawValue))"
            if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
            if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
            if guest.hasIntolerances { line += " ⚠️\(guest.intolerances.joined(separator: ","))" }
            let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }.map(\.name)
            if !guestTags.isEmpty { line += " Tags: \(guestTags.joined(separator: ", "))" }
            ctx += line + "\n"
        }

        let clusters = detectClusters(guests: guests, tags: tags)
        if !clusters.isEmpty {
            ctx += "\n## Gruppen\n\n"
            for cluster in clusters {
                let names = cluster.guestIDs.compactMap { id in guests.first { $0.id == id }?.fullName }
                ctx += "- \(cluster.tagName) (\(cluster.guestIDs.count)): \(names.joined(separator: ", "))\n"
            }
        }

        let bridges = findBridgePersons(guests: guests, tags: tags)
        if !bridges.isEmpty {
            ctx += "\n## Brücken-Personen\n\n"
            for bridge in bridges {
                ctx += "- \(bridge.guestName): verbindet \(bridge.sharedTags.joined(separator: " + "))\n"
            }
        }

        if !constraints.isEmpty {
            ctx += "\n## Einschränkungen\n\n"
            for constraint in constraints {
                let names = constraint.guestIDs.compactMap { id in guests.first { $0.id == id }?.fullName }
                ctx += "- \(constraint.type.rawValue): \(names.joined(separator: ", "))"
                if !constraint.reason.isEmpty { ctx += " (\(constraint.reason))" }
                ctx += "\n"
            }
        }

        if !tables.isEmpty {
            ctx += "\n## Verfügbare Tische\n\n"
            for table in tables.sorted(by: { $0.name < $1.name }) {
                ctx += "- \(table.name): \(table.shape.rawValue), \(table.capacity) Plätze"
                if table.isChildTable { ctx += " [Kindertisch]" }
                ctx += " (\(table.guests.count) zugewiesen)\n"
            }
        }

        return ctx
    }
}
