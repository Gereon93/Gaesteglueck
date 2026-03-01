import Foundation

struct OnboardingCard: Identifiable {
    let id = UUID()
    let guests: [Guest]

    var displayName: String {
        if guests.count == 1 {
            return guests[0].name
        }
        // Extract shared last name
        let lastNames = guests.map { $0.name.components(separatedBy: " ").last ?? "" }
        if let shared = lastNames.first, lastNames.allSatisfy({ $0 == shared }) {
            return "Familie \(shared)"
        }
        return guests.map(\.name).joined(separator: " & ")
    }

    var isFamily: Bool { guests.count > 1 }
}

enum OnboardingEngine {
    /// Group guests into cards for the onboarding wizard.
    static func buildCards(from guests: [Guest], excludeWithGroupType: Bool = false) -> [OnboardingCard] {
        let filtered = excludeWithGroupType ? guests.filter { $0.groupType == nil } : guests

        var familyGroups: [UUID: [Guest]] = [:]
        var solos: [Guest] = []

        for guest in filtered {
            if let fid = guest.familyID {
                familyGroups[fid, default: []].append(guest)
            } else {
                solos.append(guest)
            }
        }

        var cards: [OnboardingCard] = familyGroups.values.map { OnboardingCard(guests: $0) }
        cards.append(contentsOf: solos.map { OnboardingCard(guests: [$0]) })
        return cards
    }
}
