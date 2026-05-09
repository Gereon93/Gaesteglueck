#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S1 — Willkommen / Onboarding (siehe design_handoff_gaesteglueck → S1).
/// Vollbild-Karte mit weichem Akzent-Wash von oben, ein kombiniertes
/// Namensfeld "Anna & Ben" plus Datum + Location. CTA "Loslegen" legt das
/// Event an.
struct OnboardingWizardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isPresented) private var isPresented
    @Query private var existingEvents: [Event]

    @State private var partner1Name: String = ""
    @State private var partner2Name: String = ""
    @State private var venue: String = ""
    @State private var date: Date = .now
    @State private var hasDate: Bool = true

    @FocusState private var focusedField: WelcomeField?

    enum WelcomeField: Hashable { case partner1, partner2, venue }

    private var canDismissWithoutSaving: Bool {
        !existingEvents.isEmpty
    }

    private var canSubmit: Bool {
        !partner1Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !partner2Name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var eventDisplayName: String {
        let p1 = partner1Name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = partner2Name.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Hochzeit \(p1) & \(p2)"
    }

    var body: some View {
        ZStack {
            // Sanfter Akzent-Wash, oben warm-rosa zu unten parchment
            backgroundLayer

            VStack(spacing: 0) {
                Spacer()
                welcomeCard
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 720, minHeight: 720)
        .task {
            // Cursor direkt ins erste Namensfeld nach Layout
            try? await Task.sleep(nanoseconds: 200_000_000)
            focusedField = .partner1
        }
    }

    private var backgroundLayer: some View {
        GeometryReader { geo in
            ZStack {
                Tokens.Colors.bg
                LinearGradient(
                    gradient: Gradient(stops: [
                        .init(color: Tokens.Colors.accentTint, location: 0),
                        .init(color: Tokens.Colors.accentTint.opacity(0.45), location: 0.35),
                        .init(color: Color.clear, location: 0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    gradient: Gradient(colors: [
                        Tokens.Colors.accentTint.opacity(0.6),
                        Color.clear
                    ]),
                    center: UnitPoint(x: 0.5, y: 0),
                    startRadius: 0,
                    endRadius: max(geo.size.width * 0.6, 600)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private var welcomeCard: some View {
        VStack(spacing: 0) {
            // Hero-Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Tokens.Colors.surface)
                    .frame(width: 56, height: 56)
                    .floatingShadow()
                Image(systemName: "ring.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            .padding(.bottom, 28)

            // Headline
            VStack(spacing: 0) {
                Text("Willkommen bei")
                    .font(Tokens.Typography.display(size: 44))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Gästeglück.")
                    .font(Tokens.Typography.display(size: 44, italic: true))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            .multilineTextAlignment(.center)

            // Subtitle
            Text("Wir helfen euch beim Sitzplan — vom ersten Rücklauf bis zur Tischkarte am Tag davor. Alles bleibt auf eurem Mac.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .lineSpacing(4)
                .padding(.top, 18)

            // Eingabefelder — zwei Namensfelder mit italic-rotem & dazwischen,
            // dann Datum + Location nebeneinander.
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Wie heißt ihr beide?")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)

                    HStack(spacing: 12) {
                        TextField("Anna", text: $partner1Name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, design: .rounded))
                            .focused($focusedField, equals: .partner1)
                        Text("&")
                            .font(Tokens.Typography.display(size: 18, italic: true))
                            .foregroundStyle(Tokens.Colors.accent)
                        TextField("Ben", text: $partner2Name)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, design: .rounded))
                            .focused($focusedField, equals: .partner2)
                    }

                    Text("Wird auf Karten und im Export verwendet")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Hochzeitsdatum")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                        if hasDate {
                            DatePicker("", selection: $date, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .font(.system(size: 14, design: .rounded))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Button("Datum hinzufügen") { hasDate = true }
                                .buttonStyle(.plain)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                        TextField("Gut Hohenholz", text: $venue)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 14, design: .rounded))
                            .focused($focusedField, equals: .venue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 520)
            .padding(.top, 36)

            // CTA-Buttons
            HStack(spacing: 10) {
                if canDismissWithoutSaving && isPresented {
                    Button("Später") { dismiss() }
                        .warmButton(.ghost)
                }
                Button {
                    createEvent()
                    // Nie dismiss() im Root-Kontext — das würde das Fenster
                    // schließen. ContentView's `if events.isEmpty` swap't
                    // automatisch auf die Main-View, sobald das Event da ist.
                    // Im Sheet-Kontext (von Settings → Bearbeiten) brauchen
                    // wir auch kein dismiss, weil dort EventSetupView läuft.
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                        Text("Loslegen")
                    }
                }
                .warmButton(.primary, size: .lg)
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.5)
            }
            .padding(.top, 28)

            // Privacy
            HStack(spacing: 6) {
                Circle()
                    .fill(Tokens.Colors.sage)
                    .frame(width: 6, height: 6)
                Text("Lokal · Kein Account · Keine Telemetrie")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            .padding(.top, 22)
        }
        .frame(width: 520)
    }

    private func createEvent() {
        let p1 = partner1Name.trimmingCharacters(in: .whitespacesAndNewlines)
        let p2 = partner2Name.trimmingCharacters(in: .whitespacesAndNewlines)

        let event = Event(
            name: eventDisplayName,
            date: hasDate ? date : nil,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines),
            partner1Name: p1,
            partner2Name: p2
        )
        modelContext.insert(event)

        // Brautpaar als Gäste — defensiv: kein inline fetch, einfach insert.
        // Doppel-Tags / Doppel-Constraints können später im Beziehungs-Wizard
        // bereinigt werden falls der User Onboarding mehrmals durchläuft.
        let group = UUID()

        let g1 = Guest(
            firstName: p1,
            lastName: "",
            partnerAssignment: .partner1,
            ageCategory: .adult,
            dietaryChoice: "Fleisch",
            funFact: "",
            notes: "",
            registrationGroup: group
        )
        modelContext.insert(g1)

        let g2 = Guest(
            firstName: p2,
            lastName: "",
            partnerAssignment: .partner2,
            ageCategory: .adult,
            dietaryChoice: "Fleisch",
            funFact: "",
            notes: "",
            registrationGroup: group
        )
        modelContext.insert(g2)

        let tag = Tag(name: "Brautpaar", category: .role)
        tag.guestIDs = [g1.id, g2.id]
        modelContext.insert(tag)

        let constraint = Constraint(
            type: .mustSitTogether,
            guestIDs: [g1.id, g2.id],
            reason: "Brautpaar"
        )
        modelContext.insert(constraint)
    }
}
#endif
