#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S4 — Anmeldungs-Import (siehe design_handoff_gaesteglueck → S4).
/// Parst pro Zeile via LM Studio in strukturierte Gäste, zeigt das
/// Ergebnis pro Karte mit Original oben + KI-Interpretation unten.
/// Wenn die KI nicht erreichbar ist, fällt der Parser auf den Regex-
/// Fallback zurück und markiert die Karte als "prüfen".
struct ImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"

    let rows: [RegistrationRow]
    let onComplete: (Int) -> Void

    @State private var rowStates: [Int: RowState] = [:]
    @State private var skippedIndices: Set<Int> = []
    @State private var importedIndices: Set<Int> = []
    @State private var autoSkippedIndices: Set<Int> = []
    @State private var showingAutoSkipped = false
    @State private var hasStartedParsing = false
    @State private var llmReachable: Bool? = nil
    @State private var isRetrying = false
    @State private var parseTask: Task<Void, Never>? = nil
    @State private var parseProgress: (done: Int, total: Int) = (0, 0)

    enum RowState {
        case parsing
        case parsed([ImportedGuest])
        case fallback([ImportedGuest], reason: String)

        var guests: [ImportedGuest] {
            switch self {
            case .parsing: return []
            case .parsed(let g), .fallback(let g, _): return g
            }
        }
    }

    private var pendingRows: [(Int, RegistrationRow)] {
        rows.enumerated().compactMap { (i, r) in
            (skippedIndices.contains(i) || importedIndices.contains(i) || autoSkippedIndices.contains(i)) ? nil : (i, r)
        }
    }

    /// Eine Zeile gilt als "unverändert", wenn jeder geparste Gast bereits in
    /// der DB existiert (Match per ImportMatcher) und keines der relevanten
    /// Felder abweicht. Dann gibt's nichts zu importieren — wir überspringen
    /// automatisch ohne den User zu nerven.
    private func isRowUnchanged(at index: Int, parsed: [ImportedGuest]) -> Bool {
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
    private func detectUnchangedRows() {
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

    private var totalGuests: Int {
        rows.reduce(0) { $0 + $1.guestCount }
    }

    private var canApplyAll: Bool {
        guard !pendingRows.isEmpty else { return false }
        return pendingRows.allSatisfy { _, _ in true }
            && pendingRows.contains { i, _ in
                if case .parsing = rowStates[i] { return false }
                return true
            }
    }

    var body: some View {
        ZStack {
            Tokens.Colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if parseTask != nil {
                            parseProgressBanner
                        }
                        if llmReachable == false {
                            llmOfflineBanner
                        }
                        infoBanner
                        if !autoSkippedIndices.isEmpty {
                            autoSkippedBanner
                        }
                        ForEach(rows.indices, id: \.self) { i in
                            let isAutoSkipped = autoSkippedIndices.contains(i)
                            let visible = !skippedIndices.contains(i)
                                && !importedIndices.contains(i)
                                && (!isAutoSkipped || showingAutoSkipped)
                            if visible {
                                ImportRowCard(
                                    row: rows[i],
                                    state: rowStates[i] ?? .parsing,
                                    isAutoSkipped: isAutoSkipped,
                                    onUpdate: { newGuests in
                                        updateGuests(at: i, with: newGuests)
                                    },
                                    onAccept: {
                                        applyRow(at: i)
                                    },
                                    onSkip: {
                                        skippedIndices.insert(i)
                                        persistSkip(rowIndex: i)
                                    }
                                )
                            }
                        }
                        if pendingRows.isEmpty && rows.count > 0 {
                            Text("Alle Anmeldungen abgearbeitet.")
                                .font(Tokens.Typography.bodyM)
                                .foregroundStyle(Tokens.Colors.ink3)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .task {
            guard !hasStartedParsing else { return }
            hasStartedParsing = true
            let t = Task { await parseAllRows() }
            parseTask = t
            await t.value
            parseTask = nil
        }
    }

    private var parseProgressBanner: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("KI liest die Anmeldungen…")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if parseProgress.total > 0 {
                    Text("\(parseProgress.done) / \(parseProgress.total) Anmeldungen · \(max(0, parseProgress.total - parseProgress.done)) offen")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
            }
            Spacer()
            Button("Abbrechen", role: .cancel) { parseTask?.cancel() }
                .warmButton(.secondary, size: .sm)
        }
        .padding(12)
        .background(Tokens.Colors.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
    }

    private var toolbar: some View {
        ScreenToolbar(
            title: "Anmeldungen prüfen",
            subtitle: "Wir haben \(rows.count) \(rows.count == 1 ? "Anmeldung" : "Anmeldungen") erkannt — schau einmal drüber."
        ) {
            Button("Abbrechen") { dismiss() }
                .warmButton(.ghost)
            Button("Alle überspringen") {
                skippedIndices = Set(rows.indices)
                for i in rows.indices {
                    persistSkip(rowIndex: i)
                }
                finalize()
            }
            .warmButton(.secondary)
            .disabled(pendingRows.isEmpty)
            Button {
                for (i, _) in pendingRows {
                    applyRow(at: i)
                }
                finalize()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Alle übernehmen (\(pendingRows.count))")
                }
            }
            .warmButton(.primary)
            .disabled(pendingRows.isEmpty)
        }
    }

    private var infoBanner: some View {
        ConflictBanner(
            title: "\(rows.count) \(rows.count == 1 ? "Anmeldung erkannt" : "Anmeldungen erkannt") · \(totalGuests) Personen insgesamt",
            message: "Die Datei wurde lokal verarbeitet. Bestehende Anmeldungen erkennen wir am Familiennamen.",
            tone: .info
        )
    }

    private var autoSkippedBanner: some View {
        ConflictBanner(
            title: "\(autoSkippedIndices.count) \(autoSkippedIndices.count == 1 ? "Anmeldung" : "Anmeldungen") unverändert — automatisch übersprungen",
            message: "Diese Anmeldungen sind bereits in der Gästeliste und haben keine Änderungen. Du kannst sie trotzdem einblenden falls du nochmal drüberschauen willst.",
            tone: .info
        ) {
            Button {
                showingAutoSkipped.toggle()
            } label: {
                Text(showingAutoSkipped ? "Wieder ausblenden" : "Trotzdem anzeigen")
            }
            .warmButton(.secondary, size: .sm)
        }
    }

    private var llmOfflineBanner: some View {
        ConflictBanner(
            title: "LM Studio ist nicht erreichbar — wir nutzen den einfachen Parser",
            message: "Für bessere Erkennung (insbesondere bei Mehrfach-Familiennamen wie 'Stein, Becker') starte LM Studio mit einem Modell und klick 'Erneut versuchen'.",
            tone: .warn
        ) {
            Button {
                Task { await retryWithLLM() }
            } label: {
                HStack(spacing: 4) {
                    if isRetrying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Erneut versuchen")
                }
            }
            .warmButton(.secondary, size: .sm)
            .disabled(isRetrying)
        }
    }

    private func retryWithLLM() async {
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

    private func parseAllRows() async {
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
    private static func parseBatch(chunk: [RegistrationRow], originalStartIndex: Int) async -> [RowState] {
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
    private static func checkLMStudioReachable(endpoint: String) async -> Bool {
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

    private static func parseSingle(row: RegistrationRow) async -> RowState {
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

    // MARK: - Apply

    private func updateGuests(at index: Int, with guests: [ImportedGuest]) {
        // Edits aus dem Card → State updaten. Wir bleiben im gleichen
        // Zustand-Bucket (parsed / fallback), nur die Liste tauscht.
        guard let current = rowStates[index] else { return }
        switch current {
        case .parsing:
            rowStates[index] = .parsed(guests)
        case .parsed:
            rowStates[index] = .parsed(guests)
        case .fallback(_, let reason):
            rowStates[index] = .fallback(guests, reason: reason)
        }
    }

    private func applyRow(at index: Int) {
        guard let state = rowStates[index] else { return }
        let guests = state.guests
        guard !guests.isEmpty else { return }

        let row = rows[index]
        let registrationGroup = UUID()
        var insertedOrUpdatedGuests: [Guest] = []

        for ig in guests {
            if let existing = ImportMatcher.findExisting(guest: ig, in: row, among: existingGuests) {
                // Sicheres Match → Felder updaten
                existing.dietaryChoice = ig.dietaryChoice
                existing.intolerances = ig.intolerances
                existing.ageCategory = ig.ageCategory
                // funFact nur setzen wenn der bestehende Eintrag noch keinen hat —
                // manuelle Pflege gewinnt gegen Auto-Extraktion beim Re-Import.
                if existing.funFact.isEmpty, !ig.funFact.isEmpty {
                    existing.funFact = ig.funFact
                }
                if existing.registrationGroup == nil {
                    existing.registrationGroup = registrationGroup
                }
                if existing.sourceID.isEmpty {
                    existing.sourceID = row.sourceID
                    existing.sourceEmail = row.sourceEmail
                }
                for tagName in ig.tagNames {
                    attachTag(named: tagName, to: existing)
                }
                insertedOrUpdatedGuests.append(existing)
            } else {
                let guest = Guest(
                    firstName: ig.firstName,
                    lastName: ig.lastName,
                    ageCategory: ig.ageCategory,
                    dietaryChoice: ig.dietaryChoice,
                    intolerances: ig.intolerances,
                    funFact: ig.funFact,
                    notes: ig.notes,
                    registrationGroup: registrationGroup,
                    sourceID: row.sourceID,
                    sourceEmail: row.sourceEmail
                )
                modelContext.insert(guest)
                for tagName in ig.tagNames {
                    attachTag(named: tagName, to: guest)
                }
                insertedOrUpdatedGuests.append(guest)
            }
        }

        // Eine gemeinsame Anmeldung mit 2+ Personen → automatischer "muss
        // zusammen sitzen"-Constraint. Lou + Resi, ein Ehepaar oder eine
        // Familie mit Begleitung soll nicht von der KI getrennt werden.
        if insertedOrUpdatedGuests.count >= 2 {
            let groupIDs = insertedOrUpdatedGuests.map(\.id)
            let alreadyExists = existingConstraints.contains { c in
                c.type == .mustSitTogether && Set(c.guestIDs) == Set(groupIDs)
            }
            if !alreadyExists {
                let reason = "Gemeinsame Anmeldung — \(row.familyName)"
                let constraint = Constraint(type: .mustSitTogether, guestIDs: groupIDs, reason: reason)
                modelContext.insert(constraint)
            }
        }

        importedIndices.insert(index)
    }

    @Query private var existingConstraints: [Constraint]

    @Query private var existingGuests: [Guest]
    @Query(sort: \Tag.name) private var existingTags: [Tag]
    @Query private var allEvents: [Event]
    private var currentEvent: Event? { allEvents.first }

    private func persistSkip(rowIndex: Int) {
        let sourceID = rows[rowIndex].sourceID
        guard !sourceID.isEmpty, let event = currentEvent else { return }
        if !event.skippedSourceIDs.contains(sourceID) {
            event.skippedSourceIDs.append(sourceID)
        }
    }

    private func attachTag(named name: String, to guest: Guest) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = existingTags.first(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            if !existing.guestIDs.contains(guest.id) {
                existing.guestIDs.append(guest.id)
            }
        } else {
            let category: TagCategory = trimmed.lowercased().contains("familie") ? .family : .custom
            let newTag = Tag(name: trimmed, category: category)
            newTag.guestIDs = [guest.id]
            modelContext.insert(newTag)
        }
    }

    private func finalize() {
        let imported = importedIndices.reduce(0) { sum, i in
            sum + (rowStates[i]?.guests.count ?? 0)
        }
        onComplete(imported)
        dismiss()
    }
}
#endif
