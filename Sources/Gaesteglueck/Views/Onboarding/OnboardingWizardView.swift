#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct OnboardingWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.name) private var allGuests: [Guest]

    @State private var cards: [OnboardingCard] = []
    @State private var currentIndex = 0

    // Current card answers
    @State private var selectedSide: Side = .neutral
    @State private var selectedGroupType: GroupType?
    @State private var customGroupName = ""
    @State private var selectedFamilyRoles: [UUID: FamilyRole] = [:]
    @State private var mainContactID: UUID?

    private var currentCard: OnboardingCard? {
        guard cards.indices.contains(currentIndex) else { return nil }
        return cards[currentIndex]
    }

    private var progress: Double {
        guard !cards.isEmpty else { return 1 }
        return Double(currentIndex) / Double(cards.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProgressView(value: progress)
                    .padding(.horizontal)

                if let card = currentCard {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // Card header
                            Text(card.displayName)
                                .font(.title2.bold())

                            if card.isFamily {
                                Text("Mitglieder: \(card.guests.map(\.name).joined(separator: ", "))")
                                    .foregroundStyle(.secondary)
                            }

                            // Q1: Side
                            questionSection("Auf welcher Seite?", icon: "person.2") {
                                Picker("Seite", selection: $selectedSide) {
                                    ForEach(Side.allCases) { side in
                                        Text(side.rawValue).tag(side)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }

                            // Q2: Group type
                            questionSection("Wie kennt ihr euch?", icon: "person.3") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 8) {
                                    ForEach(GroupType.allCases) { gt in
                                        Button {
                                            selectedGroupType = gt
                                        } label: {
                                            Text(gt.rawValue)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(selectedGroupType == gt ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                if selectedGroupType == .clubMember {
                                    TextField("Welcher Verein?", text: $customGroupName)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }

                            // Q3: Family roles (for each member)
                            if card.guests.count > 1 {
                                questionSection("Wer ist wer?", icon: "figure.2.and.child") {
                                    ForEach(card.guests) { guest in
                                        HStack {
                                            Text(guest.name)
                                            Spacer()
                                            Picker("Rolle", selection: Binding(
                                                get: { selectedFamilyRoles[guest.id] },
                                                set: { selectedFamilyRoles[guest.id] = $0 }
                                            )) {
                                                Text("—").tag(nil as FamilyRole?)
                                                ForEach(FamilyRole.allCases) { role in
                                                    Text(role.rawValue).tag(role as FamilyRole?)
                                                }
                                            }
                                        }
                                    }
                                }
                            } else {
                                questionSection("Beziehung zum Brautpaar?", icon: "heart") {
                                    Picker("Rolle", selection: Binding(
                                        get: { selectedFamilyRoles[card.guests[0].id] },
                                        set: { selectedFamilyRoles[card.guests[0].id] = $0 }
                                    )) {
                                        Text("Keine Angabe").tag(nil as FamilyRole?)
                                        ForEach(FamilyRole.allCases) { role in
                                            Text(role.rawValue).tag(role as FamilyRole?)
                                        }
                                    }
                                }
                            }

                            // Q4: Main contact person
                            if card.guests.count > 1 {
                                questionSection("Wer ist die Hauptbezugsperson?", icon: "star") {
                                    Text("Wer von dieser Gruppe kennt das Brautpaar am besten?")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(card.guests) { guest in
                                        Button {
                                            mainContactID = guest.id
                                        } label: {
                                            HStack {
                                                Image(systemName: mainContactID == guest.id ? "star.fill" : "star")
                                                Text(guest.name)
                                            }
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                            .background(mainContactID == guest.id ? Color.accentColor.opacity(0.1) : .clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                        .padding()
                    }

                    // Navigation buttons
                    HStack {
                        if currentIndex > 0 {
                            Button("Zurück") {
                                currentIndex -= 1
                                loadCurrentCard()
                            }
                        }
                        Spacer()
                        Text("\(currentIndex + 1) / \(cards.count)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(currentIndex == cards.count - 1 ? "Fertig" : "Weiter") {
                            saveCurrentCard()
                            if currentIndex < cards.count - 1 {
                                currentIndex += 1
                                loadCurrentCard()
                            } else {
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    ContentUnavailableView("Keine Gäste zum Onboarden", systemImage: "checkmark.circle", description: Text("Alle Gäste haben bereits Gruppen zugewiesen."))
                }
            }
            .navigationTitle("Beziehungen zuweisen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen") { dismiss() }
                }
            }
            .onAppear {
                cards = OnboardingEngine.buildCards(from: allGuests, excludeWithGroupType: true)
                loadCurrentCard()
            }
        }
    }

    private func loadCurrentCard() {
        guard let card = currentCard else { return }
        selectedSide = card.guests.first?.side ?? .neutral
        selectedGroupType = card.guests.first?.groupType
        customGroupName = card.guests.first?.customGroupName ?? ""
        selectedFamilyRoles = Dictionary(
            uniqueKeysWithValues: card.guests.compactMap { guest in
                guard let role = guest.familyRole else { return nil }
                return (guest.id, role)
            }
        )
        mainContactID = card.guests.first(where: { $0.mainContactPersonID != nil })?.id
    }

    private func saveCurrentCard() {
        guard let card = currentCard else { return }
        for guest in card.guests {
            guest.side = selectedSide
            guest.groupType = selectedGroupType
            guest.customGroupName = customGroupName.isEmpty ? nil : customGroupName
            guest.familyRole = selectedFamilyRoles[guest.id]
            if let mainID = mainContactID {
                guest.mainContactPersonID = mainID
            }
        }
    }

    @ViewBuilder
    private func questionSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
    }
}
#endif
