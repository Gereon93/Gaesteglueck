#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct EventSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var events: [Event]

    @State private var name: String = ""
    @State private var date: Date = .now
    @State private var hasDate: Bool = false
    @State private var venue: String = ""
    @State private var partner1Name: String = ""
    @State private var partner2Name: String = ""
    @State private var partner1PreMarriageName: String = ""
    @State private var partner2PreMarriageName: String = ""
    @State private var menuOptionsString: String = "Fleisch, Vegetarisch, Vegan"
    @State private var roomWidthCM: String = ""
    @State private var roomLengthCM: String = ""

    private var existingEvent: Event? { events.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Event") {
                    TextField("Name (z.B. Hochzeit Müller)", text: $name)
                    Toggle("Datum", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Datum", selection: $date, displayedComponents: .date)
                    }
                    TextField("Veranstaltungsort", text: $venue)
                }

                Section("Partner") {
                    TextField("Name Partner 1", text: $partner1Name)
                    TextField("Name Partner 2", text: $partner2Name)
                    TextField("Geburtsname Partner 1", text: $partner1PreMarriageName)
                    TextField("Geburtsname Partner 2", text: $partner2PreMarriageName)
                }

                Section("Menü") {
                    TextField("Menüoptionen (kommagetrennt)", text: $menuOptionsString)
                    Text("z.B. Fleisch, Vegetarisch, Vegan, Kinderportion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Raum") {
                    HStack {
                        Text("Breite (cm)")
                        Spacer()
                        TextField("z.B. 1500", text: $roomWidthCM)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    HStack {
                        Text("Länge (cm)")
                        Spacer()
                        TextField("z.B. 2000", text: $roomLengthCM)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                }
            }
            .navigationTitle(existingEvent == nil ? "Event einrichten" : "Event bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExisting() }
        }
    }

    private func loadExisting() {
        guard let e = existingEvent else { return }
        name = e.name
        if let d = e.date { date = d; hasDate = true }
        venue = e.venue
        partner1Name = e.partner1Name
        partner2Name = e.partner2Name
        partner1PreMarriageName = e.partner1PreMarriageName
        partner2PreMarriageName = e.partner2PreMarriageName
        menuOptionsString = e.menuOptions.joined(separator: ", ")
        roomWidthCM = e.roomWidthCM.map { String(Int($0)) } ?? ""
        roomLengthCM = e.roomLengthCM.map { String(Int($0)) } ?? ""
    }

    private func save() {
        let menuOptions = menuOptionsString
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let e = existingEvent {
            e.name = name.trimmingCharacters(in: .whitespaces)
            e.date = hasDate ? date : nil
            e.venue = venue
            e.partner1Name = partner1Name
            e.partner2Name = partner2Name
            e.partner1PreMarriageName = partner1PreMarriageName
            e.partner2PreMarriageName = partner2PreMarriageName
            e.menuOptions = menuOptions.isEmpty ? ["Fleisch", "Vegetarisch", "Vegan"] : menuOptions
            e.roomWidthCM = Double(roomWidthCM)
            e.roomLengthCM = Double(roomLengthCM)
        } else {
            let e = Event(
                name: name.trimmingCharacters(in: .whitespaces),
                date: hasDate ? date : nil,
                venue: venue,
                partner1Name: partner1Name,
                partner2Name: partner2Name,
                partner1PreMarriageName: partner1PreMarriageName,
                partner2PreMarriageName: partner2PreMarriageName,
                menuOptions: menuOptions.isEmpty ? ["Fleisch", "Vegetarisch", "Vegan"] : menuOptions
            )
            e.roomWidthCM = Double(roomWidthCM)
            e.roomLengthCM = Double(roomLengthCM)
            modelContext.insert(e)
        }
        dismiss()
    }
}
#endif
