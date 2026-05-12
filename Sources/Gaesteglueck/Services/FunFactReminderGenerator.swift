import Foundation

enum FunFactReminderGenerator {
    static func message(for guest: Guest, event: Event?) -> String {
        let name = guest.firstName.isEmpty ? "du" : guest.firstName
        let partnerName = relevantPartnerName(for: guest, event: event)
        let bullets = exampleBullets(for: guest, partnerName: partnerName)
        let bulletsBlock = bullets.map { "- \($0)" }.joined(separator: "\n")

        return """
        Hallo \(name),

        uns fehlt von dir noch ein FunFact für unser Abendprogramm! Ein FunFact ist eine kleine besondere Geschichte oder Tatsache über dich — etwas, was du gemacht oder erlebt hast. Wir verteilen die FunFacts anonym auf den Tischen, und die Gäste raten dann, zu wem welcher gehört.

        Beispiele, woran wir gerade denken:
        \(bulletsBlock)

        Schick uns einfach kurz einen Satz zurück. Danke dir!
        """
    }

    private static func relevantPartnerName(for guest: Guest, event: Event?) -> String {
        guard let event else { return "uns" }
        let p1 = event.partner1Name.trimmingCharacters(in: .whitespaces)
        let p2 = event.partner2Name.trimmingCharacters(in: .whitespaces)
        switch guest.partnerAssignment {
        case .partner1: return p1.isEmpty ? "uns" : p1
        case .partner2: return p2.isEmpty ? "uns" : p2
        case .both, .unassigned:
            let pair = [p1, p2].filter { !$0.isEmpty }
            return pair.isEmpty ? "uns" : pair.joined(separator: " & ")
        }
    }

    private static func exampleBullets(for guest: Guest, partnerName: String) -> [String] {
        switch guest.familyRole {
        case .mother, .father:
            return [
                "Du hast \(partnerName) als Kind eine bestimmte Sache beigebracht, die heute noch hängengeblieben ist.",
                "Es gibt eine kleine Macke aus der Kindheit, die nur du kennst."
            ]
        case .grandmother, .grandfather:
            return [
                "Eine Sache, die du \(partnerName) früher als Kind beigebracht hast.",
                "Ein Familienrezept oder eine Tradition, an die nur du dich noch erinnerst."
            ]
        case .sister, .brother:
            return [
                "Eine peinliche Geschichte aus eurer Kindheit mit \(partnerName), die nur ihr beide kennt.",
                "Ein gemeinsames Hobby, in dem du \(partnerName) regelmäßig schlägst (oder andersrum)."
            ]
        case .godmother, .godfather:
            return [
                "Ein besonderer Moment mit \(partnerName), den nur du als Pat:in erlebt hast.",
                "Ein Ritual oder Geschenk, das ihr beide jedes Jahr habt."
            ]
        case .aunt, .uncle, .cousin, .cousine, .nephew, .niece:
            return [
                "Eine Familienanekdote mit \(partnerName), die immer wieder erzählt wird.",
                "Eine gemeinsame Aktion oder Reise, an die du gerne zurückdenkst."
            ]
        case .child, .godchild:
            return [
                "Etwas Lustiges oder Tolles, das du mit \(partnerName) zusammen erlebt hast.",
                "Eine Sache, die du am liebsten mit \(partnerName) machst."
            ]
        case .sisterInLaw, .brotherInLaw, .motherInLaw, .fatherInLaw, .other, .none:
            return [
                "Du hast schon viele Reisen oder Ausflüge mit \(partnerName) geplant.",
                "Ihr habt zusammen ein Projekt oder Hobby — etwas, womit du \(partnerName) schon lang verbindest."
            ]
        }
    }
}
