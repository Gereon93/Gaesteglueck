import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Onboarding Engine")
struct OnboardingEngineTests {
    @Test("Groups guests into onboarding cards by familyID")
    func groupsByFamily() {
        let fid = UUID()
        let a = Guest(name: "Klaus Müller", side: .neutral, familyID: fid)
        let b = Guest(name: "Erika Müller", side: .neutral, familyID: fid)
        let c = Guest(name: "Solo Gast", side: .neutral)

        let cards = OnboardingEngine.buildCards(from: [a, b, c])
        #expect(cards.count == 2) // one family card + one solo card
        #expect(cards[0].guests.count == 2 || cards[1].guests.count == 2)
    }

    @Test("Filters out already-onboarded guests")
    func filtersOnboarded() {
        let a = Guest(name: "Already Done", side: .bride, groupType: .immediateFamily)
        let b = Guest(name: "Needs Onboarding", side: .neutral)

        let cards = OnboardingEngine.buildCards(from: [a, b], excludeWithGroupType: true)
        #expect(cards.count == 1)
        #expect(cards[0].guests[0].name == "Needs Onboarding")
    }

    @Test("Card display name uses family name for couples")
    func cardDisplayName() {
        let fid = UUID()
        let a = Guest(name: "Klaus Müller", side: .neutral, familyID: fid)
        let b = Guest(name: "Erika Müller", side: .neutral, familyID: fid)

        let cards = OnboardingEngine.buildCards(from: [a, b])
        #expect(cards[0].displayName == "Familie Müller")
    }
}
