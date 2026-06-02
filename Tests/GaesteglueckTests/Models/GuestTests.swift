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

    @Test("countsForSeating is true only for confirmed")
    func countsForSeating() {
        #expect(Guest(firstName: "A", rsvpStatus: .confirmed).countsForSeating)
        #expect(!Guest(firstName: "B", rsvpStatus: .pending).countsForSeating)
        #expect(!Guest(firstName: "C", rsvpStatus: .declined).countsForSeating)
    }

    @Test("isLateCancellation: declined AND still seated")
    func lateCancellationSeated() {
        let table = GuestTable(name: "T", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Tante", rsvpStatus: .declined)
        guest.table = table
        #expect(guest.isLateCancellation)
    }

    @Test("isLateCancellation: declined without a seat is a normal decline")
    func declineWithoutSeatIsNotLate() {
        let guest = Guest(firstName: "Onkel", rsvpStatus: .declined)
        #expect(guest.table == nil)
        #expect(!guest.isLateCancellation)
    }

    @Test("isLateCancellation: confirmed seated guest is not a late cancellation")
    func confirmedSeatedNotLate() {
        let table = GuestTable(name: "T", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Anna", rsvpStatus: .confirmed)
        guest.table = table
        #expect(!guest.isLateCancellation)
    }

    @Test("applyRSVP declining a seated guest frees the seat but keeps the table as a late-cancellation record")
    func decliningFreesSeatKeepsTable() {
        let table = GuestTable(name: "T2", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Tante", rsvpStatus: .confirmed)
        guest.table = table
        guest.seatIndex = 5

        guest.applyRSVP(.declined)

        #expect(guest.seatIndex == nil)
        #expect(guest.table === table)
        #expect(guest.isLateCancellation)
        #expect(!guest.countsForSeating)
    }

    @Test("applyRSVP re-confirming a late cancellation detaches it back to the seating inbox")
    func reconfirmingDetachesFromTable() {
        let table = GuestTable(name: "T2", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Tante", rsvpStatus: .confirmed)
        guest.table = table
        guest.seatIndex = 5
        guest.applyRSVP(.declined)

        guest.applyRSVP(.confirmed)

        #expect(guest.table == nil)
        #expect(guest.seatIndex == nil)
        #expect(!guest.isLateCancellation)
        #expect(guest.awaitsSeating)
    }

    @Test("applyRSVP declining an unseated guest stays a normal decline")
    func decliningUnseatedStaysNormal() {
        let guest = Guest(firstName: "Onkel", rsvpStatus: .pending)

        guest.applyRSVP(.declined)

        #expect(guest.table == nil)
        #expect(!guest.isLateCancellation)
    }

    @Test("applyRSVP declining a never-confirmed seated guest is not a late cancellation")
    func decliningPendingSeatedIsNotLate() {
        let table = GuestTable(name: "T2", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Vielleicht", rsvpStatus: .pending)
        guest.table = table
        guest.seatIndex = 3

        guest.applyRSVP(.declined)

        #expect(guest.table == nil)
        #expect(!guest.isLateCancellation)
    }

    @Test("applyRSVP re-saving a late cancellation keeps its table record")
    func resavingLateCancellationKeepsTable() {
        let table = GuestTable(name: "T2", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Tante", rsvpStatus: .confirmed)
        guest.table = table
        guest.seatIndex = 5
        guest.applyRSVP(.declined)

        guest.applyRSVP(.declined)

        #expect(guest.table === table)
        #expect(guest.isLateCancellation)
    }

    @Test("applyRSVP confirmed→pending releases the seat to stay consistent with countsForSeating")
    func confirmedToPendingReleasesSeat() {
        let table = GuestTable(name: "T2", shape: .round, diameter: 180)
        let guest = Guest(firstName: "Wackel", rsvpStatus: .confirmed)
        guest.table = table
        guest.seatIndex = 2

        guest.applyRSVP(.pending)

        #expect(guest.table == nil)
        #expect(guest.seatIndex == nil)
        #expect(!guest.countsForSeating)
    }

    @Test("Declined guest without a seat does not await seating")
    func declinedDoesNotAwaitSeating() {
        let declined = Guest(firstName: "Tante", rsvpStatus: .declined)
        #expect(declined.table == nil)
        #expect(!declined.awaitsSeating)
    }

    @Test("Confirmed unseated adult awaits seating")
    func confirmedUnseatedAwaitsSeating() {
        let g = Guest(firstName: "Anna", ageCategory: .adult, rsvpStatus: .confirmed)
        #expect(g.awaitsSeating)
    }

    @Test("Seated guest does not await seating")
    func seatedDoesNotAwaitSeating() {
        let table = GuestTable(name: "T", shape: .round, diameter: 180)
        let g = Guest(firstName: "Anna", rsvpStatus: .confirmed)
        g.table = table
        #expect(!g.awaitsSeating)
    }

    @Test("Declined guest never needs a FunFact follow-up")
    func declinedNoFunFactFollowUp() {
        let g = Guest(firstName: "Tante", rsvpStatus: .declined)
        #expect(!g.needsFunFactFollowUp)
    }

    @Test("Confirmed guest with empty FunFact needs follow-up")
    func emptyFunFactNeedsFollowUp() {
        let g = Guest(firstName: "Anna", rsvpStatus: .confirmed)
        #expect(g.needsFunFactFollowUp)
    }

    @Test("Confirmed guest with unapproved FunFact needs follow-up")
    func unapprovedFunFactNeedsFollowUp() {
        let g = Guest(firstName: "Anna", funFact: "Klettert gern", rsvpStatus: .confirmed)
        g.funFactApproved = false
        #expect(g.needsFunFactFollowUp)
    }

    @Test("Confirmed guest with approved FunFact needs no follow-up")
    func approvedFunFactNoFollowUp() {
        let g = Guest(firstName: "Anna", funFact: "Klettert gern", rsvpStatus: .confirmed)
        g.funFactApproved = true
        #expect(!g.needsFunFactFollowUp)
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
