#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GuestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let guest: Guest?

    @State private var name: String
    @State private var side: Side
    @State private var groupType: GroupType?
    @State private var customGroupName: String
    @State private var familyRole: FamilyRole?
    @State private var dietaryPreference: DietaryPreference
    @State private var allergies: String
    @State private var isChild: Bool
    @State private var rsvpStatus: RSVPStatus
    @State private var notes: String

    init(guest: Guest? = nil) {
        self.guest = guest
        _name = State(initialValue: guest?.name ?? "")
        _side = State(initialValue: guest?.side ?? .neutral)
        _groupType = State(initialValue: guest?.groupType)
        _customGroupName = State(initialValue: guest?.customGroupName ?? "")
        _familyRole = State(initialValue: guest?.familyRole)
        _dietaryPreference = State(initialValue: guest?.dietaryPreference ?? .meat)
        _allergies = State(initialValue: guest?.allergies ?? "")
        _isChild = State(initialValue: guest?.isChild ?? false)
        _rsvpStatus = State(initialValue: guest?.rsvpStatus ?? .pending)
        _notes = State(initialValue: guest?.notes ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pflichtfelder") {
                    TextField("Name", text: $name)
                    Picker("Seite", selection: $side) {
                        ForEach(Side.allCases) { side in
                            Text(side.rawValue).tag(side)
                        }
                    }
                    Toggle("Kind", isOn: $isChild)
                }
                Section("Gruppe & Beziehung") {
                    Picker("Gruppe", selection: $groupType) {
                        Text("Keine").tag(nil as GroupType?)
                        ForEach(GroupType.allCases) { gt in
                            Text(gt.rawValue).tag(gt as GroupType?)
                        }
                    }
                    if groupType == .clubMember {
                        TextField("Vereinsname (z.B. TuS Musterstadt)", text: $customGroupName)
                    }
                    Picker("Beziehung", selection: $familyRole) {
                        Text("Keine Angabe").tag(nil as FamilyRole?)
                        ForEach(FamilyRole.allCases) { role in
                            Text(role.rawValue).tag(role as FamilyRole?)
                        }
                    }
                }
                Section("Essen & Unverträglichkeiten") {
                    Picker("Ernährung", selection: $dietaryPreference) {
                        ForEach(DietaryPreference.allCases) { pref in
                            HStack {
                                Text(pref.badge)
                                Text(pref.rawValue)
                            }.tag(pref)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Unverträglichkeiten (z.B. Laktose, Nüsse)", text: $allergies)
                }
                Section("Status") {
                    Picker("RSVP", selection: $rsvpStatus) {
                        ForEach(RSVPStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Notizen", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(guest == nil ? "Gast hinzufügen" : "Gast bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
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
        if let guest {
            guest.name = name.trimmingCharacters(in: .whitespaces)
            guest.side = side
            guest.groupType = groupType
            guest.customGroupName = customGroupName.isEmpty ? nil : customGroupName
            guest.familyRole = familyRole
            guest.dietaryPreference = dietaryPreference
            guest.allergies = allergies
            guest.isChild = isChild
            guest.rsvpStatus = rsvpStatus
            guest.notes = notes
        } else {
            let newGuest = Guest(
                name: name.trimmingCharacters(in: .whitespaces),
                side: side,
                groupType: groupType,
                customGroupName: customGroupName.isEmpty ? nil : customGroupName,
                familyRole: familyRole,
                dietaryPreference: dietaryPreference,
                allergies: allergies,
                rsvpStatus: rsvpStatus,
                isChild: isChild,
                notes: notes
            )
            modelContext.insert(newGuest)
        }
        dismiss()
    }
}
#endif
