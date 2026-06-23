#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GuestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Guest.firstName) private var allGuests: [Guest]

    let guest: Guest?

    @State private var firstName: String
    @State private var lastName: String
    @State private var title: String
    @State private var gender: Gender
    @State private var partnerAssignment: PartnerAssignment
    @State private var familyRole: FamilyRole?
    @State private var dietaryChoice: String
    @State private var intolerances: String
    @State private var ageCategory: AgeCategory
    @State private var rsvpStatus: RSVPStatus
    @State private var funFact: String
    @State private var notes: String
    @State private var phoneNumber: String
    @State private var employer: String
    @State private var profession: String
    @State private var hobbies: String
    @State private var funFactApproved: Bool = false
    @State private var showingExtraDetails = false
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var didLoadInitialTags = false
    @State private var contactPickerMatches: [ContactMatch] = []
    @State private var showingContactPicker = false
    @State private var contactErrorMessage: String?

    private var menuOptions: [String] {
        events.first?.menuOptions ?? ["Fleisch", "Vegetarisch", "Vegan"]
    }

    init(guest: Guest? = nil) {
        self.guest = guest
        _firstName = State(initialValue: guest?.firstName ?? "")
        _lastName = State(initialValue: guest?.lastName ?? "")
        _title = State(initialValue: guest?.title ?? "")
        _gender = State(initialValue: guest?.gender ?? .unspecified)
        _partnerAssignment = State(initialValue: guest?.partnerAssignment ?? .both)
        _familyRole = State(initialValue: guest?.familyRole)
        _dietaryChoice = State(initialValue: guest?.dietaryChoice ?? "Fleisch")
        _intolerances = State(initialValue: guest?.intolerances.joined(separator: ", ") ?? "")
        _ageCategory = State(initialValue: guest?.ageCategory ?? .adult)
        _rsvpStatus = State(initialValue: guest?.rsvpStatus ?? .confirmed)
        _funFact = State(initialValue: guest?.funFact ?? "")
        _funFactApproved = State(initialValue: guest?.funFactApproved ?? false)
        _notes = State(initialValue: guest?.notes ?? "")
        _phoneNumber = State(initialValue: guest?.phoneNumber ?? "")
        _employer = State(initialValue: guest?.employer ?? "")
        _profession = State(initialValue: guest?.profession ?? "")
        _hobbies = State(initialValue: guest?.hobbies.joined(separator: ", ") ?? "")
    }

    private var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// True wenn die aktuelle Picker-Auswahl eine Geschwister-Rolle ist —
    /// dann zeigen wir den Auto-Propagation-Hinweis im Form.
    private var siblingRoleSelected: Bool {
        guard let role = familyRole else { return false }
        return [.sister, .brother, .sisterInLaw, .brotherInLaw].contains(role)
    }

    /// Anzahl Kinder/Kleinkinder/Babys ohne FamilyRole in der gleichen
    /// Anmeldung — für den Hinweis-Text in der Beziehungs-Section.
    private var kidsInRegistrationGroup: Int {
        guard let g = guest, let group = g.registrationGroup else { return 0 }
        return allGuests.filter { peer in
            peer.id != g.id
                && peer.registrationGroup == group
                && peer.familyRole == nil
                && peer.ageCategory != .adult
        }.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    LabeledContent("Titel") {
                        TextField("optional, z.B. Dr., Pfarrer, Dekan", text: $title)
                    }
                    LabeledContent("Vorname") {
                        TextField("Vorname", text: $firstName)
                    }
                    LabeledContent("Nachname") {
                        TextField("Nachname", text: $lastName)
                    }
                    LabeledContent("Geschlecht") {
                        Picker("", selection: $gender) {
                            ForEach(Gender.allCases) { g in
                                Text(g.displayName).tag(g)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("Zuordnung") {
                    Picker("Seite", selection: $partnerAssignment) {
                        ForEach(PartnerAssignment.allCases) { pa in
                            Text(pa.displayName(for: events.first)).tag(pa)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Alter", selection: $ageCategory) {
                        ForEach(AgeCategory.allCases) { ac in
                            Text(ac.rawValue).tag(ac)
                        }
                    }
                }

                Section {
                    Picker("Familienrolle", selection: $familyRole) {
                        Text("Keine Angabe").tag(nil as FamilyRole?)
                        ForEach(FamilyRole.allCases) { role in
                            Text(role.rawValue).tag(role as FamilyRole?)
                        }
                    }
                    if siblingRoleSelected, kidsInRegistrationGroup > 0 {
                        Text("\(kidsInRegistrationGroup) \(kidsInRegistrationGroup == 1 ? "Kind" : "Kinder") in dieser Anmeldung werden beim Speichern automatisch als Nichte/Neffe markiert. Korrigieren kannst du das einzeln.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } header: {
                    Text("Beziehung")
                }

                GuestTagsSection(selectedTagIDs: $selectedTagIDs)

                if guest != nil {
                    GuestPairingsSection(guest: guest, firstName: firstName)
                    GuestConflictsSection(guest: guest, firstName: firstName)
                }

                Section("Essen & Unverträglichkeiten") {
                    Picker("Menüwahl", selection: $dietaryChoice) {
                        ForEach(menuOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    LabeledContent("Unverträglichkeiten") {
                        TextField("kommagetrennt", text: $intolerances)
                    }
                }

                Section("Sonstiges") {
                    Picker("RSVP", selection: $rsvpStatus) {
                        ForEach(RSVPStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    LabeledContent("Fun Fact") {
                        TextField("z.B. spielt Klavier seit 20 Jahren", text: $funFact)
                    }
                    Toggle("FunFact ist gut – darf erzaehlt werden", isOn: $funFactApproved)
                        #if os(macOS)
                        .toggleStyle(.checkbox)
                        #endif
                        .disabled(funFact.trimmingCharacters(in: .whitespaces).isEmpty)
                        .help("Bestaetige dass dieser FunFact konkret und persoenlich ist und beim Brauttisch erwaehnt werden kann.")
                    LabeledContent("Notizen") {
                        TextField("optionale Anmerkungen", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
                    LabeledContent("Telefon") {
                        HStack {
                            TextField("z.B. +49 170 1234567", text: $phoneNumber)
                            Button {
                                if let g = guest {
                                    Task { await importPhoneFromContacts(into: g) }
                                }
                            } label: {
                                Image(systemName: "person.crop.circle.badge.plus")
                            }
                            .buttonStyle(.borderless)
                            .help("Aus macOS-Kontakten holen")
                            .disabled(guest == nil)
                        }
                    }
                }

                DisclosureGroup("Weitere Details", isExpanded: $showingExtraDetails) {
                    LabeledContent("Arbeitgeber") {
                        TextField("optional", text: $employer)
                    }
                    LabeledContent("Beruf") {
                        TextField("optional", text: $profession)
                    }
                    LabeledContent("Hobbies") {
                        TextField("kommagetrennt", text: $hobbies)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(guest == nil ? "Gast hinzufügen" : "Gast bearbeiten")
            .sheet(isPresented: $showingContactPicker) {
                if let g = guest {
                    ContactPickerSheet(guest: g, matches: contactPickerMatches) { phone in
                        phoneNumber = phone
                        g.phoneNumber = phone
                        try? modelContext.save()
                    }
                }
            }
            .alert("Kontakte-Zugriff", isPresented: Binding(
                get: { contactErrorMessage != nil },
                set: { if !$0 { contactErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(contactErrorMessage ?? "")
            }
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
        .frame(minWidth: 560, minHeight: 640)
        .onAppear {
            guard !didLoadInitialTags else { return }
            didLoadInitialTags = true
            if let g = guest {
                selectedTagIDs = Set(allTags.filter { $0.guestIDs.contains(g.id) }.map(\.id))
            }
        }
    }

    @MainActor
    private func importPhoneFromContacts(into target: Guest) async {
        do {
            guard try await ContactsService.requestAccess() else {
                contactErrorMessage = ContactsServiceError.accessDenied.errorDescription
                return
            }
            let matches = try ContactsService.search(firstName: firstName, lastName: lastName)
            if matches.count == 1, let only = matches.first, only.phoneNumbers.count == 1 {
                phoneNumber = only.phoneNumbers[0]
                target.phoneNumber = only.phoneNumbers[0]
                try? modelContext.save()
                return
            }
            if matches.isEmpty {
                contactErrorMessage = "Keine Treffer fuer \(firstName) \(lastName) in den Kontakten."
                return
            }
            contactPickerMatches = matches
            showingContactPicker = true
        } catch let error as ContactsServiceError {
            contactErrorMessage = error.errorDescription
        } catch {
            contactErrorMessage = error.localizedDescription
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

        let trimmedFunFact = funFact.trimmingCharacters(in: .whitespaces)

        let targetGuest: Guest
        if let guest {
            guest.firstName = firstName.trimmingCharacters(in: .whitespaces)
            guest.lastName = lastName.trimmingCharacters(in: .whitespaces)
            guest.partnerAssignment = partnerAssignment
            guest.familyRole = familyRole
            guest.dietaryChoice = dietaryChoice
            guest.intolerances = parsedIntolerances
            guest.ageCategory = ageCategory
            guest.applyRSVP(rsvpStatus)
            // Rohdaten geändert → alte vereinheitlichte Fassung passt nicht
            // mehr, daher verwerfen (Fallback auf neuen Rohtext bis neu
            // vereinheitlicht wird). Kein stilles Auseinanderlaufen.
            if guest.funFact != trimmedFunFact {
                guest.funFactNormalized = ""
            }
            guest.funFact = trimmedFunFact
            guest.funFactApproved = trimmedFunFact.isEmpty ? false : funFactApproved
            guest.notes = notes
            guest.employer = employer
            guest.profession = profession
            guest.hobbies = parsedHobbies
            guest.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
            guest.title = title.trimmingCharacters(in: .whitespaces)
            guest.gender = gender
            targetGuest = guest
        } else {
            let newGuest = Guest(
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                partnerAssignment: partnerAssignment,
                ageCategory: ageCategory,
                familyRole: familyRole,
                dietaryChoice: dietaryChoice,
                intolerances: parsedIntolerances,
                funFact: trimmedFunFact,
                notes: notes,
                rsvpStatus: rsvpStatus
            )
            newGuest.funFactApproved = trimmedFunFact.isEmpty ? false : funFactApproved
            newGuest.employer = employer
            newGuest.profession = profession
            newGuest.hobbies = parsedHobbies
            newGuest.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
            newGuest.title = title.trimmingCharacters(in: .whitespaces)
            newGuest.gender = gender
            modelContext.insert(newGuest)
            targetGuest = newGuest
        }
        // Tag-Mitgliedschaften abgleichen — auf jedem Tag schauen ob der Gast
        // dort jetzt drin sein soll und die guestIDs entsprechend ergänzen/entfernen.
        for tag in allTags {
            let shouldContain = selectedTagIDs.contains(tag.id)
            let alreadyContains = tag.guestIDs.contains(targetGuest.id)
            if shouldContain && !alreadyContains {
                tag.guestIDs.append(targetGuest.id)
            } else if !shouldContain && alreadyContains {
                tag.guestIDs.removeAll { $0 == targetGuest.id }
            }
        }
        // Wenn der Gast noch keine Seite hat, leiten wir sie aus den Tags ab.
        // Beispiel: Tobias ist in "JGA Bob" + "Realschulfreunde Bob"
        // → Seite = Bob. So muss der User nicht zwei Stellen pflegen.
        PartnerSideDeriver.applyIfUnassigned(targetGuest, in: allTags, allGuests: allGuests)

        // Sippe nachziehen: wenn der Gast jetzt eine Seite hat, ziehen wir
        // alle anderen unzugeordneten Mitglieder der Anmeldung mit. Beispiel:
        // Carina (Cousine Alice) → Tom (Mann) und Hugo (Sohn) erben Alice.
        PartnerSideDeriver.propagateSide(targetGuest.partnerAssignment, fromGuest: targetGuest, in: allGuests)

        // Geschwister-Sippe: wenn dieser Gast eine Schwester/Bruder/Schwager/
        // Schwägerin ist und in der Anmeldung nicht-erwachsene Personen ohne
        // Familienrolle dabei sind → die zählen wir automatisch als Nichten/
        // Neffen. Spart 2-3 Edit-Sheets pro Sippe.
        propagateSiblingRoleToKids(of: targetGuest)
        dismiss()
    }

    /// Wenn der gerade gespeicherte Gast eine Geschwister-Rolle hat und in
    /// seiner registrationGroup Kinder ohne familyRole sind, markieren wir
    /// die als Nichte (Default — User kann auf Neffe umstellen). Auch die
    /// familyRolePartner-Seite wird übernommen, damit "Nichte von Bob"
    /// klar bleibt.
    private func propagateSiblingRoleToKids(of saved: Guest) {
        guard let role = saved.familyRole else { return }
        let siblingRoles: Set<FamilyRole> = [.sister, .brother, .sisterInLaw, .brotherInLaw]
        guard siblingRoles.contains(role) else { return }
        guard let group = saved.registrationGroup else { return }
        let inheritedPartner = saved.familyRolePartner ?? saved.partnerAssignment
        let peers = allGuests.filter { $0.id != saved.id && $0.registrationGroup == group }
        for peer in peers where peer.familyRole == nil && peer.ageCategory != .adult {
            peer.familyRole = .niece
            peer.familyRolePartner = inheritedPartner
        }
    }
}
#endif
