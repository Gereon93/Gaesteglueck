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
    case other = "Sonstige"
    // ACHTUNG: Patenkind/Patenonkel/Patentante kommen via VersionedSchema-
    // Migration zurück — bis dahin schema-stabil halten damit Bestandsdaten
    // beim Restart nicht wieder weggewipt werden.
    var id: String { rawValue }
}
