import Foundation

enum LLMGuestParser {
    struct ParsedGuest: Codable, Sendable {
        // Tolerant gegenüber dem LLM: alle Felder optional, Defaults beim Mappen.
        let firstName: String?
        let lastName: String?
        let dietary: String?
        let intolerances: [String]?
        let isChild: Bool?
        let funFact: String?
        let notes: String?
    }

    private struct Wrapper: Codable {
        let guests: [ParsedGuest]?
        let plan: [ParsedGuest]?
        let result: [ParsedGuest]?
        let data: [ParsedGuest]?
    }

    /// Eine Antwort im Batch-Modus — pro Anmeldung das Gäste-Array.
    private struct BatchEntry: Codable {
        let row: Int          // 1-basiert, matched buildBatchPrompt
        let guests: [ParsedGuest]
    }

    static let systemPrompt = """
        Du bist ein Daten-Parser für Hochzeitsanmeldungen aus echten Google-Forms-Antworten. \
        Die Daten sind notorisch unsauber — Familienname-Felder enthalten manchmal mehrere \
        Nachnamen ("Stein, Becker", "Brandt und Dallmann", "Nowak/Huber"), und das Gäste-\
        Details-Feld ist Freitext mit allen möglichen Trennzeichen (Komma, Doppelpunkt, \
        Slash, Zeilenumbruch, "und"). Deine Aufgabe: das sauber zu strukturierten Gästen \
        rückzubauen.

        WICHTIG: Du bekommst eine "Anzahl Gäste" — du MUSST genau diese Anzahl Gäste \
        zurückgeben. Falls du nicht alle aus dem Freitext ableiten kannst, ergänze \
        fehlende Personen mit firstName "Gast", lastName aus dem Familienname-Feld, \
        dietary "Fleisch", isChild false. Lieber Platzhalter als zu wenig.

        Beispiele (Familienname → Details → Erwartetes Ergebnis):

        1. "Stein, Becker", Anzahl 2 → "Clara: Vegetarisch, Heike: Fleisch"
           → Clara Stein (Vegetarisch), Heike Becker (Fleisch).
           Bei mehreren Nachnamen im Familienname-Feld die Vornamen den passenden zuordnen.

        2. "Brandt und Dallmann", Anzahl 2 → "Nils Brandt, Fleisch\\nMartha Dallmann, Fleisch"
           → Nils Brandt (Fleisch), Martha Dallmann (Fleisch).

        3. "Sperber", Anzahl 2 → "Resi, Fleisch / Lou, Fleisch"
           → Resi Sperber (Fleisch), Lou Sperber (Fleisch).

        4. "Nowak/Huber", Anzahl 2 → "Patrick Fleisch, Erika Fleisch"
           → Patrick Nowak (Fleisch), Erika Huber (Fleisch).
           Reihenfolge der Nachnamen folgt der Reihenfolge der Vornamen.

        5. "Falkenberg", Anzahl 2 → "Essen alles" mit Fun Facts "Rita ist Bingo-Queen / Jan ist Eishockey-Fan"
           → Rita Falkenberg (Fleisch), Jan Falkenberg (Fleisch).
           "Essen alles" oder unklar → "Fleisch". Vornamen aus Fun Facts ableiten falls \
           nicht in Details genannt.

        6. "Vogel", Anzahl 2 → "Alex, vegetarisch; Lilli, vegan"
           → Alex Vogel (Vegetarisch), Lilli Vogel (Vegan).

        Falls die Anmeldung Zusatz-Spalten enthält (z.B. Heimatort, Anreise, \
        Übernachtungsbedarf, Liedwünsche, Hochzeits-Tipps, persönliche Nachrichten \
        ans Brautpaar) — interpretiere sie sinnvoll. Heimatort / Liedwunsch / \
        Übernachtung / Anreise gehören in das `notes`-Feld des Gastes (kompakt, \
        eine Zeile). Persönliche Botschaften ans Brautpaar gehören NICHT in die \
        Gast-Daten — die ignorieren wir. Tags vergibst du nicht selbst, das macht \
        der User später manuell.

        Pro Gast folgende JSON-Felder:
        - firstName: nur der Vorname, ohne Doppelpunkt oder Sonderzeichen
        - lastName: passender Nachname. Bei Mehrfach-Familiennamen anhand der Vornamen \
          zuordnen; sonst der einzige aus dem Familienname-Feld.
        - dietary: genau einer von "Fleisch", "Vegetarisch", "Vegan". "alles", leer oder \
          unklar = "Fleisch". Groß-/Kleinschreibung ignorieren.
        - intolerances: Array von Strings — Unverträglichkeiten/Allergien. Leer wenn keine.
        - isChild: true nur wenn explizit als Kind markiert.
        - funFact: passender Fun Fact aus dem Fun-Facts-Feld zu diesem Vornamen, ohne \
          "Vorname:"-Präfix. Leer wenn kein Fun Fact gefunden.
        - notes: relevante Zusatz-Infos zum Gast aus den Zusatz-Spalten (Heimatort, \
          Liedwunsch, Anreise, etc.). Eine kompakte Zeile, leer wenn nichts passt.

        Antworte AUSSCHLIESSLICH mit einem JSON-Array. Format:
        [{"firstName":"…","lastName":"…","dietary":"Fleisch","intolerances":[],"isChild":false,"funFact":"…","notes":"…"}]
        Kein Markdown, keine Erklärungen, kein umschließendes Objekt.
        """

