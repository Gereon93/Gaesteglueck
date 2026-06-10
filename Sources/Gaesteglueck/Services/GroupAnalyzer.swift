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

    struct TagOverlap: Sendable {
        let tagA: String
        let tagB: String
        let sharedCount: Int
    }

    static func computeClusterOverlaps(tags: [Tag], minShared: Int = 2) -> [TagOverlap] {
        let nonEmptyTags = tags.filter(\.isActive).filter { !$0.guestIDs.isEmpty }
        var overlaps: [TagOverlap] = []
        for i in 0..<nonEmptyTags.count {
            for j in (i + 1)..<nonEmptyTags.count {
                let a = nonEmptyTags[i]
                let b = nonEmptyTags[j]
                let shared = Set(a.guestIDs).intersection(Set(b.guestIDs))
                if shared.count >= minShared {
                    overlaps.append(TagOverlap(tagA: a.name, tagB: b.name, sharedCount: shared.count))
                }
            }
        }
        return overlaps.sorted { $0.sharedCount > $1.sharedCount }
    }

    static func detectClusters(guests: [Guest], tags: [Tag]) -> [Cluster] {
        tags.filter(\.isActive).filter { !$0.guestIDs.isEmpty }
            .map { tag in
                Cluster(tagName: tag.name, tagCategory: tag.category, guestIDs: tag.guestIDs, partnerAssignment: tag.partnerAssignment)
            }
            .sorted { $0.guestIDs.count > $1.guestIDs.count }
    }

    static func findBridgePersons(guests: [Guest], tags: [Tag]) -> [BridgePerson] {
        var guestTagMap: [UUID: [String]] = [:]
        for tag in tags.filter(\.isActive) {
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

    private static func familySideSuffix(for side: PartnerAssignment?, event: Event?) -> String {
        guard let side else { return "" }
        switch side {
        case .partner1: return " von \(event?.partnerDisplayName1 ?? "Partner 1")"
        case .partner2: return " von \(event?.partnerDisplayName2 ?? "Partner 2")"
        case .both: return " (beide Seiten)"
        case .unassigned: return ""
        }
    }

    static func buildLLMContext(guests: [Guest], tags: [Tag], constraints: [Constraint], tables: [GuestTable], event: Event? = nil) -> String {
        let tags = tags.filter(\.isActive)
        var ctx = "# Gästeliste\n\nGesamt: \(guests.count) Gäste\n"
        ctx += "Erwachsene: \(guests.filter { $0.ageCategory == .adult }.count)\n"
        ctx += "Kinder: \(guests.filter { $0.ageCategory != .adult }.count)\n\n"

        ctx += "## Gäste\n\n"
        for guest in guests.sorted(by: { $0.fullName < $1.fullName }) {
            var line = "- \(guest.fullName) (\(guest.partnerAssignment.displayName(for: event)))"
            if guest.ageCategory != .adult { line += " [\(guest.ageCategory.rawValue)]" }
            if let role = guest.familyRole {
                line += " 👪\(role.rawValue)\(familySideSuffix(for: guest.familyRolePartner, event: event))"
            }
            if guest.dietaryChoice != "Fleisch" { line += " \(guest.dietaryChoice)" }
            if guest.hasIntolerances { line += " ⚠️\(guest.intolerances.joined(separator: ","))" }
            let guestTags = tags.filter { $0.guestIDs.contains(guest.id) }.map(\.name)
            if !guestTags.isEmpty { line += " Tags: \(guestTags.joined(separator: ", "))" }
            if !guest.hobbies.isEmpty { line += " Hobbys: \(guest.hobbies.joined(separator: ", "))" }
            if !guest.profession.isEmpty { line += " Beruf: \(guest.profession)" }
            if !guest.notes.isEmpty { line += " Notizen: \(guest.notes.prefix(120))" }
            if !guest.funFact.isEmpty { line += " FunFact: \(guest.funFact.prefix(120))" }
            ctx += line + "\n"
        }

        // Familien-Cluster: alle Gäste mit FamilyRole nach Seite + Rolle
        // gruppieren. So sieht die KI auf einen Blick "die Eltern Bob's
        // sind X, Y" oder "Onkel/Tanten Alice: A, B, C".
        let withFamilyRole = guests.filter { $0.familyRole != nil }
        if !withFamilyRole.isEmpty {
            ctx += "\n## Familien-Cluster (aus Familienrollen)\n\n"
            ctx += "Diese Gruppen sind oft die Anker für eigene Familientische — Eltern, Onkel/Tanten, Geschwister mit Anhang gehören typischerweise an einen oder zwei Tische pro Seite zusammen:\n\n"
            let bySide: [PartnerAssignment?: [Guest]] = Dictionary(grouping: withFamilyRole) { $0.familyRolePartner ?? $0.partnerAssignment.optionalSelf }
            for sideKey in [PartnerAssignment.partner1, .partner2, .both, .unassigned] {
                let candidates = bySide[sideKey] ?? bySide[nil] ?? []
                let group = candidates.filter { ($0.familyRolePartner ?? $0.partnerAssignment) == sideKey }
                guard !group.isEmpty else { continue }
                let label = sideKey.displayName(for: event)
                ctx += "### \(label)-Familie\n"
                let byRole = Dictionary(grouping: group) { $0.familyRole! }
                for role in FamilyRole.allCases {
                    if let people = byRole[role], !people.isEmpty {
                        let names = people.map(\.fullName).sorted().joined(separator: ", ")
                        ctx += "- \(role.rawValue): \(names)\n"
                    }
                }
            }
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
            ctx += "\n## Brücken-Personen — wichtig für Cluster-Kombinationen\n\n"
            ctx += "Diese Gäste sind in MEHREREN Tags gleichzeitig. Cluster die sich eine Brücke teilen, sollten am gleichen Tisch sitzen — der Brücken-Gast hält die Verbindung. Sortiert nach Tag-Anzahl absteigend:\n\n"
            for bridge in bridges {
                ctx += "- \(bridge.guestName): \(bridge.sharedTags.joined(separator: " + "))\n"
            }
        }

        let overlaps = computeClusterOverlaps(tags: tags)
        if !overlaps.isEmpty {
            ctx += "\n## Cluster-Überlappungen — Kandidaten für gemeinsame Tische\n\n"
            ctx += "Diese Tag-Paare teilen sich ≥2 Personen. Wenn beide Cluster klein sind (≤7 Personen), sind sie gute Kandidaten für einen gemeinsamen Tisch:\n\n"
            for overlap in overlaps {
                ctx += "- '\(overlap.tagA)' ⇄ '\(overlap.tagB)': \(overlap.sharedCount) gemeinsame Personen\n"
            }
        }

        // Anmeldungs-Gruppen explizit auflisten — sonst übersieht das LLM dass
        // Manuel + Karen + Ruben zusammen kamen (Reisdorfs sind 1 Anmeldung,
        // nicht 1 Einzelgänger + 2 Pärchen). Pflicht-Hinweis: gleiche Tisch-
        // platzierung garantiert.
        let withGroup = guests.filter { $0.registrationGroup != nil }
        let grouped = Dictionary(grouping: withGroup) { $0.registrationGroup! }
        let multiPersonGroups = grouped.values.filter { $0.count >= 2 }
        if !multiPersonGroups.isEmpty {
            ctx += "\n## Anmeldungs-Gruppen (PFLICHT zusammensitzen)\n\n"
            ctx += "Diese Gäste kamen jeweils in einer einzigen CSV-Zeile / Anmeldung. Sie MÜSSEN zwingend am gleichen Tisch sitzen — egal was sonst noch passiert. Nie als Einzelgänger behandeln, immer als Block:\n\n"
            for group in multiPersonGroups.sorted(by: { ($0.first?.fullName ?? "") < ($1.first?.fullName ?? "") }) {
                let names = group.map(\.fullName).sorted().joined(separator: " + ")
                ctx += "- \(names)\n"
            }
        }

        // Manuelle Pairings/Tabus separat — nur die NICHT-Anmeldungs-basierten,
        // damit der LLM die echten User-Wünsche von der Auto-Anmeldungs-Logik
        // unterscheiden kann.
        let pairings = constraints.filter { $0.type == .mustSitTogether && !$0.reason.hasPrefix("Gemeinsame Anmeldung") }
        let taboos = constraints.filter { $0.type == .mustNotSitTogether }
        if !pairings.isEmpty {
            ctx += "\n## Manuelle Pflicht-Verknüpfungen\n\n"
            for c in pairings {
                let names = c.guestIDs.compactMap { id in guests.first { $0.id == id }?.fullName }
                ctx += "- \(names.joined(separator: " + "))"
                if !c.reason.isEmpty { ctx += " — \(c.reason)" }
                ctx += "\n"
            }
        }
        if !taboos.isEmpty {
            ctx += "\n## Tabus (NIEMALS am gleichen Tisch)\n\n"
            for c in taboos {
                let names = c.guestIDs.compactMap { id in guests.first { $0.id == id }?.fullName }
                ctx += "- \(names.joined(separator: " ⚡ "))"
                if !c.reason.isEmpty { ctx += " — \(c.reason)" }
                ctx += "\n"
            }
        }

        if !tables.isEmpty {
            ctx += "\n## Verfügbare Tische\n\n"
            for table in tables.sorted(by: { $0.name < $1.name }) {
                ctx += "- \(table.name): \(table.shape.rawValue), \(table.capacity) Plätze"
                if table.isChildTable { ctx += " [Kindertisch]" }
                ctx += " (\(table.attendingGuests.count) zugewiesen)\n"
            }
        }

        return ctx
    }
}
