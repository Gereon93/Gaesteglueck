#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S2 — Dashboard (siehe design_handoff_gaesteglueck → S2). Hero-Karte mit
/// Couple-Name + Tage-Counter, vier Stat-Cards in einer Reihe, dann die
/// "Was als nächstes"-Karte mit Empfehlungen und die Caterer-Vorschau mit
/// Menüwahl-Metern. Wenn noch kein Event existiert, zeigt der Empty-State
/// das Welcome-Onboarding an.
struct DashboardView: View {
    @Environment(\.modelContext) var modelContext
    @Query var events: [Event]
    @Query var guests: [Guest]
    @Query var tables: [GuestTable]
    @Query var tags: [Tag]
    @State var showingEventSetup = false
    @Binding var selection: AppSection?

    init(selection: Binding<AppSection?>) {
        self._selection = selection
    }

    var event: Event? { events.first }

    var attendingGuests: [Guest] {
        guests.filter(\.countsForSeating)
    }

    var seatedGuestCount: Int {
        attendingGuests.filter { $0.table != nil }.count
    }

    var awaitingSeatCount: Int {
        guests.filter(\.awaitsSeating).count
    }

    var allergyCount: Int {
        attendingGuests.filter(\.hasIntolerances).count
    }

    var registrationGroupCount: Int {
        Set(guests.map { $0.registrationGroup }).count
    }

    var daysUntilWedding: Int? {
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
#endif
