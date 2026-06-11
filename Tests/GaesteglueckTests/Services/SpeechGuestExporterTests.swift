import Testing
import Foundation
@testable import Gaesteglueck

@Suite("Speech Guest Export")
struct SpeechGuestExporterTests {
    private func tag(_ name: String, _ cat: TagCategory,
                     side: PartnerAssignment? = nil, guests: [Guest]) -> Gaesteglueck.Tag {
        let t = Gaesteglueck.Tag(name: name, category: cat, partnerAssignment: side)
        t.guestIDs = guests.map(\.id)
        return t
    }
    private func event() -> Event {
        Event(name: "Test", partner1Name: "Alice", partner2Name: "Bob")
    }

    @Test("Declined guests are excluded from the speech material")
    func declinedExcluded() {
        let coming = Guest(firstName: "Anna", partnerAssignment: .partner1, rsvpStatus: .confirmed)
        let gone = Guest(firstName: "Berta", partnerAssignment: .partner1, rsvpStatus: .declined)
        let md = SpeechGuestExporter.generateMarkdown(guests: [coming, gone], tags: [], event: event())
        #expect(md.contains("Anna"))
        #expect(!md.contains("Berta"))
    }

    @Test("Guest is placed under their partner side")
    func groupedBySide() {
        let g = Guest(firstName: "Max", partnerAssignment: .partner2)
        let md = SpeechGuestExporter.generateMarkdown(guests: [g], tags: [], event: event())
        #expect(md.contains("## Seite Bob"))
        #expect(!md.contains("## Seite Alice"))
    }

    @Test("Role tag wins the category bucket but all tags are still listed")
    func rolePriorityKeepsAllTags() {
        let g = Guest(firstName: "Max", lastName: "M", partnerAssignment: .partner1)
        let role = tag("Trauzeuge", .role, guests: [g])
        let friends = tag("Studium", .friendGroup, guests: [g])
        let md = SpeechGuestExporter.generateMarkdown(guests: [g], tags: [role, friends], event: event())
        #expect(md.contains("### Hochzeitsrollen"))
        #expect(!md.contains("### Freunde"))
        #expect(md.contains("Trauzeuge"))
        #expect(md.contains("Studium"))
    }

    @Test("Side is derived from a tag when the guest is unassigned")
    func sideDerivedFromTag() {
        let g = Guest(firstName: "Carina", partnerAssignment: .unassigned)
        let t = tag("Alices Mädels", .friendGroup, side: .partner1, guests: [g])
        let md = SpeechGuestExporter.generateMarkdown(guests: [g], tags: [t], event: event())
        #expect(md.contains("## Seite Alice"))
    }

    @Test("Rich fields appear; empty fields are skipped")
    func richContent() {
        let g = Guest(firstName: "Max", lastName: "M", partnerAssignment: .partner1,
                      funFact: "Hat den Mount Everest bestiegen")
        g.profession = "Architekt"
        let md = SpeechGuestExporter.generateMarkdown(guests: [g], tags: [], event: event())
        #expect(md.contains("Hat den Mount Everest bestiegen"))
        #expect(md.contains("Architekt"))
        #expect(!md.contains("Notizen:"))
    }

    @Test("Untagged guest lands under 'Ohne Tag'")
    func untagged() {
        let g = Guest(firstName: "Max", partnerAssignment: .partner1)
        let md = SpeechGuestExporter.generateMarkdown(guests: [g], tags: [], event: event())
        #expect(md.contains("### Ohne Tag"))
    }
}
