#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

extension ImportPreviewView {
    var pendingRows: [(Int, RegistrationRow)] {
        rows.enumerated().compactMap { (i, r) in
            (skippedIndices.contains(i) || importedIndices.contains(i) || autoSkippedIndices.contains(i)) ? nil : (i, r)
        }
    }

    /// Eine Zeile gilt als "unverändert", wenn jeder geparste Gast bereits in
    /// der DB existiert (Match per ImportMatcher) und keines der relevanten
    /// Felder abweicht. Dann gibt's nichts zu importieren — wir überspringen
    /// automatisch ohne den User zu nerven.
    func isRowUnchanged(at index: Int, parsed: [ImportedGuest]) -> Bool {
        let row = rows[index]
        guard !parsed.isEmpty else { return false }
        for ig in parsed {
            guard let existing = ImportMatcher.findExisting(guest: ig, in: row, among: existingGuests) else {
                return false
            }
            if existing.firstName.trimmingCharacters(in: .whitespaces).lowercased()
                != ig.firstName.trimmingCharacters(in: .whitespaces).lowercased() { return false }
            if existing.lastName.trimmingCharacters(in: .whitespaces).lowercased()
                != ig.lastName.trimmingCharacters(in: .whitespaces).lowercased() { return false }
            if existing.dietaryChoice != ig.dietaryChoice { return false }
            if Set(existing.intolerances.map { $0.lowercased() }) != Set(ig.intolerances.map { $0.lowercased() }) { return false }
            if existing.ageCategory != ig.ageCategory { return false }
        }
        return true
    }

    /// Geht alle frisch geparsten Zeilen durch und markiert die ohne
    /// Abweichung als auto-übersprungen. Wird nach jedem Batch aufgerufen.
    @MainActor
    func detectUnchangedRows() {
        for i in rows.indices {
            guard !skippedIndices.contains(i),
                  !importedIndices.contains(i),
                  !autoSkippedIndices.contains(i) else { continue }
            let parsed: [ImportedGuest]?
            switch rowStates[i] {
            case .parsed(let g): parsed = g
            case .fallback(let g, _): parsed = g
            default: parsed = nil
            }
            guard let guests = parsed else { continue }
            if isRowUnchanged(at: i, parsed: guests) {
                autoSkippedIndices.insert(i)
            }
        }
    }

    func retryWithLLM() async {
        isRetrying = true
        defer { isRetrying = false }
        // Reset und nochmal — diesmal mit aktuellem Connection-Check.
        await MainActor.run {
            for i in rows.indices where !importedIndices.contains(i) && !skippedIndices.contains(i) {
                rowStates[i] = .parsing
            }
            llmReachable = nil
        }
        await parseAllRows()
    }

    // MARK: - Parsing

    func parseAllRows() async {
        // Initial: alle als .parsing markieren
        await MainActor.run {
            for i in rows.indices {
                rowStates[i] = .parsing
            }
        }

        let endpoint = lmStudioEndpoint
        let provider = LLMClientFactory.provider(for: .importParse)
        let isOnline: Bool
        if provider == .lmStudio {
            isOnline = await Self.checkLMStudioReachable(endpoint: endpoint)
        } else {
            isOnline = true
        }
        await MainActor.run {
            llmReachable = isOnline
        }

        guard isOnline else {
            await MainActor.run {
                for i in rows.indices {
                    let parsed = LLMGuestParser.fallbackParse(rows[i])
                    rowStates[i] = .fallback(parsed, reason: "LM Studio (\(endpoint)) nicht erreichbar — Fallback-Parser verwendet. Schau einmal drüber.")
                }
            }
            return
        }

        // Batch-Modus: Anmeldungen in 12er-Chunks an die KI schicken (passt
        // bei den meisten Modellen auch in 4K Context, ein 27B mit 16K kriegt
        // alles mit Headroom). Nur wenn ein ganzer Batch fehlschlägt fallen
        // wir per Zeile auf Per-Row + Regex zurück.
        let chunkSize = 12
        let chunks = stride(from: 0, to: rows.count, by: chunkSize).map { start in
            Array(rows[start..<min(start + chunkSize, rows.count)])
        }
        await MainActor.run { parseProgress = (0, rows.count) }
        var globalIndex = 0
        for chunk in chunks {
            if Task.isCancelled {
                await MainActor.run {
                    for i in rows.indices {
                        guard case .parsing = rowStates[i] else { continue }
                        let parsed = LLMGuestParser.fallbackParse(rows[i])
                        rowStates[i] = .fallback(parsed, reason: "Abgebrochen — Fallback-Parser verwendet. Schau einmal drüber.")
                    }
                }
                return
            }
            let startIndex = globalIndex
            let states = await Self.parseBatch(chunk: chunk, originalStartIndex: startIndex)
            await MainActor.run {
                for (offset, state) in states.enumerated() {
                    rowStates[startIndex + offset] = state
                }
                detectUnchangedRows()
                parseProgress = (min(startIndex + chunk.count, rows.count), rows.count)
            }
            globalIndex += chunk.count
        }
    }

