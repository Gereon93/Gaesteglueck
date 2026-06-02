import Foundation

struct CatererSummary {
    struct DietCount: Equatable { let choice: String; let count: Int }
    struct AgeCount: Equatable { let category: AgeCategory; let count: Int }

    struct Change: Equatable {
        let name: String
        let tableName: String
        let dietaryChoice: String
        let intolerances: [String]
    }

    let dietCounts: [DietCount]
    let totalMeals: Int
    let ageCounts: [AgeCount]
    let totalPersons: Int
    let intolerant: [Guest]
    let changes: [Change]
    let removedDietCounts: [DietCount]

    private static let ageOrder: [AgeCategory] = [.adult, .teenager, .child, .toddler, .baby]

    init(tables: [GuestTable]) {
        let attending = tables.flatMap(\.attendingGuests)

        let diet = Dictionary(grouping: attending, by: \.dietaryChoice).mapValues(\.count)
        dietCounts = diet.sorted { $0.key < $1.key }.map { DietCount(choice: $0.key, count: $0.value) }
        totalMeals = attending.count

        let ages = Dictionary(grouping: attending, by: \.ageCategory).mapValues(\.count)
        ageCounts = Self.ageOrder.compactMap { cat in
            let n = ages[cat] ?? 0
            return n > 0 ? AgeCount(category: cat, count: n) : nil
        }
        totalPersons = attending.count

        intolerant = attending
            .filter(\.hasIntolerances)
            .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }

        let ghosts = tables.flatMap(\.ghostGuests)
        changes = tables.flatMap { table in
            table.ghostGuests.map { g in
                Change(name: g.fullName,
                       tableName: table.name,
                       dietaryChoice: g.dietaryChoice,
                       intolerances: g.intolerances)
            }
        }.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }

        let removed = Dictionary(grouping: ghosts, by: \.dietaryChoice).mapValues(\.count)
        removedDietCounts = removed.sorted { $0.key < $1.key }.map { DietCount(choice: $0.key, count: $0.value) }
    }

    static func changeDetail(_ change: Change) -> String {
        var parts: [String] = []
        let diet = change.dietaryChoice.trimmingCharacters(in: .whitespaces)
        if !diet.isEmpty && diet != "Fleisch" { parts.append(diet) }
        if !change.intolerances.isEmpty {
            parts.append("⚠️ \(change.intolerances.joined(separator: ", "))")
        }
        return parts.joined(separator: " · ")
    }
}
