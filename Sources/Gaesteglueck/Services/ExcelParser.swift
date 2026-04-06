import Foundation
import CoreXLSX

enum ExcelParser {
    static func parseRegistrations(_ data: Data) throws -> [RegistrationRow] {
        guard let file = try? XLSXFile(data: data) else {
            throw ImportError.invalidFormat("Kann XLSX nicht lesen")
        }
        guard let sharedStrings = try file.parseSharedStrings() else {
            throw ImportError.invalidFormat("Keine Shared Strings in der XLSX-Datei")
        }

        for workbook in try file.parseWorkbooks() {
            for (_, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: path)
                guard let rows = worksheet.data?.rows, rows.count > 1 else { continue }

                let headerRow = rows[0]
                let headers = headerRow.cells.map { cell -> String in
                    cell.stringValue(sharedStrings) ?? ""
                }.map { $0.lowercased() }

                let familyIdx = headers.firstIndex { $0.contains("familie") || $0.contains("name") }
                let attendIdx = headers.firstIndex { $0.contains("teilnehm") || $0.contains("attend") }
                let countIdx = headers.firstIndex { $0.contains("anzahl") || $0.contains("gesamt") }
                let guestsIdx = headers.firstIndex { $0.contains("gast") || $0.contains("gib") || $0.contains("jeden") }
                let funFactIdx = headers.firstIndex { $0.contains("fun") || $0.contains("fact") }
                let notesIdx = headers.lastIndex { $0.contains("anmerkung") || $0.contains("wünsch") }

                var registrations: [RegistrationRow] = []

                for row in rows.dropFirst() {
                    let cells = row.cells
                    func cellValue(_ idx: Int?) -> String {
                        guard let idx, idx < cells.count else { return "" }
                        return cells[idx].stringValue(sharedStrings) ?? ""
                    }

                    if let aIdx = attendIdx {
                        let attendance = cellValue(aIdx).lowercased()
                        if attendance.contains("nein") || attendance.contains("nicht") { continue }
                    }

                    let familyName = cellValue(familyIdx)
                    guard !familyName.isEmpty else { continue }
                    let countStr = cellValue(countIdx)
                    let guestCount = Int(Double(countStr) ?? 1)

                    registrations.append(RegistrationRow(
                        familyName: familyName,
                        guestCount: guestCount,
                        guestDetails: cellValue(guestsIdx),
                        funFacts: cellValue(funFactIdx),
                        notes: cellValue(notesIdx)
                    ))
                }

                if !registrations.isEmpty { return registrations }
            }
        }
        throw ImportError.emptyFile
    }
}