    /// Schickt einen Chunk aus 1-N Anmeldungen als ein einziges Batch-Prompt
    /// an die KI. Wenn das Parsen scheitert oder einzelne Zeilen fehlen, fällt
    /// jede betroffene Zeile auf Per-Row-Parsing bzw. den Regex-Fallback zurück.
    static func parseBatch(chunk: [RegistrationRow], originalStartIndex: Int) async -> [RowState] {
        guard !chunk.isEmpty else { return [] }
        let client = LLMClientFactory.makeClient(for: .importParse)
        let userPrompt = LLMGuestParser.buildBatchPrompt(rows: chunk)
        do {
            let response = try await client.chat(messages: [
                LLMMessage(role: "system", content: LLMGuestParser.batchSystemPrompt),
                LLMMessage(role: "user", content: userPrompt),
            ], temperature: 0.2, maxTokens: 4096)

            let parsed = try LLMGuestParser.parseBatchResponse(response, rows: chunk)
            var result: [RowState] = []
            for (i, row) in chunk.enumerated() {
                if let guests = parsed[i] {
                    let padded = LLMGuestParser.ensureCount(guests, expected: row.guestCount, familyName: row.familyName)
                    let enriched = LLMGuestParser.enrichFunFacts(padded, from: row)
                    if guests.count < row.guestCount {
                        result.append(.fallback(enriched, reason: "KI fand nur \(guests.count) von \(row.guestCount) Gästen — fehlende mit Platzhaltern aufgefüllt."))
                    } else {
                        result.append(.parsed(enriched))
                    }
                } else {
                    // Diese Zeile fehlt im Batch — Per-Row als Backup
                    let single = await parseSingle(row: row)
                    result.append(single)
                }
            }
            return result
        } catch {
            // Ganzer Batch hat versagt — pro Zeile Per-Row-Fallback
            var result: [RowState] = []
            for row in chunk {
                let single = await parseSingle(row: row)
                result.append(single)
            }
            return result
        }
    }

    /// Schneller Connection-Check (max 3s) gegen den /v1/models Endpoint.
    static func checkLMStudioReachable(endpoint: String) async -> Bool {
        guard let url = URL(string: endpoint + "/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                return true
            }
            return false
        } catch {
            return false
        }
    }

    static func parseSingle(row: RegistrationRow) async -> RowState {
        let client = LLMClientFactory.makeClient(for: .importParse)
        let userPrompt = LLMGuestParser.buildPrompt(for: row)
        do {
            let response = try await client.chat(messages: [
                LLMMessage(role: "system", content: LLMGuestParser.systemPrompt),
                LLMMessage(role: "user", content: userPrompt),
            ], temperature: 0.2, maxTokens: 2048)
            let parsed = try LLMGuestParser.parseResponse(response, expectedCount: row.guestCount)
            let padded = LLMGuestParser.ensureCount(parsed, expected: row.guestCount, familyName: row.familyName)
            // Fun-Facts aus eigener Spalte ergänzen falls KI sie nicht zugeordnet hat
            let enriched = LLMGuestParser.enrichFunFacts(padded, from: row)

            if parsed.count < row.guestCount {
                return .fallback(
                    enriched,
                    reason: "KI fand nur \(parsed.count) von \(row.guestCount) Gästen — fehlende mit Platzhaltern aufgefüllt."
                )
            }
            return .parsed(enriched)
        } catch {
            let fallback = LLMGuestParser.fallbackParse(row)
            let enriched = LLMGuestParser.enrichFunFacts(fallback, from: row)
            return .fallback(enriched, reason: error.localizedDescription)
        }
    }
}
#endif
