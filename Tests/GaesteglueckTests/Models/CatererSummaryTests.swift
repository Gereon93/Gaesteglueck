import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Caterer Summary")
struct CatererSummaryTests {
    private func seat(_ guest: Guest, at table: GuestTable) {
        guest.table = table
        table.guests.append(guest)
    }

    @Test("Declined ghost is excluded from diet counts and totals")
    func ghostExcludedFromCounts() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let anna = Guest(firstName: "Anna", dietaryChoice: "Vegetarisch", rsvpStatus: .confirmed)
        let tante = Guest(firstName: "Tante", dietaryChoice: "Vegetarisch", rsvpStatus: .declined)
        seat(anna, at: table)
        seat(tante, at: table)

        let summary = CatererSummary(tables: [table])
        #expect(summary.totalMeals == 1)
        #expect(summary.totalPersons == 1)
        #expect(summary.dietCounts == [.init(choice: "Vegetarisch", count: 1)])
    }

    @Test("Late cancellation appears in the changes list with diet + intolerance")
    func lateCancellationInChanges() {
        let table = GuestTable(name: "Tisch 3", shape: .round, diameter: 180)
        let tante = Guest(firstName: "Tante", lastName: "Hilde",
                          dietaryChoice: "Vegetarisch",
                          intolerances: ["Nüsse"],
                          rsvpStatus: .declined)
        seat(tante, at: table)

        let summary = CatererSummary(tables: [table])
        #expect(summary.changes == [
            .init(name: "Tante Hilde", tableName: "Tisch 3",
                  dietaryChoice: "Vegetarisch", intolerances: ["Nüsse"])
        ])
    }

    @Test("Ghost is not counted among attending intolerances")
    func ghostNotInIntolerantList() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let tante = Guest(firstName: "Tante", intolerances: ["Nüsse"], rsvpStatus: .declined)
        seat(tante, at: table)

        let summary = CatererSummary(tables: [table])
        #expect(summary.intolerant.isEmpty)
    }

    @Test("Removed diet counts aggregate the late cancellations per menu")
    func removedDietCounts() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let v1 = Guest(firstName: "A", dietaryChoice: "Vegetarisch", rsvpStatus: .declined)
        let v2 = Guest(firstName: "B", dietaryChoice: "Vegetarisch", rsvpStatus: .declined)
        let m1 = Guest(firstName: "C", dietaryChoice: "Fleisch", rsvpStatus: .declined)
        seat(v1, at: table); seat(v2, at: table); seat(m1, at: table)

        let summary = CatererSummary(tables: [table])
        #expect(summary.removedDietCounts.contains(.init(choice: "Vegetarisch", count: 2)))
        #expect(summary.removedDietCounts.contains(.init(choice: "Fleisch", count: 1)))
    }

    @Test("Pending (not confirmed) guest is neither counted nor a ghost")
    func pendingNotCountedNotGhost() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        let pending = Guest(firstName: "Unklar", dietaryChoice: "Vegan", rsvpStatus: .pending)
        seat(pending, at: table)

        let summary = CatererSummary(tables: [table])
        #expect(summary.totalMeals == 0)
        #expect(summary.changes.isEmpty)
        #expect(summary.removedDietCounts.isEmpty)
    }

    @Test("No late cancellations means an empty changes list")
    func noChangesWhenAllConfirmed() {
        let table = GuestTable(name: "Tisch 1", shape: .round, diameter: 180)
        seat(Guest(firstName: "Anna", rsvpStatus: .confirmed), at: table)
        let summary = CatererSummary(tables: [table])
        #expect(summary.changes.isEmpty)
    }

    @Test("changeDetail has no leading separator when the diet is empty")
    func changeDetailNoLeadingSeparator() {
        let change = CatererSummary.Change(
            name: "Tante",
            tableName: "T2",
            dietaryChoice: "",
            intolerances: ["Nüsse"]
        )
        #expect(CatererSummary.changeDetail(change) == "⚠️ Nüsse")
    }
}
