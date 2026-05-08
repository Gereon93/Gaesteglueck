import Foundation

enum CSVParser {
    static func parseRegistrations(_ content: String) throws -> [RegistrationRow] {
        // Erst nach RFC 4180 zerlegen — das respektiert "..."-quotete Zellen die
        // selbst Newlines, Kommas oder Doppel-Quotes enthalten dürfen. Vorher
        // hat das simple split(\n) Multi-Line-Zellen wie "Nils Brandt, Fleisch\n
        // Martha Dallmann, Fleisch" mitten durchgeschnitten.
        let allRecords = parseRFC4180(content)
        guard !allRecords.isEmpty, let header = allRecords.first else { throw ImportError.emptyFile }

        let delimiterUsed = detectDelimiter(in: content)
        _ = delimiterUsed // bereits in parseRFC4180 berücksichtigt

        let headers = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        let emailIdx = headers.firstIndex { $0.contains("e-mail") || $0.contains("email") || $0.contains("mail") }
        let phoneIdx = headers.firstIndex { $0.contains("telefon") || $0.contains("phone") || $0.contains("nummer") }
        let timestampIdx = headers.firstIndex { $0.contains("zeitstempel") || $0.contains("timestamp") || $0.contains("zeit") }
        let familyIdx = headers.firstIndex { $0.contains("familie") || $0.contains("name") }
        let attendIdx = headers.firstIndex { $0.contains("teilnehm") || $0.contains("teilnahm") || $0.contains("attend") }
        let countIdx = headers.firstIndex { $0.contains("anzahl") || $0.contains("gesamt") || $0.contains("count") }
        // Achtung: das Anzahl-Feld heißt z.B. "Gesamtzahl der Gäste" und enthält
        // damit auch "gäst". Der Count wird oben schon erkannt; deswegen hier
        // spezifisch auf das Details-Feld matchen — Indikatoren die NICHT
        // gleichzeitig auch im Count- oder FunFact-Header stehen.
        let guestsIdx = headers.firstIndex { h in
            // Schließe das schon erkannte Count- und FunFact-Feld aus
            if let cIdx = countIdx, headers[cIdx] == h { return false }
            return h.contains("informationen")
                || h.contains("unverträglich")
                || h.contains("vegetarisch")
                || h.contains("vegan")
                || h.contains("details")
                || (h.contains("gib") && h.contains("gast"))   // "Bitte gib für jeden Gast …"
                || (h.contains("jeden gast") && !h.contains("fun"))
        }
        let funFactIdx = headers.firstIndex { $0.contains("fun") || $0.contains("fact") }
        let notesIdx = headers.lastIndex { $0.contains("anmerkung") || $0.contains("wünsch") || $0.contains("notes") }

        var rows: [RegistrationRow] = []
        var rowIndex = 0

        for record in allRecords.dropFirst() {
            rowIndex += 1
            let fields = record.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            // Leere Zeilen überspringen
            if fields.allSatisfy(\.isEmpty) { continue }

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
            let email = emailIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let phone = phoneIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""
            let timestamp = timestampIdx.flatMap { fields.indices.contains($0) ? fields[$0] : nil } ?? ""

            let sourceID = makeSourceID(email: email, phone: phone, timestamp: timestamp, familyName: familyName, rowIndex: rowIndex)

            // Komplette Roh-Zeile mit Original-Header weiterreichen.
            // header[i] ist schon kleingeschrieben — wir reichen aber das Original
            // weiter, damit der LLM-Prompt lesbar bleibt.
            let originalHeaders = allRecords.first?.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? []
            var rawFields: [CSVField] = []
            for (i, value) in fields.enumerated() {
                guard originalHeaders.indices.contains(i), !originalHeaders[i].isEmpty else { continue }
                rawFields.append(CSVField(header: originalHeaders[i], value: value))
            }

            rows.append(RegistrationRow(
                familyName: familyName,
                guestCount: guestCount,
                guestDetails: guestDetails,
                funFacts: funFacts,
                notes: notes,
                sourceEmail: email,
                sourcePhone: phone,
                sourceID: sourceID,
                rawFields: rawFields
            ))
        }

        return rows
    }

