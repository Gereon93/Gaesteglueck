#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S2 — Dashboard (siehe design_handoff_gaesteglueck → S2). Hero-Karte mit
/// Couple-Name + Tage-Counter, vier Stat-Cards in einer Reihe, dann die
/// "Was als nächstes"-Karte mit Empfehlungen und die Caterer-Vorschau mit
/// Menüwahl-Metern. Wenn noch kein Event existiert, zeigt der Empty-State
/// das Welcome-Onboarding an.
struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var tags: [Tag]
    @State private var showingEventSetup = false
    @Binding var selection: AppSection?

    init(selection: Binding<AppSection?>) {
        self._selection = selection
    }

    private var event: Event? { events.first }

    private var attendingGuests: [Guest] {
        guests.filter(\.countsForSeating)
    }

    private var seatedGuestCount: Int {
        attendingGuests.filter { $0.table != nil }.count
    }

    private var awaitingSeatCount: Int {
        guests.filter(\.awaitsSeating).count
    }

    private var allergyCount: Int {
        attendingGuests.filter(\.hasIntolerances).count
    }

    private var registrationGroupCount: Int {
        Set(guests.map { $0.registrationGroup }).count
    }

    private var daysUntilWedding: Int? {
        guard let date = event?.date else { return nil }
        let cal = Calendar.current
        let start = cal.startOfDay(for: .now)
        let end = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: start, to: end).day
    }

    var body: some View {
        ZStack {
            Tokens.Colors.bg.ignoresSafeArea()

            if let event {
                dashboard(for: event)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showingEventSetup) {
            OnboardingWizardView()
        }
    }

    // MARK: - Dashboard mit Event

    private func dashboard(for event: Event) -> some View {
        VStack(spacing: 0) {
            toolbar(for: event)
            ScrollView {
                VStack(spacing: 24) {
                    heroCard(for: event)
                    statGrid
                    bottomCards
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func toolbar(for event: Event) -> some View {
        ScreenToolbar(
            title: "Dashboard",
            subtitle: dashboardSubtitle
        ) {
            Button {
                selection = .guests
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc")
                    Text("Anmeldungen importieren")
                }
            }
            .warmButton(.primary)
        }
    }

    private var dashboardSubtitle: String {
        if let days = daysUntilWedding {
            return days >= 0 ? "Noch \(days) Tage bis zur Hochzeit" : "Vor \(-days) Tagen war die Hochzeit"
        }
        return "Datum noch offen"
    }

    private func heroCard(for event: Event) -> some View {
        ZStack(alignment: .topLeading) {
            // Layered Gradient (gleiche Sprache wie der Onboarding-Hintergrund):
            // sanfte Diagonale + radiale Wärme links oben + zarte Beige-Note
            // rechts. Bewusst KEIN Wave-Pattern — das wirkte unruhig.
            LinearGradient(
                colors: [Tokens.Colors.accentTint, Color(hex: "#f7eddb")],
                startPoint: UnitPoint(x: 0, y: 0.32),
                endPoint: UnitPoint(x: 1, y: 0.68)
            )
            RadialGradient(
                colors: [Tokens.Colors.accent.opacity(0.18), .clear],
                center: UnitPoint(x: 0.12, y: 0.2),
                startRadius: 0,
                endRadius: 320
            )
            RadialGradient(
                colors: [Color(hex: "#f4d9b6").opacity(0.35), .clear],
                center: UnitPoint(x: 0.92, y: 0.85),
                startRadius: 0,
                endRadius: 280
            )

            HStack(alignment: .center, spacing: 28) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(heroDateLine(event))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.accent)
                        .tracking(1)
                    HStack(spacing: 0) {
                        Text(event.partnerDisplayName1)
                            .font(Tokens.Typography.display(size: 38))
                            .tracking(-0.6)
                            .foregroundStyle(Tokens.Colors.ink)
                        Text(" & ")
                            .font(Tokens.Typography.display(size: 38, italic: true))
                            .tracking(-0.6)
                            .foregroundStyle(Tokens.Colors.accent)
                        Text(event.partnerDisplayName2)
                            .font(Tokens.Typography.display(size: 38))
                            .tracking(-0.6)
                            .foregroundStyle(Tokens.Colors.ink)
                    }
                    .lineLimit(1)
                    .padding(.top, 6)
                    Text(heroSubtitle)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .padding(.top, 10)
                        .frame(maxWidth: 460, alignment: .leading)
                }
                Spacer(minLength: 0)
                if let days = daysUntilWedding, days >= 0 {
                    daysCounter(days: days)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
    }

    private func daysCounter(days: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(days)")
                .font(Tokens.Typography.display(size: 28, weight: .medium))
                .foregroundStyle(Tokens.Colors.accent)
                .monospacedDigit()
            Text("Tage")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.5)
        }
        .frame(width: 88, height: 88)
        .background(Tokens.Colors.surface)
        .clipShape(Circle())
        .cardShadow()
    }

    private var heroSubtitle: String {
        guard !attendingGuests.isEmpty else {
            return "Lass uns mit den ersten Anmeldungen anfangen — sobald die Gästeliste steht, planen wir gemeinsam die Tische."
        }
        let percent = Int((Double(seatedGuestCount) / Double(attendingGuests.count)) * 100)
        return "Ihr seid auf gutem Weg. \(percent) % der zugesagten Gäste haben einen Tisch."
    }

    private func heroDateLine(_ event: Event) -> String {
        var parts: [String] = []
        if let date = event.date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.locale = Locale(identifier: "de_DE")
            parts.append(fmt.string(from: date))
        }
        if !event.venue.isEmpty {
            parts.append(event.venue)
        }
        return parts.joined(separator: " · ").uppercased()
    }

    // MARK: - Stat-Grid

    private var statGrid: some View {
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

    private var guestBreakdown: String? {
        guard !guests.isEmpty else { return nil }
        let adults = guests.filter { $0.ageCategory == .adult }.count
        let kids = guests.count - adults
        if kids > 0 {
            return "\(adults) Erwachsene · \(kids) Kinder"
        }
        return nil
    }

    private var allergyHint: String? {
        let allergic = attendingGuests.filter(\.hasIntolerances)
        guard !allergic.isEmpty else { return nil }
        let allTokens = allergic.flatMap { $0.intolerances }
        let counts = Dictionary(grouping: allTokens, by: { $0 }).mapValues(\.count)
        let top = counts.sorted { $0.value > $1.value }.prefix(3)
        return top.map { "\($0.value) \($0.key)" }.joined(separator: " · ")
    }

    // MARK: - Bottom Cards

    private var bottomCards: some View {
        HStack(alignment: .top, spacing: 20) {
            nextStepCard
                .frame(maxWidth: .infinity)
            catererPreviewCard
                .frame(width: 320)
        }
    }

    private var nextStepCard: some View {
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

    private var nextStepTitle: String {
        if guests.isEmpty { return "Lade die ersten Anmeldungen rein" }
        if tables.isEmpty { return "Wie viele Tische habt ihr im Saal?" }
        if awaitingSeatCount > 0 {
            return "\(awaitingSeatCount) Gäste warten auf einen Platz"
        }
        return "Alle Gäste haben einen Tisch — Zeit für die Tischkarten."
    }

    private var nextStepBody: String {
        if guests.isEmpty { return "Aus Google Sheets oder einer Excel-Datei. Die KI parst die Anmeldungen für euch." }
        if tables.isEmpty { return "Form, Größe und Platzierung — alles im Raumplan." }
        if awaitingSeatCount > 0 {
            return "Lass die KI einen ersten Vorschlag machen oder zieh die Gäste manuell auf den Plan."
        }
        return "Druckfertig: Tischkarten mit Name + Fun Fact, Plakat für den Saal, PDF für den Caterer."
    }

    private var nextStepCTA: String {
        if guests.isEmpty { return "Anmeldungen prüfen" }
        if tables.isEmpty { return "Tische einrichten" }
        return "Sitzplan öffnen"
    }

    private var nextStepTarget: AppSection {
        if guests.isEmpty { return .guests }
        if tables.isEmpty { return .tables }
        return .tables
    }

    private struct RecommendationData {
        let icon: String
        let title: String
        let message: String
    }

    private var recommendations: [RecommendationData] {
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

    private var catererPreviewCard: some View {
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

    private struct MenuMeterData {
        let label: String
        let count: Int
        let color: Color
    }

    private var menuMeters: [MenuMeterData] {
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

    // MARK: - Empty State (vor erstem Event)

    private var emptyState: some View {
        EmptyStateCard(
            icon: "heart.circle.fill",
            title: "Willkommen bei Gästeglück",
            message: "Lass uns mit eurem Hochzeitsdatum anfangen. Wir brauchen nur ein paar Eckdaten — Namen, Datum, Location — und können loslegen.",
            variant: .warm
        ) {
            Button {
                showingEventSetup = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Event einrichten")
                }
            }
            .warmButton(.primary, size: .lg)
        }
        .padding(40)
    }
}

// MARK: - Recommendation Row

private struct RecommendationRow: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Tokens.Colors.accentTint)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text(message)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Meter

private struct DashboardMeter: View {
    let label: String
    let count: Int
    let total: Int
    let color: Color

    private var percent: Double { total > 0 ? Double(count) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Tokens.Colors.bg2)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(color)
                        .frame(width: max(2, geo.size.width * percent), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
#endif
