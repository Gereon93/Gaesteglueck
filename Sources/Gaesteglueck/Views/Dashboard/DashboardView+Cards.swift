#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

extension DashboardView {
    // MARK: - Stat-Grid

    var statGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 4), spacing: 16) {
            GGStatCard(
                icon: "doc.text",
                label: "Anmeldungen",
                value: "\(registrationGroupCount)",
                hint: registrationGroupCount > 0 ? "\(guests.count) Gäste insgesamt" : nil,
                tint: .rose
            )
            GGStatCard(
                icon: "person.2",
                label: "Gäste",
                value: "\(guests.count)",
                hint: guestBreakdown,
                tint: .sage
            )
            GGStatCard(
                icon: "square.grid.3x3",
                label: "Plätze vergeben",
                value: "\(seatedGuestCount)",
                hint: attendingGuests.isEmpty ? nil : "von \(attendingGuests.count) — \(awaitingSeatCount) offen",
                tint: .sand
            )
            GGStatCard(
                icon: "exclamationmark.triangle",
                label: "Allergien",
                value: "\(allergyCount)",
                hint: allergyCount > 0 ? allergyHint : nil,
                tint: .sky
            )
        }
    }

    var guestBreakdown: String? {
        guard !guests.isEmpty else { return nil }
        let adults = guests.filter { $0.ageCategory == .adult }.count
        let kids = guests.count - adults
        if kids > 0 {
            return "\(adults) Erwachsene · \(kids) Kinder"
        }
        return nil
    }

    var allergyHint: String? {
        let allergic = attendingGuests.filter(\.hasIntolerances)
        guard !allergic.isEmpty else { return nil }
        let allTokens = allergic.flatMap { $0.intolerances }
        let counts = Dictionary(grouping: allTokens, by: { $0 }).mapValues(\.count)
        let top = counts.sorted { $0.value > $1.value }.prefix(3)
        return top.map { "\($0.value) \($0.key)" }.joined(separator: " · ")
    }

    // MARK: - Bottom Cards

    var bottomCards: some View {
        HStack(alignment: .top, spacing: 20) {
            nextStepCard
                .frame(maxWidth: .infinity)
            catererPreviewCard
                .frame(width: 320)
        }
    }

    var nextStepCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WAS ALS NÄCHSTES")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                Text(nextStepTitle)
                    .font(Tokens.Typography.displayS)
                    .foregroundStyle(Tokens.Colors.ink)
                Text(nextStepBody)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineSpacing(4)
                    .padding(.top, 2)

                HStack(spacing: 8) {
                    Button {
                        selection = nextStepTarget
                    } label: {
                        HStack(spacing: 6) {
                            Text(nextStepCTA)
                            Image(systemName: "arrow.right")
                        }
                    }
                    .warmButton(.primary)

                    Button("Später") { }
                        .warmButton(.secondary)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)

            Divider().background(Tokens.Colors.line)

            VStack(alignment: .leading, spacing: 0) {
                Text("EMPFEHLUNGEN")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                    .padding(.bottom, 8)

                ForEach(recommendations.indices, id: \.self) { index in
                    let rec = recommendations[index]
                    RecommendationRow(icon: rec.icon, title: rec.title, message: rec.message)
                    if index < recommendations.count - 1 {
                        Divider().background(Tokens.Colors.line)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
    }

    var nextStepTitle: String {
        if guests.isEmpty { return "Lade die ersten Anmeldungen rein" }
        if tables.isEmpty { return "Wie viele Tische habt ihr im Saal?" }
        if awaitingSeatCount > 0 {
            return "\(awaitingSeatCount) Gäste warten auf einen Platz"
        }
        return "Alle Gäste haben einen Tisch — Zeit für die Tischkarten."
    }

    var nextStepBody: String {
        if guests.isEmpty { return "Aus Google Sheets oder einer Excel-Datei. Die KI parst die Anmeldungen für euch." }
        if tables.isEmpty { return "Form, Größe und Platzierung — alles im Raumplan." }
        if awaitingSeatCount > 0 {
            return "Lass die KI einen ersten Vorschlag machen oder zieh die Gäste manuell auf den Plan."
        }
        return "Druckfertig: Tischkarten mit Name + Fun Fact, Plakat für den Saal, PDF für den Caterer."
    }

    var nextStepCTA: String {
        if guests.isEmpty { return "Anmeldungen prüfen" }
        if tables.isEmpty { return "Tische einrichten" }
        return "Sitzplan öffnen"
    }

    var nextStepTarget: AppSection {
        if guests.isEmpty { return .guests }
        if tables.isEmpty { return .tables }
        return .tables
    }

    struct RecommendationData {
        let icon: String
        let title: String
        let message: String
    }

    var recommendations: [RecommendationData] {
        var recs: [RecommendationData] = []
        if allergyCount > 0 {
            recs.append(.init(
                icon: "exclamationmark.triangle.fill",
                title: "Allergien im Caterer-Export markieren",
                message: "\(allergyCount) Gäste haben Unverträglichkeiten — die werden im PDF rot hervorgehoben."
            ))
        }
        if !guests.isEmpty && tags.isEmpty {
            recs.append(.init(
                icon: "wand.and.stars",
                title: "Beziehungen pflegen",
                message: "Tags helfen der KI dabei, sinnvolle Tischgruppen zu finden."
            ))
        }
        if guests.count > 80 && tables.isEmpty {
            recs.append(.init(
                icon: "square.grid.3x3",
                title: "Tisch-Inventar einrichten",
                message: "Bei \(guests.count) Gästen empfehlen wir 8–14 Tische im Hauptraum."
            ))
        }
        if recs.isEmpty {
            recs.append(.init(
                icon: "sparkles",
                title: "Nichts dringendes",
                message: "Ihr seid auf Kurs. Schau gerne nochmal in die Beziehungen."
            ))
        }
        return Array(recs.prefix(3))
    }

    var catererPreviewCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CATERER-VORSCHAU")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                Text("Menüwahl")
                    .font(Tokens.Typography.displayXS)
                    .foregroundStyle(Tokens.Colors.ink)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().background(Tokens.Colors.line)

            VStack(spacing: 12) {
                ForEach(menuMeters, id: \.label) { meter in
                    DashboardMeter(
                        label: meter.label,
                        count: meter.count,
                        total: max(attendingGuests.count, 1),
                        color: meter.color
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider().background(Tokens.Colors.line)

            HStack {
                Button {
                    selection = .tables
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                        Text("Caterer-PDF exportieren")
                    }
                }
                .warmButton(.ghost)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
    }

    struct MenuMeterData {
        let label: String
        let count: Int
        let color: Color
    }

    var menuMeters: [MenuMeterData] {
        let grouped = Dictionary(grouping: attendingGuests, by: \.dietaryChoice).mapValues(\.count)
        let known = ["Fleisch", "Vegetarisch", "Vegan"]
        var result: [MenuMeterData] = []
        for choice in known {
            let count = grouped[choice] ?? 0
            let color: Color = switch choice {
            case "Fleisch": Color(hex: "#b88a5c")
            case "Vegetarisch": Tokens.Colors.dietVegetarian
            case "Vegan": Tokens.Colors.dietVegan
            default: Tokens.Colors.ink4
            }
            result.append(.init(label: choice, count: count, color: color))
        }
        let undefined = attendingGuests.filter { !known.contains($0.dietaryChoice) }.count
        if undefined > 0 {
            result.append(.init(label: "Noch offen", count: undefined, color: Tokens.Colors.ink4))
        }
        return result
    }
}
#endif