    /// Batch-System-Prompt: erweitert den Single-Prompt um die Output-Struktur
    /// für mehrere Anmeldungen in einem Aufruf.
    static let batchSystemPrompt: String = systemPrompt + """


        BATCH-MODUS: Du bekommst mehrere Anmeldungen auf einmal — jeweils mit \
        einer Nummer (1, 2, 3, …). Gib EIN JSON-Array zurück, das pro Anmeldung \
        einen Eintrag mit der Form {"row": N, "guests": [...]} enthält. Die \
        Reihenfolge bleibt erhalten und die Anzahl der Einträge stimmt exakt \
        mit der Anzahl der Anmeldungen überein.

        Format:
        [
          {"row":1,"guests":[{"firstName":"…","lastName":"…","dietary":"Fleisch","intolerances":[],"isChild":false,"funFact":"…"}]},
          {"row":2,"guests":[…]}
        ]

        Kein Markdown, keine Erklärungen, nur das äußere JSON-Array.
        """

    static func buildBatchPrompt(rows: [RegistrationRow]) -> String {
        var lines: [String] = ["Anmeldungen — pro Eintrag genau die angegebene Anzahl Gäste zurückgeben:"]
        for (i, row) in rows.enumerated() {
            lines.append("")
            lines.append("--- Anmeldung \(i + 1) ---")
            lines.append(renderRowFields(row))
        }
        lines.append("")
        lines.append("Gib ein JSON-Array mit \(rows.count) Einträgen zurück, einer pro Anmeldung in dieser Reihenfolge.")
        return lines.joined(separator: "\n")
    }

    /// Parst die Batch-Antwort in eine Liste von Gäste-Listen, eine pro Eingabe-Zeile.
    /// Nicht-zugeordnete Zeilen kriegen `nil`, der Caller kann auf Per-Row-Parsing fallback'en.
    static func parseBatchResponse(_ text: String, rows: [RegistrationRow]) throws -> [[ImportedGuest]?] {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("Batch-Antwort nicht als Text lesbar")
        }
        let decoder = JSONDecoder()

        // Versuch 1: Array von BatchEntries [{row, guests}]
        if let entries = try? decoder.decode([BatchEntry].self, from: data) {
            return mapEntries(entries, count: rows.count)
        }

        // Versuch 2: Array von Arrays [[{firstName, ...}]]
        if let arrays = try? decoder.decode([[ParsedGuest]].self, from: data) {
            return arrays.prefix(rows.count).map { Optional($0.map(toImportedGuest)) }
                + Array(repeating: nil, count: max(0, rows.count - arrays.count))
        }

        // Versuch 3: gewrappt in Objekt
        struct BatchWrapper: Codable {
            let rows: [BatchEntry]?
            let entries: [BatchEntry]?
            let result: [BatchEntry]?
        }
        if let wrapper = try? decoder.decode(BatchWrapper.self, from: data) {
            let entries = wrapper.rows ?? wrapper.entries ?? wrapper.result ?? []
            if !entries.isEmpty {
                return mapEntries(entries, count: rows.count)
            }
        }

