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
    let firstName: String
    let lastName: String
    let dietaryChoice: String
    let intolerances: [String]
    let ageCategory: AgeCategory
    let funFact: String
    let notes: String
    var tagNames: [String] = []
}
