#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GuestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]

    let guest: Guest?

    @State private var firstName: String
    @State private var lastName: String
    @State private var partnerAssignment: PartnerAssignment
    @State private var familyRole: FamilyRole?
    @State private var dietaryChoice: String
    @State private var intolerances: String
    @State private var ageCategory: AgeCategory
    @State private var rsvpStatus: RSVPStatus
    @State private var funFact: String
    @State private var notes: String
    @State private var employer: String
    @State private var profession: String
    @State private var hobbies: String
    @State private var showingExtraDetails = false

    private var menuOptions: [String] {
        events.first?.menuOptions ?? ["Fleisch", "Vegetarisch", "Vegan"]
    }

    init(guest: Guest? = nil) {
        self.guest = guest
        _firstName = State(initialValue: guest?.firstName ?? "")
        _lastName = State(initialValue: guest?.lastName ?? "")
        _partnerAssignment = State(initialValue: guest?.partnerAssignment ?? .both)
        _familyRole = State(initialValue: guest?.familyRole)
        _dietaryChoice = State(initialValue: guest?.dietaryChoice ?? "Fleisch")
        _intolerances = State(initialValue: guest?.intolerances.joined(separator: ", ") ?? "")
        _ageCategory = State(initialValue: guest?.ageCategory ?? .adult)
        _rsvpStatus = State(initialValue: guest?.rsvpStatus ?? .confirmed)
        _funFact = State(initialValue: guest?.funFact ?? "")
        _notes = State(initialValue: guest?.notes ?? "")
        _employer = State(initialValue: guest?.employer ?? "")
        _profession = State(initialValue: guest?.profession ?? "")
        _hobbies = State(initialValue: guest?.hobbies.joined(separator: ", ") ?? "")
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Vorname", text: $firstName)
                    TextField("Nachname", text: $lastName)
                }

                Section("Zuordnung") {
                    Picker("Partner", selection: $partnerAssignment) {
                        ForEach(PartnerAssignment.allCases) { pa in
                            Text(pa.rawValue).tag(pa)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Alter", selection: $ageCategory) {
                        ForEach(AgeCategory.allCases) { ac in
                            Text(ac.rawValue).tag(ac)
                        }
                    }
                }

                Section("Beziehung") {
                    Picker("Familienrolle", selection: $familyRole) {
                        Text("Keine Angabe").tag(nil as FamilyRole?)
                        ForEach(FamilyRole.allCases) { role in
                            Text(role.rawValue).tag(role as FamilyRole?)
                        }
                    }
                }

                Section("Essen & Unverträglichkeiten") {
                    Picker("Menüwahl", selection: $dietaryChoice) {
                        ForEach(menuOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    TextField("Unverträglichkeiten (kommagetrennt)", text: $intolerances)
                }

                Section("Sonstiges") {
                    Picker("RSVP", selection: $rsvpStatus) {
                        ForEach(RSVPStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Fun Fact", text: $funFact)
                    TextField("Notizen", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                DisclosureGroup("Weitere Details", isExpanded: $showingExtraDetails) {
                    TextField("Arbeitgeber", text: $employer)
                    TextField("Beruf", text: $profession)
                    TextField("Hobbies (kommagetrennt)", text: $hobbies)
                }
            }
            .navigationTitle(guest == nil ? "Gast hinzufügen" : "Gast bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        let parsedIntolerances = intolerances
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let parsedHobbies = hobbies
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let guest {
            guest.firstName = firstName.trimmingCharacters(in: .whitespaces)
            guest.lastName = lastName.trimmingCharacters(in: .whitespaces)
            guest.partnerAssignment = partnerAssignment
            guest.familyRole = familyRole
            guest.dietaryChoice = dietaryChoice
            guest.intolerances = parsedIntolerances
            guest.ageCategory = ageCategory
            guest.rsvpStatus = rsvpStatus
            guest.funFact = funFact
            guest.notes = notes
            guest.employer = employer
            guest.profession = profession
            guest.hobbies = parsedHobbies
        } else {
            let newGuest = Guest(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                partnerAssignment: partnerAssignment,
                ageCategory: ageCategory,
                familyRole: familyRole,
                dietaryChoice: dietaryChoice,
                intolerances: parsedIntolerances,
                funFact: funFact,
                notes: notes,
                rsvpStatus: rsvpStatus
            )
            newGuest.employer = employer
            newGuest.profession = profession
            newGuest.hobbies = parsedHobbies
            modelContext.insert(newGuest)
        }
        dismiss()
    }
}
#endif
