import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Model")
struct GuestTests {
    @Test("Guest initializes with correct defaults")
    func guestDefaults() {
        let guest = Guest(firstName: "Anna", lastName: "Schmidt", partnerAssignment: .partner1)
        #expect(guest.firstName == "Anna")
        #expect(guest.lastName == "Schmidt")
        #expect(guest.fullName == "Anna Schmidt")
        #expect(guest.partnerAssignment == .partner1)
        #expect(guest.familyID == nil)
        #expect(guest.rsvpStatus == .confirmed)
        #expect(guest.dietaryChoice == "Fleisch")
        #expect(guest.intolerances.isEmpty)
    }

    @Test("Guest dietary choice")
    func dietaryChoice() {
        let guest = Guest(firstName: "Lisa", lastName: "Vegan", partnerAssignment: .partner1, dietaryChoice: "Vegan")
        #expect(guest.dietaryChoice == "Vegan")
    }

    @Test("Guest intolerances stored correctly")
    func intolerances() {
        let guest = Guest(firstName: "Tom", partnerAssignment: .partner2, intolerances: ["Laktose", "Nüsse"])
        #expect(guest.intolerances == ["Laktose", "Nüsse"])
        #expect(guest.hasIntolerances)
    }

    @Test("Guest family role")
    func familyRole() {
        let guest = Guest(firstName: "Schwester", partnerAssignment: .partner1, familyRole: .sister)
        #expect(guest.familyRole == .sister)
    }

    @Test("RSVP status transitions")
    func rsvpStatus() {
        let guest = Guest(firstName: "Test")
        #expect(guest.rsvpStatus == .confirmed)
        guest.rsvpStatus = .pending
        #expect(guest.rsvpStatus == .pending)
    }

    @Test("Guest ageCategory")
    func ageCategory() {
        let child = Guest(firstName: "Klein-Max", ageCategory: .child)
        #expect(child.ageCategory == .child)
        #expect(child.ageCategory != .adult)
    }

    @Test("Pinned guest defaults to false and can be toggled")
    func pinnedGuest() {
        let guest = Guest(firstName: "Braut", partnerAssignment: .partner1)
        #expect(!guest.isPinned)
        guest.isPinned = true
        #expect(guest.isPinned)
    }

    @Test("Full name with only first name")
    func fullNameFirstOnly() {
        let guest = Guest(firstName: "Anna")
        #expect(guest.fullName == "Anna")
    }

    @Test("Full name with both names")
    func fullNameBoth() {
        let guest = Guest(firstName: "Anna", lastName: "Schmidt")
        #expect(guest.fullName == "Anna Schmidt")
    }

    @Test("Dietary summary")
    func dietarySummary() {
        let guest = Guest(firstName: "Test", dietaryChoice: "Vegetarisch", intolerances: ["Nüsse"])
        #expect(guest.dietarySummary.contains("Vegetarisch"))
        #expect(guest.dietarySummary.contains("Nüsse"))
    }
}
