#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Auto-Tag-Generator mit Chat-artiger Eingabe pro Partner.
/// LLM erzeugt Tag-Vorschläge UND ordnet bestehende Gäste zu — der User
/// kann pro Vorschlag entscheiden ob er übernehmen will, dann fügt ein Klick
/// alle Tags inkl. Mitgliederliste an.
struct TagGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var existingTags: [Tag]
    @Query private var events: [Event]

    @State private var partner1Hint = ""
    @State private var partner2Hint = ""
    @State private var isGenerating = false
    @State private var proposals: [ProposedTag] = []
    @State private var errorMessage: String?
    @State private var hasGenerated = false
    @State private var rawDebugResponse: String? = nil
    @State private var showingRawDebug = false
    @State private var useAIForAssignment: Bool = false
    @State private var skippedFamilyTerms: [String] = []

    private var event: Event? { events.first }
    private var partner1Name: String { event?.partnerDisplayName1 ?? "Partner 1" }
    private var partner2Name: String { event?.partnerDisplayName2 ?? "Partner 2" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Tokens.Colors.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if proposals.isEmpty {
                        inputStage
                    } else {
                        reviewStage
                    }
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if !proposals.isEmpty {
                Divider().background(Tokens.Colors.line)
                applyBar
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(Tokens.Colors.bg)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tags automatisch generieren")
                    .font(Tokens.Typography.display(size: 22))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Beschreibe wen ihr eingeladen habt — die KI legt die Tags an und ordnet die Gäste zu.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer()
            Button("Schließen") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    // MARK: Input Stage

    private var inputStage: some View {
        VStack(alignment: .leading, spacing: 18) {
            inputContextHint
            partnerInput(name: partner1Name, hint: $partner1Hint, placeholder: "z.B. Realschulfreunde, Kommilitonen, Wohnheim, Trauzeugen, JGA, Berufsschulfreunde, Familienfreunde")
            partnerInput(name: partner2Name, hint: $partner2Hint, placeholder: "z.B. Arbeitskolleginnen, Fasching, Reichental, Nachbarschaft, Volleyball, JGA, Familienfreunde")

            if let errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Tokens.Colors.warn)
                        Text(errorMessage)
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if rawDebugResponse != nil {
                            Button(showingRawDebug ? "Roh ausblenden" : "Roh-Antwort anzeigen") {
                                showingRawDebug.toggle()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Colors.accent)
                        }
                    }
                    if showingRawDebug, let raw = rawDebugResponse {
                        ScrollView {
                            Text(raw)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Tokens.Colors.ink2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(maxHeight: 220)
                        .padding(8)
                        .background(Color.white.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.Colors.warn.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 12) {
                Toggle(isOn: $useAIForAssignment) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Gäste per KI zuordnen")
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink)
                        Text(guests.isEmpty ? "Keine Gäste in der DB — KI-Schritt überspringt von selbst." : "Zusätzlicher LM-Studio-Call versucht Gäste den Tags zuzuordnen.")
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                }
                .toggleStyle(.switch)
                .disabled(guests.isEmpty)
                Spacer()
                Button {
                    Task { await generate() }
                } label: {
                    HStack(spacing: 6) {
                        if isGenerating {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(isGenerating ? (useAIForAssignment ? "KI ordnet zu…" : "Berechne…") : "Tags vorschlagen")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Tokens.Colors.accent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isGenerating || (partner1Hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && partner2Hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("So funktioniert's")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.6)
                Text("• Familie (Eltern, Onkel, Cousin, …) wird automatisch aus den Familienrollen befüllt, die du an den Gästen gesetzt hast — kein Doppelpflegen.\n• JGA in beiden Listen → zwei separate Tags pro Seite.\n• Familienfreunde/Nachbarn in beiden → ein gemeinsamer 'beide'-Tag.\n• Freundeskreise (Realschule, Wohnheim, Fasching, …) bleiben erstmal leer und kannst du in der Gästeliste pro Person zuziehen.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    /// Hinweis-Box am Anfang der Eingabe damit der User nicht unnötig
    /// Familie tippt und sich dann wundert dass die Tags fehlen.
    private var inputContextHint: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb")
                .foregroundStyle(Tokens.Colors.accent)
                .font(.system(size: 12))
            Text("Familie nicht doppeln — Eltern/Geschwister/Onkel/Tanten/Cousins werden über die Familienrolle am Gast erfasst (Gast bearbeiten → Familienrolle). Hier eintragen wo's Tags wirklich braucht: **Freundeskreise**, **Aktivitäten**, **Arbeit**, **Hochzeitsrollen**.")
                .font(.system(size: 11.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.accentTint.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func partnerInput(name: String, hint: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Wen hat \(name) eingeladen?")
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
            TextEditor(text: hint)
                .font(.system(size: 13, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 90)
                .background(Tokens.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Tokens.Colors.line, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if hint.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    // MARK: Review Stage

    private var reviewStage: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(proposals.count) Vorschläge")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    Text("Aktiviere/deaktiviere Tags und übernimm dann alle auf einmal.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                Spacer()
                Button("Neu generieren") {
                    proposals = []
                    hasGenerated = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.accent)
            }
            if !skippedFamilyTerms.isEmpty {
                familySkipBanner
            }

            ForEach($proposals) { $proposal in
                proposalCard(proposal: $proposal)
            }
        }
    }

    private var familySkipBanner: some View {
        let preview = skippedFamilyTerms.prefix(5).joined(separator: ", ")
        let suffix = skippedFamilyTerms.count > 5 ? ", …" : ""
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(Tokens.Colors.ink3)
                .font(.system(size: 13))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(skippedFamilyTerms.count) Familien-Begriffe übersprungen")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Familie (Eltern, Onkel/Tante, Geschwister, Cousins) wird über die Familienrolle direkt am Gast erfasst — kein Doppelpflegen nötig. Erkannt: \(preview)\(suffix)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func proposalCard(proposal: Binding<ProposedTag>) -> some View {
        let p = proposal.wrappedValue
        let assignedGuests = guests.filter { p.guestIDs.contains($0.id) }
        let isDuplicate = existingTags.contains(where: {
            $0.name.lowercased() == p.name.lowercased()
                && $0.partnerAssignment == p.partnerAssignment
        })

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Toggle("", isOn: proposal.accepted)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Circle()
                    .fill(Color(hex: p.category.defaultColor))
                    .frame(width: 10, height: 10)
                Text(p.name)
                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Spacer()
                categoryChip(p.category)
                if let pa = p.partnerAssignment {
                    sideChip(pa)
                }
                if isDuplicate {
                    Text("existiert — wird ergänzt")
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.warn)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Tokens.Colors.warn.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            if !p.derivationRule.isEmpty {
                Text("Regel: \(p.derivationRule)")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Tokens.Colors.ink3)
                if assignedGuests.isEmpty {
                    Text("Keine automatische Zuordnung — manuell zuweisen")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                } else {
                    Text("\(assignedGuests.count) Gast\(assignedGuests.count == 1 ? "" : "e"): \(assignedGuests.prefix(4).map(\.fullName).joined(separator: ", "))\(assignedGuests.count > 4 ? "…" : "")")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(p.accepted ? Tokens.Colors.surface : Tokens.Colors.bg2)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(p.accepted ? Tokens.Colors.line : Tokens.Colors.line.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .opacity(p.accepted ? 1 : 0.55)
    }

    private func categoryChip(_ cat: TagCategory) -> some View {
        Text(cat.rawValue)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: cat.defaultColor).opacity(0.18))
            .foregroundStyle(Color(hex: cat.defaultColor))
            .clipShape(Capsule())
    }

    private func sideChip(_ pa: PartnerAssignment) -> some View {
        Text(pa.displayName(for: event))
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pa.color.opacity(0.18))
            .foregroundStyle(pa.color)
            .clipShape(Capsule())
    }

    // MARK: Apply Bar

    private var applyBar: some View {
        let active = proposals.filter(\.accepted)
        let totalAssignments = active.reduce(0) { $0 + $1.guestIDs.count }
        return HStack {
            Text("\(active.count) Tag\(active.count == 1 ? "" : "s") aktiv · \(totalAssignments) Zuordnungen")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            Spacer()
            Button("Alle übernehmen") {
                applyProposals()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(active.isEmpty ? Tokens.Colors.ink4 : Tokens.Colors.accent)
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .disabled(active.isEmpty)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Tokens.Colors.surface)
    }

    // MARK: Generate

    @MainActor
    private func generate() async {
        errorMessage = nil
        rawDebugResponse = nil
        isGenerating = true
        defer { isGenerating = false }

        // Schritt 1: lokal aus dem Freitext Tags ableiten — sofort, ohne KI.
        // Family-Begriffe werden bewusst übersprungen weil sie schon über
        // Guest.familyRole modelliert sind — sonst hätten wir 22 Tags von
        // denen 8 redundant wären.
        let snapshotsForLocal = guests.map { g in
            GuestSnapshot(
                id: g.id,
                fullName: g.fullName,
                partnerAssignment: g.partnerAssignment,
                registrationGroup: g.registrationGroup,
                funFact: g.funFact,
                notes: g.notes,
                profession: g.profession,
                hobbies: g.hobbies,
                familyRole: g.familyRole,
                familyRolePartner: g.familyRolePartner
            )
        }
        let derivation = LocalTagDeriver.derive(
            partner1Name: partner1Name,
            partner2Name: partner2Name,
            partner1Hint: partner1Hint,
            partner2Hint: partner2Hint,
            guests: snapshotsForLocal
        )
        let localResult = derivation.proposals
        skippedFamilyTerms = derivation.skippedFamilyTerms
        guard !localResult.isEmpty else {
            errorMessage = "Keine Tags aus dem Freitext erkannt — bitte mit Komma-getrennten Begriffen probieren."
            return
        }

        // Schritt 2 (optional): KI nutzt die Tags + Gästeliste um Mitglieder zuzuordnen
        if useAIForAssignment, !guests.isEmpty {
            let client = LLMClientFactory.makeFromSettings()
            if let lm = client as? LMStudioClient {
                do {
                    _ = try await lm.checkConnection()
                } catch {
                    proposals = localResult
                    hasGenerated = true
                    errorMessage = "Tags lokal erstellt — KI-Zuordnung übersprungen (LM Studio nicht erreichbar)."
                    return
                }
            }
            let service = TagSuggestionService(client: client)
            let snapshots = snapshotsForLocal
            do {
                let aiResult = try await service.generateWithRaw(
                    partner1Name: partner1Name,
                    partner2Name: partner2Name,
                    partner1Hint: partner1Hint,
                    partner2Hint: partner2Hint,
                    guests: snapshots
                )
                if aiResult.proposals.isEmpty {
                    proposals = localResult
                    errorMessage = "Tags lokal erstellt — KI-Zuordnung lieferte kein verwertbares JSON. Empfehlung: gemma-3-12b verwenden."
                    rawDebugResponse = aiResult.rawResponse
                } else {
                    // Lokal-Tags mit KI-Vorschlägen verheiraten: gleiche
                    // Namen → guestIDs der KI übernehmen.
                    var merged = localResult
                    for ai in aiResult.proposals {
                        if let idx = merged.firstIndex(where: { $0.name.lowercased() == ai.name.lowercased() }) {
                            merged[idx].guestIDs = ai.guestIDs
                        }
                    }
                    proposals = merged
                }
                hasGenerated = true
            } catch {
                proposals = localResult
                errorMessage = "Tags lokal erstellt — KI-Schritt fehlgeschlagen: \(error.localizedDescription)"
                hasGenerated = true
            }
        } else {
            proposals = localResult
            hasGenerated = true
        }
    }

    // MARK: Apply

    private func applyProposals() {
        var affectedTags: [Tag] = []
        for proposal in proposals where proposal.accepted {
            affectedTags.append(applyOne(proposal))
        }
        try? modelContext.save()
        derivePartnerSidesAfterApply(affectedTags: affectedTags)
        dismiss()
    }

    private func derivePartnerSidesAfterApply(affectedTags: [Tag]) {
        let touchedIDs = Set(proposals.filter(\.accepted).flatMap(\.guestIDs))
        let mergedTags = mergeTagSnapshots(existingTags, affectedTags)
        for id in touchedIDs {
            if let g = guests.first(where: { $0.id == id }) {
                PartnerSideDeriver.applyIfUnassigned(g, in: mergedTags, allGuests: guests)
            }
        }
    }

    private func mergeTagSnapshots(_ a: [Tag], _ b: [Tag]) -> [Tag] {
        var seen = Set<UUID>()
        var result: [Tag] = []
        for tag in a + b where !seen.contains(tag.id) {
            seen.insert(tag.id)
            result.append(tag)
        }
        return result
    }

    @discardableResult
    private func applyOne(_ proposal: ProposedTag) -> Tag {
        if let existing = mergeIntoExistingTagIfMatching(proposal) {
            return existing
        }
        return insertNewTag(from: proposal)
    }

    private func mergeIntoExistingTagIfMatching(_ proposal: ProposedTag) -> Tag? {
        guard let existing = existingTags.first(where: {
            $0.name.lowercased() == proposal.name.lowercased()
                && $0.partnerAssignment == proposal.partnerAssignment
        }) else { return nil }
        var union = Set(existing.guestIDs)
        for id in proposal.guestIDs { union.insert(id) }
        existing.guestIDs = Array(union)
        return existing
    }

    private func insertNewTag(from proposal: ProposedTag) -> Tag {
        let tag = Tag(
            name: proposal.name,
            category: proposal.category,
            partnerAssignment: proposal.partnerAssignment
        )
        tag.guestIDs = proposal.guestIDs
        modelContext.insert(tag)
        return tag
    }
}
#endif
