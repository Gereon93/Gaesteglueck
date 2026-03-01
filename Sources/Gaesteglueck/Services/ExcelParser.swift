import Foundation
import CoreXLSX

enum ExcelParser {
    static func parse(url: URL) throws -> [ImportedFamily] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ImportError.invalidFormat("Kann XLSX-Datei nicht öffnen")
        }
        guard let sharedStrings = try file.parseSharedStrings() else {
            throw ImportError.invalidFormat("Keine Shared Strings gefunden")
        }

        let paths = try file.parseWorksheetPaths()
        guard let firstPath = paths.first else {
            throw ImportError.emptyFile
        }
        let worksheet = try file.parseWorksheet(at: firstPath)

        guard let rows = worksheet.data?.rows, !rows.isEmpty else {
            throw ImportError.emptyFile
        }

        let headerRow = rows[0]
        let headers = headerRow.cells.map { cell -> String in
            cell.stringValue(sharedStrings) ?? ""
        }.map { $0.trimmingCharacters(in: CharacterSet.whitespaces).lowercased() }

        guard let nameIdx = headers.firstIndex(of: "name") else {
            throw ImportError.missingNameColumn
        }
        let sideIdx = headers.firstIndex(where: { ["seite", "side"].contains($0) })
        let dietIdx = headers.firstIndex(where: { ["essen", "ernährung"].contains($0) })
        let allergyIdx = headers.firstIndex(where: { ["unverträglichkeiten", "allergien"].contains($0) })
        let childrenIdx = headers.firstIndex(where: { ["kinder", "children"].contains($0) })

        var families: [ImportedFamily] = []

        for row in rows.dropFirst() {
            let cells = row.cells
            func cellValue(_ idx: Int) -> String {
                guard idx < cells.count else { return "" }
                return cells[idx].stringValue(sharedStrings)?.trimmingCharacters(in: CharacterSet.whitespaces) ?? ""
            }

            let rawName = cellValue(nameIdx)
            guard !rawName.isEmpty else { continue }

            let side: Side = {
                guard let idx = sideIdx else { return .neutral }
                switch cellValue(idx).lowercased() {
                case "braut", "bride": return .bride
                case "bräutigam", "groom": return .groom
                default: return .neutral
                }
            }()

            let dietary: DietaryPreference = {
                guard let idx = dietIdx else { return .meat }
                switch cellValue(idx).lowercased() {
                case "vegan": return .vegan
                case "vegetarisch", "veggie": return .vegetarian
                default: return .meat
                }
            }()

            let allergies = allergyIdx.map { cellValue($0) } ?? ""

            let names = CSVParser.splitCoupleNames(rawName)
            let familyID = names.count > 1 ? UUID() : nil

            var members = names.map { name in
                ImportedGuest(name: name, side: side, dietaryPreference: dietary, allergies: allergies, isChild: false)
            }

            if let cIdx = childrenIdx {
                let childrenRaw = cellValue(cIdx)
                if !childrenRaw.isEmpty {
                    let lastName = CSVParser.extractLastName(from: rawName)
                    let children = CSVParser.parseChildren(childrenRaw, lastName: lastName, side: side)
                    members.append(contentsOf: children)
                }
            }

            families.append(ImportedFamily(
                sharedFamilyID: members.count > 1 ? (familyID ?? UUID()) : nil,
                members: members
            ))
        }

        return families
    }
}
