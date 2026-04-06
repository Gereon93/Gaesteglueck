import Foundation

enum FamilyGrouper {
    static func group(_ guests: [Guest]) -> [[Guest]] {
        let withFamily = guests.filter { $0.familyID != nil }
        let grouped = Dictionary(grouping: withFamily, by: { $0.familyID! })
        let solos = guests.filter { $0.familyID == nil }.map { [$0] }
        return Array(grouped.values) + solos
    }
}
