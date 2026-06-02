import Foundation

enum SpeechGuestExporter {
    static func generate(guests: [Guest], tags: [Tag], event: Event?) -> Data {
        Data(generateMarkdown(guests: guests, tags: tags, event: event).utf8)
    }

    static func generateMarkdown(guests: [Guest], tags: [Tag], event: Event?) -> String {
        let activeTags = tags.filter(\.isActive)
        let attending = guests.filter(\.countsForSeating)

        var out = "# Gäste – Vorstellung für die Rede\n"
        if let event {
            var title = "Hochzeit"
            let names = [event.partner1Name, event.partner2Name].filter { !$0.isEmpty }
            if !names.isEmpty { title += " von \(names.joined(separator: " & "))" }
            if let date = event.date {
                let fmt = DateFormatter()
                fmt.dateStyle = .long
                fmt.locale = Locale(identifier: "de_DE")
                title += " · \(fmt.string(from: date))"
            }
            out += title + "\n"
        }
        out += "_Kontext: pro Gast Name, Beziehung (Tags), Beruf, FunFact, Hobbys – Material für eine Rede._\n"

        for side in SideOrder.allCases {
            let inSide = attending
                .filter { resolvedSide($0, tags: activeTags) == side.assignment }
                .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
            guard !inSide.isEmpty else { continue }

            out += "\n## \(side.heading(event: event))\n"
            let byBucket = Dictionary(grouping: inSide) { bucket(for: $0, tags: activeTags) }
            for bucket in CategoryBucket.allCases {
                guard let members = byBucket[bucket], !members.isEmpty else { continue }
                out += "\n### \(bucket.heading)\n"
                for guest in members {
                    out += entry(for: guest, tags: activeTags)
                }
            }
        }
        return out
    }

    // MARK: - Seite

    private enum SideOrder: CaseIterable {
        case partner1, partner2, both, unassigned
        var assignment: PartnerAssignment {
            switch self {
            case .partner1: .partner1
            case .partner2: .partner2
            case .both: .both
            case .unassigned: .unassigned
            }
        }
        func heading(event: Event?) -> String {
            switch self {
            case .partner1:
                let n = event?.partner1Name ?? ""
                return "Seite \(n.isEmpty ? "Partner 1" : n)"
            case .partner2:
                let n = event?.partner2Name ?? ""
                return "Seite \(n.isEmpty ? "Partner 2" : n)"
            case .both: return "Beide"
            case .unassigned: return "Ohne Zuordnung"
            }
        }
    }

    private static func resolvedSide(_ guest: Guest, tags: [Tag]) -> PartnerAssignment {
        if guest.partnerAssignment != .unassigned { return guest.partnerAssignment }
        return PartnerSideDeriver.derive(for: guest.id, from: tags) ?? .unassigned
    }

    // MARK: - Kategorie-Bucket

    private enum CategoryBucket: CaseIterable {
        case role, family, friends, work, custom, none
        var heading: String {
            switch self {
            case .role: "Hochzeitsrollen"
            case .family: "Familie"
            case .friends: "Freunde (Schule, Studium, Hobby …)"
            case .work: "Arbeit"
            case .custom: "Sonstige"
            case .none: "Ohne Tag"
            }
        }
    }

    private static func tags(of guest: Guest, in tags: [Tag]) -> [Tag] {
        tags.filter { $0.guestIDs.contains(guest.id) }
    }

    private static func bucket(for guest: Guest, tags: [Tag]) -> CategoryBucket {
        let cats = Set(self.tags(of: guest, in: tags).map(\.category))
        if cats.contains(.role) { return .role }
        if cats.contains(.family) { return .family }
        if cats.contains(.friendGroup) || cats.contains(.activity) { return .friends }
        if cats.contains(.work) { return .work }
        if cats.contains(.custom) { return .custom }
        return .none
    }

    // MARK: - Eintrag

    private static func entry(for guest: Guest, tags: [Tag]) -> String {
        let guestTags = self.tags(of: guest, in: tags)
        let roleNames = guestTags.filter { $0.category == .role }.map(\.name)

        var name = guest.fullName
        if !guest.title.isEmpty { name = "\(guest.title) \(name)" }
        var head = "- **\(name)**"
        if !roleNames.isEmpty { head += " — \(roleNames.joined(separator: ", "))" }
        var lines = [head]

        func sub(_ text: String) { lines.append("  - \(text)") }

        let allTagNames = guestTags.map(\.name)
        if !allTagNames.isEmpty { sub("Woher wir uns kennen: \(allTagNames.joined(separator: ", "))") }

        var facts: [String] = []
        let job = jobText(guest)
        if !job.isEmpty { facts.append(job) }
        if let role = guest.familyRole { facts.append("Familie: \(role.rawValue)") }
        if let age = guest.age { facts.append("Alter: \(age)") }
        if !facts.isEmpty { sub(facts.joined(separator: " · ")) }

        let fun = guest.funFactDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if !fun.isEmpty { sub("FunFact: \(fun)") }

        var extras: [String] = []
        if !guest.hobbies.isEmpty { extras.append("Hobbys: \(guest.hobbies.joined(separator: ", "))") }
        if !guest.languages.isEmpty { extras.append("Sprachen: \(guest.languages.joined(separator: ", "))") }
        if !extras.isEmpty { sub(extras.joined(separator: " · ")) }

        let notes = guest.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty { sub("Notizen: \(notes)") }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func jobText(_ guest: Guest) -> String {
        switch (guest.profession.isEmpty, guest.employer.isEmpty) {
        case (false, false): return "Beruf: \(guest.profession) bei \(guest.employer)"
        case (false, true): return "Beruf: \(guest.profession)"
        case (true, false): return "Beruf: bei \(guest.employer)"
        case (true, true): return ""
        }
    }
}
