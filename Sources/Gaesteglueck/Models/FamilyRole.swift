import Foundation

enum FamilyRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case mother = "Mutter"
    case father = "Vater"
    case sister = "Schwester"
    case brother = "Bruder"
    case grandmother = "Oma"
    case grandfather = "Opa"
    case sisterInLaw = "Schwägerin"
    case brotherInLaw = "Schwager"
    case motherInLaw = "Schwiegermutter"
    case fatherInLaw = "Schwiegervater"
    case aunt = "Tante"
    case uncle = "Onkel"
    case cousin = "Cousin"
    case cousine = "Cousine"
    case niece = "Nichte"
    case nephew = "Neffe"
    case child = "Kind"
    case godchild = "Patenkind"
    case godfather = "Patenonkel"
    case godmother = "Patentante"
    case other = "Sonstige"
    var id: String { rawValue }
}
