#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Event-Daten — Partnernamen, Datum, Location, Menüoptionen. Öffnet das
/// EventSetup-Sheet zum Bearbeiten.
struct EventCardView: View {
    @Query private var events: [Event]
    @State private var showingEventSetup = false

    private var event: Event? { events.first }

    var body: some View {
        SettingsCard(
            title: "Event-Daten",
            subtitle: "Erscheinen auf jeder PDF-Seite und auf dem Dashboard."
        ) {
            if let event {
                VStack(spacing: 10) {
                    SettingsRow(label: "Partnernamen") {
                        Text("\(event.partnerDisplayName1) & \(event.partnerDisplayName2)")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink)
                    }
                    SettingsRow(label: "Hochzeitsdatum") {
                        if let date = event.date {
                            Text(formatDate(date))
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink)
                        } else {
                            Text("Noch offen")
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                    }
                    SettingsRow(label: "Location") {
                        Text(event.venue.isEmpty ? "Noch offen" : event.venue)
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(event.venue.isEmpty ? Tokens.Colors.ink3 : Tokens.Colors.ink)
                    }
                    SettingsRow(label: "Menüoptionen") {
                        HStack(spacing: 4) {
                            ForEach(event.menuOptions, id: \.self) { option in
                                TagChip(label: option, kind: chipKindFor(menu: option), size: .sm)
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Bearbeiten") { showingEventSetup = true }
                            .warmButton(.secondary, size: .sm)
                    }
                    .padding(.top, 4)
                }
            } else {
                HStack {
                    Text("Noch kein Event eingerichtet.")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Spacer()
                    Button("Event einrichten") { showingEventSetup = true }
                        .warmButton(.primary, size: .sm)
                }
            }
        }
        .sheet(isPresented: $showingEventSetup) {
            EventSetupView()
        }
    }

    private func chipKindFor(menu: String) -> TagChip.Kind {
        switch menu.lowercased() {
        case "vegetarisch", "vegan": .friends
        case "fleisch": .role
        default: .custom
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.locale = Locale(identifier: "de_DE")
        return fmt.string(from: date)
    }
}
#endif
