import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Guest Model")
struct GuestTests {
    @Test("Guest initializes with correct defaults")
    func guestDefaults() {
        let guest = Guest(name: "Anna Schmidt", side: .bride)
        #expect(guest.name == "Anna Schmidt")
        #expect(guest.side == .bride)
        #expect(guest.groupType == nil)
        #expect(guest.familyID == nil)
        #expect(guest.rsvpStatus == .pending)
        #expect(guest.dietaryPreference == .meat)
        #expect(guest.allergies.isEmpty)
    }

    @Test("Guest dietary preference")
    func dietaryPreference() {
        let guest = Guest(name: "Lisa Vegan", side: .bride, dietaryPreference: .vegan)
        #expect(guest.dietaryPreference == .vegan)
    }

    @Test("Guest allergies stored correctly")
    func allergies() {
        let guest = Guest(name: "Tom", side: .groom, allergies: "Laktose, Nüsse")
        #expect(guest.allergies == "Laktose, Nüsse")
    }

    @Test("Guest group type")
    func groupType() {
        let guest = Guest(name: "Max", side: .groom, groupType: .universityFriend)
        #expect(guest.groupType == .universityFriend)
    }

    @Test("Guest family role")
    func familyRole() {
        let guest = Guest(name: "Schwester", side: .bride, familyRole: .sister)
        #expect(guest.familyRole == .sister)
    }

    @Test("RSVP status transitions")
    func rsvpStatus() {
        let guest = Guest(name: "Test", side: .neutral)
        #expect(guest.rsvpStatus == .pending)
        guest.rsvpStatus = .confirmed
        #expect(guest.rsvpStatus == .confirmed)
    }

    @Test("Guest isChild flag")
    func isChild() {
        let child = Guest(name: "Klein-Max", side: .bride, isChild: true)
        #expect(child.isChild)
    }
}
