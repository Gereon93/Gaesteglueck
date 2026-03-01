import Foundation

enum ImportError: Error, LocalizedError {
    case missingNameColumn
    case emptyFile
    case invalidFormat(String)

    var errorDescription: String? {
        switch self {
        case .missingNameColumn: "Die Datei muss eine 'Name'-Spalte enthalten."
        case .emptyFile: "Die Datei ist leer."
        case .invalidFormat(let detail): "Ungültiges Format: \(detail)"
        }
    }
}

struct ImportedFamily: Sendable {
    let sharedFamilyID: UUID?
    var members: [ImportedGuest]
}

struct ImportedGuest: Sendable {
    let name: String
    let side: Side
    let dietaryPreference: DietaryPreference
    let allergies: String
    let isChild: Bool
}