        throw ImportError.invalidFormat("Batch-Antwort hat unerwartetes Format")
    }

    private static func mapEntries(_ entries: [BatchEntry], count: Int) -> [[ImportedGuest]?] {
        var result: [[ImportedGuest]?] = Array(repeating: nil, count: count)
        for entry in entries {
            let idx = entry.row - 1 // 1-basiert in der Antwort
            guard result.indices.contains(idx) else { continue }
            result[idx] = entry.guests.map(toImportedGuest)
        }
        return result
    }

    static func buildPrompt(for row: RegistrationRow) -> String {
        let body = renderRowFields(row)
        return """
        \(body)

        Gib GENAU \(row.guestCount) \(row.guestCount == 1 ? "Gast" : "Gäste") als JSON-Array zurück.
        """
    }

    /// Rendert eine Zeile als Prompt-Block — die strukturierten Schlüssel-
    /// felder zuerst (Familienname, Anzahl, Gäste-Details, Fun Facts,
    /// Anmerkungen), dann ALLE weiteren Spalten aus rawFields die noch nicht
    /// gezeigt wurden. So sieht der LLM auch Zusatz-Spalten wie Heimatort,
    /// Liedwunsch, Anreise — die er als Tags oder Notizen interpretieren kann.
    private static func renderRowFields(_ row: RegistrationRow) -> String {
        var lines: [String] = []
        lines.append("Familienname: \"\(row.familyName)\"")
        lines.append("Anzahl Gäste: \(row.guestCount)")
        lines.append("Gäste-Details: \"\(row.guestDetails)\"")
        lines.append("Fun Facts: \"\(row.funFacts)\"")
        lines.append("Anmerkungen: \"\(row.notes)\"")

        // Werte die schon in den Hauptfeldern landen, nicht doppelt zeigen
        let alreadyShown: Set<String> = [
            row.familyName, row.guestDetails, row.funFacts, row.notes
        ]

        var extras: [String] = []
        for field in row.rawFields {
            let trimmed = field.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !alreadyShown.contains(trimmed) else { continue }
            // Header verkürzen falls Google-Forms-typisch ellenlang
            let shortHeader = field.header
                .components(separatedBy: "(").first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                ?? field.header
            extras.append("\(shortHeader): \"\(trimmed)\"")
        }

        if !extras.isEmpty {
            lines.append("")
            lines.append("Zusatz-Spalten aus dem Formular:")
            lines.append(contentsOf: extras)
        }
        return lines.joined(separator: "\n")
    }

    static func parseResponse(_ text: String, expectedCount: Int) throws -> [ImportedGuest] {
        let jsonString = extractJSON(from: text)
        guard let data = jsonString.data(using: .utf8) else {
            throw ImportError.invalidFormat("Konnte Antwort nicht als Text lesen")
        }
        let decoder = JSONDecoder()

        // 1. Versuch: direkt als Array
        if let parsed = try? decoder.decode([ParsedGuest].self, from: data) {
            return parsed.map(toImportedGuest)
        }

        // 2. Versuch: umschließendes Objekt {"guests": [...]} / "plan" / "result" / "data"
        if let wrapper = try? decoder.decode(Wrapper.self, from: data) {
            let parsed = wrapper.guests ?? wrapper.plan ?? wrapper.result ?? wrapper.data ?? []
            if !parsed.isEmpty {
                return parsed.map(toImportedGuest)
            }
        }

        // 3. Versuch: einzelnes Objekt → in Array packen
        if let single = try? decoder.decode(ParsedGuest.self, from: data) {
            return [toImportedGuest(single)]
        }

        // Nichts hat gepasst — Caller fängt das ab und macht den Fallback-Parser.
        let preview = jsonString.prefix(120)
        throw ImportError.invalidFormat("Antwort hat unerwartetes Format: \(preview)")
    }

    private static func toImportedGuest(_ p: ParsedGuest) -> ImportedGuest {
        ImportedGuest(
            firstName: (p.firstName ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: (p.lastName ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            dietaryChoice: normalizeDietary(p.dietary ?? ""),
            intolerances: (p.intolerances ?? []).filter { !$0.isEmpty },
            ageCategory: (p.isChild ?? false) ? .child : .adult,
            funFact: (p.funFact ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            notes: (p.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    static func extractJSON(from text: String) -> String {
        // Zuerst: ```json fenced Block
        if let start = text.range(of: "```json"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Zweitens: irgendein ```-Block
        if let start = text.range(of: "```"),
           let end = text.range(of: "```", range: start.upperBound..<text.endIndex) {
            return String(text[start.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Drittens: erstes [ ... letztes ]  (Array)
        if let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start < end {
            return String(text[start...end])
        }
        // Viertens: erstes { ... letztes }  (Objekt)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeDietary(_ raw: String) -> String {
        let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
        switch lower {
        case "vegan": return "Vegan"
        case "vegetarisch", "vegetarian", "veggie", "veg": return "Vegetarisch"
        default: return "Fleisch"
        }
    }

    /// Geht jeden Gast durch und ergänzt fehlende funFacts aus dem dedizierten
    /// Fun-Facts-Feld der Anmeldung. Verwendet ALLE Vornamen der Anmeldung als
    /// Grenzen, damit der Fun Fact einer Person nicht in den Fun Fact der
    /// nächsten überläuft (Beispiel: "Heike Becker: Hat … besucht. Clara
    /// Stein: Ist schonmal …" — Heikes Fact endet bei "Clara").
    /// Existierende funFacts bleiben unverändert.
    static func enrichFunFacts(_ guests: [ImportedGuest], from row: RegistrationRow) -> [ImportedGuest] {
        guard !row.funFacts.isEmpty else { return guests }

        // Anker pro Gast: erste Position des Vornamens im Text (case-insensitive,
        // vorzugsweise gefolgt von ":" oder Leerzeichen+Großbuchstabe).
        let text = row.funFacts
        let lowerText = text.lowercased()
        var anchors: [(guestIndex: Int, start: String.Index)] = []
        for (i, g) in guests.enumerated() {
            let firstName = g.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !firstName.isEmpty else { continue }
            if let pos = findNameAnchor(name: firstName, in: lowerText, originalText: text) {
                anchors.append((i, pos))
            }
        }
        anchors.sort { $0.start < $1.start }

        var result = guests
        for (n, anchor) in anchors.enumerated() {
            // Fact endet bei dem Anker des nächsten gefundenen Gastes — oder am Textende
            let nextStart = (n + 1 < anchors.count) ? anchors[n + 1].start : text.endIndex
            let segment = String(text[anchor.start..<nextStart])
            let fact = stripNamePrefix(from: segment, firstName: result[anchor.guestIndex].firstName)
            if !fact.isEmpty, result[anchor.guestIndex].funFact.isEmpty {
                let g = result[anchor.guestIndex]
                result[anchor.guestIndex] = ImportedGuest(
                    firstName: g.firstName,
                    lastName: g.lastName,
                    dietaryChoice: g.dietaryChoice,
                    intolerances: g.intolerances,
                    ageCategory: g.ageCategory,
                    funFact: fact,
                    notes: g.notes,
                    tagNames: g.tagNames
                )
            }
        }
        return result
    }

    /// Behält Public-API für Edge-Cases: ein einzelner Vorname → ein Fact.
    /// Findet die erste Position im Text und nimmt alles bis zum nächsten
    /// Vornamen-Anker (case-insensitive) oder Textende.
    static func extractFunFact(for firstName: String, from text: String) -> String? {
        let result = enrichFunFacts(
            [ImportedGuest(firstName: firstName, lastName: "", dietaryChoice: "Fleisch",
                           intolerances: [], ageCategory: .adult, funFact: "", notes: "")],
            from: RegistrationRow(familyName: "", guestCount: 1, guestDetails: "",
                                   funFacts: text, notes: "")
        )
        let f = result.first?.funFact ?? ""
        return f.isEmpty ? nil : f
    }

    /// Findet die Position eines Vornamens im Text — bevorzugt mit ":" oder
    /// "<Großbuchstabe>" danach, damit "Heike" in "Heike Becker: …" trifft
    /// aber nicht zufällig mitten in einem anderen Wort.
    private static func findNameAnchor(name: String, in lowerText: String, originalText: String) -> String.Index? {
        let needle = name.lowercased()
        var searchStart = lowerText.startIndex
        while let range = lowerText.range(of: needle, range: searchStart..<lowerText.endIndex) {
            // Wort-Anfang prüfen
            let isWordStart = range.lowerBound == lowerText.startIndex
                || !lowerText[lowerText.index(before: range.lowerBound)].isLetter
            if isWordStart {
                return range.lowerBound
            }
            searchStart = lowerText.index(after: range.lowerBound)
        }
        return nil
    }

    /// Entfernt führendes "Vorname [Nachname]:" oder "Vorname " vom Segment-Start.
    private static func stripNamePrefix(from segment: String, firstName: String) -> String {
        var s = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        // Entferne führenden Vornamen
        if s.lowercased().hasPrefix(firstName.lowercased()) {
            s = String(s.dropFirst(firstName.count))
        }
        // Entferne optionalen Nachnamen vor dem Doppelpunkt: " Becker:" oder ":"
        if let colonIdx = s.firstIndex(of: ":") {
            let beforeColon = s[..<colonIdx]
            // Nur überspringen wenn vor dem Doppelpunkt nur Wortzeichen + Leerzeichen sind
            // (also wirklich ein Name-Header, kein Satz mit "Doppelpunkt: …")
            if beforeColon.allSatisfy({ $0.isLetter || $0.isWhitespace || $0 == "-" }) {
                s = String(s[s.index(after: colonIdx)...])
            }
        }
        return s.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,;-")))
    }

    /// Erzwingt, dass das Ergebnis mindestens `expectedCount` Gäste hat —
    /// fehlende werden mit Familiennamen-Platzhaltern aufgefüllt.
    static func ensureCount(_ guests: [ImportedGuest], expected: Int, familyName: String) -> [ImportedGuest] {
        guard guests.count < expected else { return guests }
        var result = guests
        let lastName = primaryLastName(from: familyName)
        for i in guests.count..<expected {
            result.append(ImportedGuest(
                firstName: i == 0 ? "Gast" : "Gast \(i + 1)",
                lastName: lastName,
                dietaryChoice: "Fleisch",
                intolerances: [],
                ageCategory: .adult,
                funFact: "",
                notes: ""
            ))
        }
        return result
    }

    private static func primaryLastName(from familyName: String) -> String {
        familyName
            .components(separatedBy: CharacterSet(charactersIn: ",/&"))
            .first?
            .replacingOccurrences(of: " und ", with: " ")
            .components(separatedBy: " ")
            .first?
            .trimmingCharacters(in: .whitespaces)
            ?? familyName
    }

    // MARK: - Fallback Parser (ohne KI)

    static func fallbackParse(_ row: RegistrationRow) -> [ImportedGuest] {
        let text = row.guestDetails.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return ensureCount([], expected: row.guestCount, familyName: row.familyName)
        }

        // Heuristik 1: "Vorname: Diet, Vorname: Diet" (Pattern aus Stein-Becker-Zeile)
        if text.contains(":") && text.contains(",") {
            let pairs = text
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let isAllNameDiet = pairs.allSatisfy { $0.contains(":") }
            if isAllNameDiet, pairs.count == row.guestCount || pairs.count > 1 {
                let surnames = splitSurnames(from: row.familyName)
                let parsed = pairs.enumerated().compactMap { (idx, pair) -> ImportedGuest? in
                    let parts = pair.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
                    guard let first = parts.first, !first.isEmpty else { return nil }
                    let diet = parts.count > 1 ? normalizeDietary(parts[1]) : "Fleisch"
                    let surname = surnames.indices.contains(idx) ? surnames[idx] : (surnames.first ?? "")
                    return ImportedGuest(firstName: first, lastName: surname, dietaryChoice: diet,
                                         intolerances: [], ageCategory: .adult, funFact: "", notes: "")
                }
                if !parsed.isEmpty {
                    return ensureCount(parsed, expected: row.guestCount, familyName: row.familyName)
                }
            }
        }

        // Heuristik 2: split by separator, dann pro Person Komma-Parsing (Name, Diet)
        let separators = ["\n", "//", "/", ";"]
        var lines = [text]
        for sep in separators {
            lines = lines.flatMap { $0.components(separatedBy: sep) }
        }
        lines = lines.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        let surnames = splitSurnames(from: row.familyName)
        var parsed: [ImportedGuest] = []
        for (idx, line) in lines.enumerated() {
            let parts = line.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            let namePart = parts.first ?? line
            let names = splitName(namePart, defaultLastName: surnames.indices.contains(idx) ? surnames[idx] : (surnames.first ?? ""))
            let dietary = parts.count > 1 ? normalizeDietary(parts[1]) : "Fleisch"
            let isChild = line.lowercased().contains("kind")
            parsed.append(ImportedGuest(firstName: names.first, lastName: names.last,
                                         dietaryChoice: dietary, intolerances: [],
                                         ageCategory: isChild ? .child : .adult,
                                         funFact: "", notes: ""))
        }

        return ensureCount(parsed, expected: row.guestCount, familyName: row.familyName)
    }

    /// Splittet "Stein, Becker" → ["Stein", "Becker"], "Brandt und Dallmann" → ["Brandt", "Dallmann"]
    private static func splitSurnames(from familyName: String) -> [String] {
        var names = [familyName]
        for sep in [",", "/", "&", " und ", " + "] {
            names = names.flatMap { $0.components(separatedBy: sep) }
        }
        return names.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func splitName(_ name: String, defaultLastName: String) -> (first: String, last: String) {
        let words = name.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ":", with: "")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        if words.count >= 2 {
            return (words[0], words.dropFirst().joined(separator: " "))
        } else if words.count == 1 {
            return (words[0], defaultLastName)
        }
        return (name, defaultLastName)
    }
}
