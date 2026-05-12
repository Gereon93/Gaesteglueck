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
            await parseAllRows()
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
        let provider = LLMClientFactory.providerFromSettings()
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
        var globalIndex = 0
        for chunk in chunks {
            let startIndex = globalIndex
            let states = await Self.parseBatch(chunk: chunk, originalStartIndex: startIndex)
            await MainActor.run {
                for (offset, state) in states.enumerated() {
                    rowStates[startIndex + offset] = state
                }
                // Nach jedem Batch: schauen ob bereits in DB unverändert
                detectUnchangedRows()
            }
            globalIndex += chunk.count
        }
    }

    /// Schickt einen Chunk aus 1-N Anmeldungen als ein einziges Batch-Prompt
    /// an die KI. Wenn das Parsen scheitert oder einzelne Zeilen fehlen, fällt
    /// jede betroffene Zeile auf Per-Row-Parsing bzw. den Regex-Fallback zurück.
    private static func parseBatch(chunk: [RegistrationRow], originalStartIndex: Int) async -> [RowState] {
        guard !chunk.isEmpty else { return [] }
        let client = LLMClientFactory.makeFromSettings()
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
        let client = LLMClientFactory.makeFromSettings()
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

// MARK: - Import Row Card

private struct ImportRowCard: View {
    let row: RegistrationRow
    let state: ImportPreviewView.RowState
    var isAutoSkipped: Bool = false
    let onUpdate: ([ImportedGuest]) -> Void
    let onAccept: () -> Void
    let onSkip: () -> Void

    @Query private var existingGuests: [Guest]
    @State private var editingIndex: Int? = nil

    private func matchType(for g: ImportedGuest) -> ImportMatcher.MatchType {
        ImportMatcher.classify(guest: g, in: row, among: existingGuests)
    }

    private var rawText: String {
        var parts: [String] = []
        parts.append(row.familyName)
        if !row.guestDetails.isEmpty { parts.append(row.guestDetails) }
        if !row.funFacts.isEmpty { parts.append(row.funFacts) }
        if !row.notes.isEmpty { parts.append(row.notes) }
        return parts.joined(separator: " · ")
    }

    private var statusBadge: (text: String, fg: Color, bg: Color)? {
        if isAutoSkipped {
            return ("Unverändert", Tokens.Colors.sage, Tokens.Colors.sage.opacity(0.18))
        }
        switch state {
        case .parsing: return ("Parst…", Tokens.Colors.ink3, Tokens.Colors.bg2)
        case .parsed: return nil
        case .fallback: return ("Prüfen", Tokens.Colors.warn, Tokens.Colors.warnSoft)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Original
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Tokens.Colors.bg3)
                    Image(systemName: "doc.text")
                        .font(.system(size: 13))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 4) {
                    Text("ORIGINAL-ANMELDUNG")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                    Text("\u{201E}\(rawText)\u{201C}")
                        .font(Tokens.Typography.display(size: 14.5, italic: true))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let badge = statusBadge {
                    Text(badge.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(badge.fg)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badge.bg)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Tokens.Colors.surface)

            Divider().background(Tokens.Colors.line)

            // Parsing-State / Gäste
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Tokens.Colors.accent)
                    Text("Wir lesen daraus:")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.accent)
                        .tracking(0.3)
                }

                switch state {
                case .parsing:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("KI parst die Anmeldung…")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                case .parsed(let guests), .fallback(let guests, _):
                    if guests.isEmpty {
                        Text("Keine Gäste extrahiert.")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                    } else {
                        ForEach(Array(guests.enumerated()), id: \.offset) { idx, g in
                            parsedGuestRow(g, index: idx)
                        }
                    }

                    Button {
                        var updated = guests
                        let lastName = guests.last?.lastName ?? row.familyName
                        updated.append(ImportedGuest(
                            firstName: "Neuer Gast",
                            lastName: lastName,
                            dietaryChoice: "Fleisch",
                            intolerances: [],
                            ageCategory: .adult,
                            funFact: "",
                            notes: ""
                        ))
                        onUpdate(updated)
                        editingIndex = updated.count - 1
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                            Text("Person hinzufügen")
                        }
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)

                    if case .fallback(_, let reason) = state {
                        Text("Hinweis: " + reason)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.warn)
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Überspringen") { onSkip() }
                        .warmButton(.ghost, size: .sm)
                    Button {
                        onAccept()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                            Text("Übernehmen")
                        }
                    }
                    .warmButton(.primary, size: .sm)
                    .disabled({
                        if case .parsing = state { return true }
                        return state.guests.isEmpty
                    }())
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
        .sheet(item: Binding<EditingTarget?>(
            get: {
                guard let idx = editingIndex,
                      let guest = state.guests[safe: idx] else { return nil }
                return EditingTarget(index: idx, guest: guest)
            },
            set: { editingIndex = $0?.index }
        )) { target in
            ImportGuestEditSheet(
                guest: target.guest,
                onSave: { updated in
                    var list = state.guests
                    if list.indices.contains(target.index) {
                        list[target.index] = updated
                        onUpdate(list)
                    }
                    editingIndex = nil
                },
                onDelete: {
                    var list = state.guests
                    if list.indices.contains(target.index) {
                        list.remove(at: target.index)
                        onUpdate(list)
                    }
                    editingIndex = nil
                },
                onCancel: {
                    editingIndex = nil
                }
            )
        }
    }

    private struct EditingTarget: Identifiable {
        let index: Int
        let guest: ImportedGuest
        var id: Int { index }
    }

    private func parsedGuestRow(_ g: ImportedGuest, index: Int) -> some View {
        let match = matchType(for: g)
        let diffs = diffFields(for: g, match: match)
        return Button {
            editingIndex = index
        } label: {
            HStack(spacing: 12) {
                Avatar(
                    name: g.firstName.isEmpty ? g.lastName : g.firstName + " " + g.lastName,
                    size: 32,
                    tag: .family,
                    diet: dietBadge(for: g)
                )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(displayName(g))
                            .font(.system(size: 13.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink)
                        matchBadge(for: match)
                    }
                    Text(detailLine(g))
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineLimit(2)
                    if !diffs.isEmpty {
                        diffStrip(diffs)
                    }
                }
                Spacer()
                Image(systemName: "pencil")
                    .font(.system(size: 11))
                    .foregroundStyle(Tokens.Colors.ink4)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Tokens.Colors.bg2)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func diffFields(for g: ImportedGuest, match: ImportMatcher.MatchType) -> [ImportDiffField] {
        guard match == .updateBySource,
              let existing = ImportMatcher.findExisting(guest: g, in: row, among: existingGuests) else {
            return []
        }
        return ImportMatcher.diff(parsed: g, existing: existing)
    }

    @ViewBuilder
    private func diffStrip(_ diffs: [ImportDiffField]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(diffs, id: \.label) { d in
                HStack(spacing: 4) {
                    Text(d.label + ":")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Text(d.oldValue)
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Text(d.newValue)
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.sage)
                }
                .lineLimit(1)
            }
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private func matchBadge(for match: ImportMatcher.MatchType) -> some View {
        switch match {
        case .new:
            EmptyView()
        case .updateBySource:
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 9))
                Text("wird aktualisiert")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Tokens.Colors.sage)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Tokens.Colors.sageTint)
            .clipShape(Capsule())
        case .nameMatchOnly:
            HStack(spacing: 3) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 9))
                Text("Name existiert schon — neu anlegen")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(Tokens.Colors.warn)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Tokens.Colors.warnSoft)
            .clipShape(Capsule())
        }
    }

    private func displayName(_ g: ImportedGuest) -> String {
        let combined = "\(g.firstName) \(g.lastName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? "(Name fehlt)" : combined
    }

    private func detailLine(_ g: ImportedGuest) -> String {
        var parts: [String] = []
        parts.append(g.dietaryChoice)
        if !g.intolerances.isEmpty {
            parts.append("Allergie: " + g.intolerances.joined(separator: ", "))
        }
        if g.ageCategory != .adult {
            parts.append(g.ageCategory.rawValue)
        }
        if !g.tagNames.isEmpty {
            let tags = g.tagNames.prefix(3).joined(separator: ", ")
            let suffix = g.tagNames.count > 3 ? " +\(g.tagNames.count - 3)" : ""
            parts.append("Tags: " + tags + suffix)
        }
        if !g.funFact.isEmpty {
            let fact = g.funFact.count > 60 ? String(g.funFact.prefix(60)) + "…" : g.funFact
            parts.append("\u{201E}" + fact + "\u{201C}")
        }
        return parts.joined(separator: " · ")
    }

    private func dietBadge(for g: ImportedGuest) -> Avatar.DietBadge? {
        if !g.intolerances.isEmpty { return .allergie }
        switch g.dietaryChoice.lowercased() {
        case "vegetarisch": return .veg
        case "vegan": return .vegan
        default: return nil
        }
    }
}

