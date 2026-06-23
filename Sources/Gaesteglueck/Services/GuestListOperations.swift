import Foundation

enum FunFactWorklist {
    static func incompleteCount(in guests: [Guest]) -> Int {
        guests.filter(\.hasIncompleteFunFact).count
    }

    static func followUpListByName(in guests: [Guest]) -> [Guest] {
        guests.filter(\.needsFunFactFollowUp).sorted(by: Guest.byName)
    }

    static func checkCandidates(in guests: [Guest]) -> [Guest] {
        guests.filter(\.funFactNeedsReview)
    }

    static func changedProposals(_ proposals: [FunFactNormalizer.Result]) -> [FunFactNormalizer.Result] {
        proposals.filter(\.isRewrite)
    }
}

enum GuestTagSelection {
    static func tagsOnAny(of selection: Set<UUID>, in tags: [Tag]) -> [Tag] {
        tags.filter { $0.includesAny(of: selection) }
    }

    static func members(of tag: Tag, in selection: Set<UUID>) -> [UUID] {
        tag.guestIDs.filter(selection.contains)
    }
}

enum MustSitTogetherLink {
    static func alreadyLinked(_ guestIDs: [UUID], in constraints: [Constraint]) -> Bool {
        constraints.contains { $0.isMustSitLink(for: Set(guestIDs)) }
    }

    static func reason(for guestIDs: [UUID], in guests: [Guest]) -> String {
        let names = guestIDs
            .compactMap { id in guests.first { $0.id == id }?.firstName }
            .sorted()
            .joined(separator: " + ")
        return names.isEmpty ? "Manuell verknüpft" : "Müssen zusammen sitzen: \(names)"
    }
}
