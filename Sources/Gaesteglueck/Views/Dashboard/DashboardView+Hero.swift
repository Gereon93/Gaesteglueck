#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

extension DashboardView {
    var dashboardSubtitle: String {
        if let days = daysUntilWedding {
            return days >= 0 ? "Noch \(days) Tage bis zur Hochzeit" : "Vor \(-days) Tagen war die Hochzeit"
        }
        return "Datum noch offen"
    }

    func heroCard(for event: Event) -> some View {
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

    func daysCounter(days: Int) -> some View {
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

    var heroSubtitle: String {
        guard !attendingGuests.isEmpty else {
            return "Lass uns mit den ersten Anmeldungen anfangen — sobald die Gästeliste steht, planen wir gemeinsam die Tische."
        }
        let percent = Int((Double(seatedGuestCount) / Double(attendingGuests.count)) * 100)
        return "Ihr seid auf gutem Weg. \(percent) % der zugesagten Gäste haben einen Tisch."
    }

    func heroDateLine(_ event: Event) -> String {
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
}
#endif