    /// RFC-4180-konformer CSV-Tokenizer. Erkennt automatisch das Trennzeichen
    /// (Tab > Semikolon > Komma) und respektiert "..."-quotete Zellen mit
    /// internen Newlines, Trennzeichen und doppelten Anführungszeichen ("").
    static func parseRFC4180(_ input: String) -> [[String]] {
        let delimiter = detectDelimiter(in: input)
        var records: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var iterator = input.unicodeScalars.makeIterator()
        var pending: Unicode.Scalar? = nil

        func nextScalar() -> Unicode.Scalar? {
            if let p = pending {
                pending = nil
                return p
            }
            return iterator.next()
        }

        while let scalar = nextScalar() {
            let char = Character(scalar)
            if insideQuotes {
                if scalar == "\"" {
                    // Doppel-Quote innerhalb von Quotes = Literal-Quote
                    if let next = iterator.next() {
                        if next == "\"" {
                            currentField.append("\"")
                        } else {
                            insideQuotes = false
                            pending = next
                        }
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if scalar == "\"" {
                    insideQuotes = true
                } else if char == delimiter {
                    currentRow.append(currentField)
                    currentField = ""
                } else if scalar == "\n" || scalar == "\r" {
                    // Wenn \r gefolgt von \n: das \n überspringen
                    if scalar == "\r" {
                        if let next = iterator.next() {
                            if next != "\n" { pending = next }
                        }
                    }
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.isEmpty || !records.isEmpty {
                        records.append(currentRow)
                    }
                    currentRow = []
                } else {
                    currentField.append(char)
                }
            }
        }

        // Letzte Zelle/Zeile flush'en
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            records.append(currentRow)
        }

        return records
    }

    private static func detectDelimiter(in input: String) -> Character {
        // Erste Zeile lesen (bis zum ersten Newline der NICHT in Quotes steckt)
        var insideQuotes = false
        var firstLine = ""
        for scalar in input.unicodeScalars {
            if scalar == "\"" {
                insideQuotes.toggle()
                continue
            }
            if (scalar == "\n" || scalar == "\r") && !insideQuotes {
                break
            }
            firstLine.append(Character(scalar))
        }

        if firstLine.contains("\t") { return "\t" }
        if firstLine.contains(";") { return ";" }
        return ","
    }

    private static func makeSourceID(email: String, phone: String, timestamp: String, familyName: String, rowIndex: Int) -> String {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedEmail.isEmpty { return "email:" + trimmedEmail }
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "/", with: "")
        if !trimmedPhone.isEmpty { return "phone:" + trimmedPhone }
        let trimmedTime = timestamp.trimmingCharacters(in: .whitespaces)
        if !trimmedTime.isEmpty {
            return "ts:" + trimmedTime + "#" + familyName.trimmingCharacters(in: .whitespaces)
        }
        return "row:\(rowIndex)#" + familyName.trimmingCharacters(in: .whitespaces)
    }
}

struct CSVField: Sendable, Equatable, Hashable {
    let header: String
    let value: String
}

struct RegistrationRow: Sendable, Equatable {
    let familyName: String
    let guestCount: Int
    let guestDetails: String
    let funFacts: String
    let notes: String
    var sourceEmail: String = ""
    var sourcePhone: String = ""
    var sourceID: String = ""
    /// Sämtliche Header→Wert-Paare aus der Original-Zeile, in der Reihenfolge
    /// der CSV-Spalten. Wird an den LLM weitergereicht, damit Heimatort,
    /// Liedwünsche, etc. nicht verloren gehen.
    var rawFields: [CSVField] = []
}
