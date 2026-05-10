import Testing
import Foundation
@testable import Gaesteglueck

@Suite("LLM Seating Planner")
struct LLMSeatingPlannerTests {

    func makeContext() -> (
        context: LLMSeatingPlanner.PlannerContext,
        guestMap: [String: UUID],
        tableMap: [String: UUID],
        guests: [Guest],
        tables: [GuestTable]
    ) {
        let alice = Guest(firstName: "Alice")
        let bob = Guest(firstName: "Bob")
        let carol = Guest(firstName: "Carol")
        let dave = Guest(firstName: "Dave")
        let guests = [alice, bob, carol, dave]

        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let tables = [t1, t2]

        let context = LLMSeatingPlanner.PlannerContext(
            guests: guests,
            tables: tables,
            tags: [],
            constraints: []
        )
        let (_, guestMap, tableMap) = LLMSeatingPlanner.buildPrompt(from: context)
        return (context, guestMap, tableMap, guests, tables)
    }

    @Test("Prompt contains stable G/T identifiers")
    func promptIdentifiers() {
        let ctx = makeContext()
        let (prompt, gMap, tMap) = LLMSeatingPlanner.buildPrompt(from: ctx.context)
        #expect(gMap.count == 4)
        #expect(tMap.count == 2)
        #expect(prompt.contains("G1"))
        #expect(prompt.contains("G4"))
        #expect(prompt.contains("T1"))
        #expect(prompt.contains("T2"))
        #expect(prompt.contains("Alice"))
    }

    @Test("Parses a clean JSON response")
    func parsesCleanJSON() throws {
        let ctx = makeContext()
        let raw = """
            {
              "plan": [
                {"table": "T1", "guests": ["G1", "G2"], "reason": "Freunde"},
                {"table": "T2", "guests": ["G3", "G4"], "reason": "Familie"}
              ]
            }
            """
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        #expect(result.assignments.count == 4)
        #expect(result.assignments[ctx.guests[0].id] == ctx.tables[0].id)
        #expect(result.assignments[ctx.guests[3].id] == ctx.tables[1].id)
        #expect(result.warnings.isEmpty)
        #expect(result.rationale.count == 2)
    }

    @Test("Parses JSON wrapped in markdown fences")
    func parsesMarkdownFenced() throws {
        let ctx = makeContext()
        let raw = """
            Hier ist mein Vorschlag:
            ```json
            {"plan":[{"table":"T1","guests":["G1","G2","G3","G4"],"reason":"Alle zusammen"}]}
            ```
            """
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        #expect(result.assignments.count == 4)
    }

    @Test("Parses JSON with prose around it")
    func parsesProseWrapped() throws {
        let ctx = makeContext()
        let raw = "Ich schlage vor: {\"plan\":[{\"table\":\"T1\",\"guests\":[\"G1\"]},{\"table\":\"T2\",\"guests\":[\"G2\",\"G3\",\"G4\"]}]} Das war's."
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        #expect(result.assignments.count == 4)
    }

    @Test("Warns about missing guests")
    func warnsMissing() throws {
        let ctx = makeContext()
        let raw = "{\"plan\":[{\"table\":\"T1\",\"guests\":[\"G1\",\"G2\"]}]}"
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        #expect(result.assignments.count == 2)
        #expect(result.warnings.contains { $0.contains("nicht platziert") || $0.contains("Nicht platziert") })
    }

    @Test("Warns about unknown guests")
    func warnsUnknown() throws {
        let ctx = makeContext()
        let raw = "{\"plan\":[{\"table\":\"T1\",\"guests\":[\"G1\",\"G99\",\"G2\"]},{\"table\":\"T2\",\"guests\":[\"G3\",\"G4\"]}]}"
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        #expect(result.assignments.count == 4)
        #expect(result.warnings.contains { $0.contains("G99") })
    }

    @Test("Warns about over-capacity")
    func warnsOverCapacity() throws {
        // Create a tiny table.
        let small = GuestTable(name: "Small", shape: .square, width: 60, depth: 60) // cap ≈ 4
        let small2 = GuestTable(name: "Small2", shape: .square, width: 60, depth: 60)
        let guests = (0..<10).map { Guest(firstName: "G\($0)") }
        let context = LLMSeatingPlanner.PlannerContext(guests: guests, tables: [small, small2], tags: [], constraints: [])
        let (_, gMap, tMap) = LLMSeatingPlanner.buildPrompt(from: context)

        // Dump all 10 at one table.
        let all = (1...10).map { "G\($0)" }.map { "\"\($0)\"" }.joined(separator: ",")
        let raw = "{\"plan\":[{\"table\":\"T1\",\"guests\":[\(all)]}]}"

        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: gMap, tableIDMap: tMap, context: context)
        #expect(result.warnings.contains { $0.contains("überbelegt") })
    }

    @Test("Warns when hard constraint violated")
    func warnsConstraintViolation() throws {
        let a = Guest(firstName: "A")
        let b = Guest(firstName: "B")
        let c = Guest(firstName: "C")
        let d = Guest(firstName: "D")
        let t1 = GuestTable(name: "T1", shape: .round, diameter: 180)
        let t2 = GuestTable(name: "T2", shape: .round, diameter: 180)
        let mustTogether = Constraint(type: .mustSitTogether, guestIDs: [a.id, b.id], reason: "Ehepaar")

        let context = LLMSeatingPlanner.PlannerContext(
            guests: [a, b, c, d],
            tables: [t1, t2],
            tags: [],
            constraints: [mustTogether]
        )
        let (_, gMap, tMap) = LLMSeatingPlanner.buildPrompt(from: context)

        // A to T1, B to T2 — violates constraint.
        let raw = "{\"plan\":[{\"table\":\"T1\",\"guests\":[\"G1\",\"G3\"]},{\"table\":\"T2\",\"guests\":[\"G2\",\"G4\"]}]}"
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: gMap, tableIDMap: tMap, context: context)
        #expect(result.warnings.contains { $0.contains("Ehepaar") })
    }

    @Test("Invalid JSON throws")
    func invalidJSONThrows() {
        let ctx = makeContext()
        let raw = "Das ist gar kein JSON."
        #expect(throws: LLMSeatingPlanner.PlannerError.self) {
            _ = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        }
    }

    @Test("Deduplicates guests appearing twice")
    func dedupsDuplicateGuests() throws {
        let ctx = makeContext()
        // G1 is in T1 AND T2 — second occurrence should be ignored with a warning.
        let raw = "{\"plan\":[{\"table\":\"T1\",\"guests\":[\"G1\",\"G2\"]},{\"table\":\"T2\",\"guests\":[\"G1\",\"G3\",\"G4\"]}]}"
        let result = try LLMSeatingPlanner.parsePlan(from: raw, guestIDMap: ctx.guestMap, tableIDMap: ctx.tableMap, context: ctx.context)
        #expect(result.assignments[ctx.guests[0].id] == ctx.tables[0].id) // first wins
        #expect(result.warnings.contains { $0.lowercased().contains("doppel") })
    }
}
