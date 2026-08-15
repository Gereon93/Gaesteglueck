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
                    LabeledContent("Name") {
                        TextField("z.B. Hochzeit Müller", text: $name)
                    }
                    Toggle("Datum festlegen", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Datum", selection: $date, displayedComponents: .date)
                    }
                    LabeledContent("Veranstaltungsort") {
                        TextField("Location", text: $venue)
                    }
                }

                Section("Partner") {
                    LabeledContent("Partner 1 — Name") {
                        TextField("Vorname", text: $partner1Name)
                    }
                    LabeledContent("Partner 2 — Name") {
                        TextField("Vorname", text: $partner2Name)
                    }
                    LabeledContent("Partner 1 — Geburtsname") {
                        TextField("optional", text: $partner1PreMarriageName)
                    }
                    LabeledContent("Partner 2 — Geburtsname") {
                        TextField("optional", text: $partner2PreMarriageName)
                    }
                }

                Section("Menü") {
                    LabeledContent("Menüoptionen") {
                        TextField("kommagetrennt", text: $menuOptionsString)
                    }
                    Text("z.B. Fleisch, Vegetarisch, Vegan, Kinderportion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    LabeledContent("Breite (cm)") {
                        TextField("z.B. 1200 für 12 m", text: $roomWidthCM)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                    LabeledContent("Länge (cm)") {
                        TextField("z.B. 2000 für 20 m", text: $roomLengthCM)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                    }
                } header: {
                    Text("Raum")
                } footer: {
                    Text("Eingabe in Zentimetern (1 m = 100 cm). Sobald gesetzt, skalieren die Tische im Sitzplan-Canvas proportional zum echten Raum.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
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
        .frame(minWidth: 560, minHeight: 620)
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
            modelContext.saveOrLog()
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
            modelContext.saveOrLog()
        }
        dismiss()
    }
}
#endif
