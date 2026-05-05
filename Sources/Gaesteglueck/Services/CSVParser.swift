import Foundation

enum CSVParser {
    static func parseRegistrations(_ content: String) throws -> [RegistrationRow] {
        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let headerLine = lines.first else { throw ImportError.emptyFile }

        let delimiter: Character = headerLine.contains("\t") ? "\t" :
                                   headerLine.contains(";") ? ";" : ","
        let headers = headerLine.split(separator: delimiter, omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }

        let familyIdx = headers.firstIndex { $0.contains("familie") || $0.contains("name") }
        let attendIdx = headers.firstIndex { $0.contains("teilnehm") || $0.contains("teilnahm") || $0.contains("attend") }
        let countIdx = headers.firstIndex { $0.contains("anzahl") || $0.contains("gesamt") || $0.contains("count") }
        let guestsIdx = headers.firstIndex { $0.contains("gast") || $0.contains("gib") || $0.contains("jeden") }
        let funFactIdx = headers.firstIndex { $0.contains("fun") || $0.contains("fact") }
        let notesIdx = headers.lastIndex { $0.contains("anmerkung") || $0.contains("wünsch") || $0.contains("notes") }

        var rows: [RegistrationRow] = []

        for line in lines.dropFirst() {
            let fields = line.split(separator: delimiter, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }

            if let aIdx = attendIdx, fields.indices.contains(aIdx) {
                let attendance = fields[aIdx].lowercased()
                if attendance.contains("nein") || attendance.contains("no") || attendance.contains("nicht") {
                    continue
                }
            }

            let familyName = familyIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            guard !familyName.isEmpty else { continue }

            let guestCount = countIdx.flatMap { fields.indices.contains($0) ? max(1, Int(Double(fields[$0]) ?? 1)) : nil } ?? 1
            let guestDetails = guestsIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let funFacts = funFactIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let notes = notesIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""

            rows.append(RegistrationRow(
                familyName: familyName,
                guestCount: guestCount,
                guestDetails: guestDetails,
                funFacts: funFacts,
                notes: notes
            ))
        }

        return rows
    }
}

struct RegistrationRow: Sendable, Equatable {
    let familyName: String
    let guestCount: Int
    let guestDetails: String
    let funFacts: String
    let notes: String
}
