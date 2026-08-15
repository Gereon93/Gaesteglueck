#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

extension TagGeneratorView {
    // MARK: Input Stage

    var inputStage: some View {
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
                    generateTask = Task { await generate() }
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
    var inputContextHint: some View {
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

    func partnerInput(name: String, hint: Binding<String>, placeholder: String) -> some View {
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

    var reviewStage: some View {
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

    var familySkipBanner: some View {
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

    func proposalCard(proposal: Binding<ProposedTag>) -> some View {
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

    func categoryChip(_ cat: TagCategory) -> some View {
        Text(cat.rawValue)
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: cat.defaultColor).opacity(0.18))
            .foregroundStyle(Color(hex: cat.defaultColor))
            .clipShape(Capsule())
    }

    func sideChip(_ pa: PartnerAssignment) -> some View {
        Text(pa.displayName(for: event))
            .font(.system(size: 10.5, weight: .medium, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(pa.color.opacity(0.18))
            .foregroundStyle(pa.color)
            .clipShape(Capsule())
    }

    // MARK: Apply Bar

    var applyBar: some View {
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
}
#endif
