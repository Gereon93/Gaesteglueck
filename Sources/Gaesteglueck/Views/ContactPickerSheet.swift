#if canImport(SwiftUI) && canImport(Contacts)
import SwiftUI

struct ContactPickerSheet: View {
    let guest: Guest
    let initialMatches: [ContactMatch]
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var matches: [ContactMatch]
    @State private var searchText: String
    @State private var selectedContactID: String?
    @State private var selectedPhone: String?
    @State private var errorMessage: String?

    init(guest: Guest, matches: [ContactMatch], onPick: @escaping (String) -> Void) {
        self.guest = guest
        self.initialMatches = matches
        self.onPick = onPick
        _matches = State(initialValue: matches)
        let prefill = [guest.firstName, guest.lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        _searchText = State(initialValue: prefill)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Telefonnummer fuer \(guest.fullName)")
                    .font(.title3.bold())
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Name in Kontakten suchen", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { runSearch() }
                    Button("Suchen") { runSearch() }
                        .keyboardShortcut(.return, modifiers: [])
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
                if matches.isEmpty {
                    Text("Keine Treffer. Versuch es mit Spitzname, Mädchenname oder nur Vornamen.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    Text("\(matches.count) Treffer — Person und Nummer waehlen.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }
            .padding()

            Divider()

            if matches.isEmpty {
                Spacer(minLength: 12)
            } else {
                List {
                    ForEach(matches) { match in
                        Section(header: Text(headerLabel(for: match))) {
                            ForEach(match.phoneNumbers, id: \.self) { number in
                                Button {
                                    selectedContactID = match.id
                                    selectedPhone = number
                                } label: {
                                    HStack {
                                        Image(systemName: isSelected(match.id, number) ? "largecircle.fill.circle" : "circle")
                                        Text(number)
                                            .monospaced()
                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Uebernehmen") {
                    if let phone = selectedPhone {
                        onPick(phone)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedPhone == nil)
            }
            .padding()
        }
        .frame(minWidth: 460, minHeight: 360)
    }

    private func headerLabel(for match: ContactMatch) -> String {
        var label = match.displayName
        if !match.organization.isEmpty {
            label += " · \(match.organization)"
        }
        return label
    }

    private func isSelected(_ contactID: String, _ phone: String) -> Bool {
        selectedContactID == contactID && selectedPhone == phone
    }

    private func runSearch() {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            matches = []
            return
        }
        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        let first = parts.first ?? trimmed
        let last = parts.count > 1 ? parts[1] : ""
        do {
            errorMessage = nil
            matches = try ContactsService.search(firstName: first, lastName: last)
            selectedContactID = nil
            selectedPhone = nil
        } catch let error as ContactsServiceError {
            errorMessage = error.errorDescription
            matches = []
        } catch {
            errorMessage = error.localizedDescription
            matches = []
        }
    }
}
#endif