// MARK: - Edit Sheet

private struct ImportGuestEditSheet: View {
    let guest: ImportedGuest
    let onSave: (ImportedGuest) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var dietaryChoice: String = "Fleisch"
    @State private var intolerancesText: String = ""
    @State private var funFact: String = ""
    @State private var isChild: Bool = false
    @State private var selectedTagNames: Set<String> = []
    @State private var newTagInput: String = ""

    private static let dietaryOptions = ["Fleisch", "Vegetarisch", "Vegan"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Gast bearbeiten")
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Korrigier was die KI falsch zusammengebaut hat — Vor- und Nachname, Menü, Allergien, Fun Fact.")
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        labeledField("Vorname") {
                            TextField("Anna", text: $firstName)
                                .textFieldStyle(.roundedBorder)
                        }
                        labeledField("Nachname") {
                            TextField("Müller", text: $lastName)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    labeledField("Menüwahl") {
                        Picker("", selection: $dietaryChoice) {
                            ForEach(Self.dietaryOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    labeledField("Unverträglichkeiten") {
                        TextField("Komma-getrennt, z.B. Nüsse, Laktose", text: $intolerancesText)
                            .textFieldStyle(.roundedBorder)
                    }

                    labeledField("Fun Fact") {
                        TextField("z.B. Hat einmal einen Yoga-Kurs für Hunde besucht", text: $funFact, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                    }

                    labeledField("Tags") {
                        VStack(alignment: .leading, spacing: 8) {
                            // Vorhandene Tags + neu hinzugefügte (lokal noch nicht gespeichert)
                            let combined = combinedTagDisplay
                            if !combined.isEmpty {
                                ChipFlow(spacing: 6) {
                                    ForEach(combined, id: \.self) { name in
                                        tagToggleChip(name: name)
                                    }
                                }
                            }
                            HStack(spacing: 6) {
                                TextField("Neuen Tag hinzufügen…", text: $newTagInput)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 13, design: .rounded))
                                    .onSubmit { addNewTag() }
                                Button {
                                    addNewTag()
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(canAddNewTag ? Tokens.Colors.accent : Tokens.Colors.ink4)
                                }
                                .buttonStyle(.plain)
                                .disabled(!canAddNewTag)
                            }
                        }
                    }

                    Toggle("Ist ein Kind", isOn: $isChild)
                        .font(.system(size: 13, design: .rounded))
                        .padding(.top, 4)
                }
                .padding(24)
            }

            // Footer
            HStack(spacing: 8) {
                Button("Löschen", role: .destructive) {
                    onDelete()
                }
                .warmButton(.ghost)
                Spacer()
                Button("Abbrechen") { onCancel() }
                    .warmButton(.secondary)
                    .keyboardShortcut(.cancelAction)
                Button {
                    save()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Speichern")
                    }
                }
                .warmButton(.primary)
                .keyboardShortcut(.defaultAction)
                .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Tokens.Colors.bg2)
            .overlay(alignment: .top) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }
        }
        .frame(width: 560, height: 580)
        .background(Tokens.Colors.surface)
        .onAppear {
            firstName = guest.firstName
            lastName = guest.lastName
            dietaryChoice = guest.dietaryChoice
            intolerancesText = guest.intolerances.joined(separator: ", ")
            funFact = guest.funFact
            isChild = guest.ageCategory != .adult
            selectedTagNames = Set(guest.tagNames)
        }
    }

    private var combinedTagDisplay: [String] {
        // Bestehende DB-Tags + neue lokal gewählte, alphabetisch
        let existing = allTags.map(\.name)
        let union = Set(existing).union(selectedTagNames)
        return union.sorted()
    }

    private var canAddNewTag: Bool {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }

    private func addNewTag() {
        let trimmed = newTagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedTagNames.insert(trimmed)
        newTagInput = ""
    }

    @ViewBuilder
    private func tagToggleChip(name: String) -> some View {
        let isSelected = selectedTagNames.contains(name)
        let kind: TagChip.Kind = tagKind(for: name)
        Button {
            if isSelected {
                selectedTagNames.remove(name)
            } else {
                selectedTagNames.insert(name)
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(kind.dotColor)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .medium : .regular, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Tokens.Colors.accent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(isSelected ? Tokens.Colors.accentSoft : Tokens.Colors.bg2)
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Tokens.Colors.accent.opacity(0.3) : Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func tagKind(for name: String) -> TagChip.Kind {
        if let existing = allTags.first(where: { $0.name.lowercased() == name.lowercased() }) {
            switch existing.category {
            case .family: return .family
            case .friendGroup: return .friends
            case .role: return .role
            case .activity: return .activity
            case .work: return .work
            case .custom: return .custom
            }
        }
        // Heuristik für lokal neu angelegte Tags
        let lower = name.lowercased()
        if lower.contains("familie") || lower.contains("familien") { return .family }
        if lower.contains("trauzeug") { return .role }
        return .custom
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.4)
            content()
        }
    }

    private func save() {
        let intolerances = intolerancesText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let updated = ImportedGuest(
            firstName: firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            lastName: lastName.trimmingCharacters(in: .whitespacesAndNewlines),
            dietaryChoice: dietaryChoice,
            intolerances: intolerances,
            ageCategory: isChild ? .child : .adult,
            funFact: funFact.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: "",
            tagNames: Array(selectedTagNames)
        )
        onSave(updated)
    }
}

// MARK: - Chip Flow Layout

private struct ChipFlow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if rowWidth + s.width > width, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
        totalHeight += rowHeight
        return CGSize(width: width.isFinite ? width : rowWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

// MARK: - Safe array access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
