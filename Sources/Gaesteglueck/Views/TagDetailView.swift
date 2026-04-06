#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TagDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var tag: Tag
    @Query(sort: \Guest.firstName) private var allGuests: [Guest]

    private var memberGuests: [Guest] {
        allGuests.filter { tag.guestIDs.contains($0.id) }
    }

    private var availableGuests: [Guest] {
        allGuests.filter { !tag.guestIDs.contains($0.id) }
    }

    var body: some View {
        Form {
            Section("Tag-Info") {
                TextField("Name", text: $tag.name)
                Picker("Kategorie", selection: $tag.category) {
                    ForEach(TagCategory.allCases) { cat in
                        Text(cat.rawValue).tag(cat)
                    }
                }
                HStack {
                    Text("Farbe")
                    Spacer()
                    Circle()
                        .fill(Color(hex: tag.color))
                        .frame(width: 24, height: 24)
                    TextField("#Hex", text: $tag.color)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                }
                Picker("Partner-Zuordnung", selection: $tag.partnerAssignment) {
                    Text("Alle").tag(nil as PartnerAssignment?)
                    ForEach(PartnerAssignment.allCases) { pa in
                        Text(pa.rawValue).tag(pa as PartnerAssignment?)
                    }
                }
            }

            Section("Mitglieder (\(memberGuests.count))") {
                if memberGuests.isEmpty {
                    Text("Noch keine Gäste in diesem Tag")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(memberGuests) { guest in
                        HStack {
                            Circle().fill(guest.partnerAssignment.color).frame(width: 8, height: 8)
                            Text(guest.fullName)
                            Spacer()
                            Button {
                                tag.guestIDs.removeAll { $0 == guest.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !availableGuests.isEmpty {
                Section("Gast hinzufügen") {
                    ForEach(availableGuests) { guest in
                        Button {
                            tag.guestIDs.append(guest.id)
                        } label: {
                            HStack {
                                Circle().fill(guest.partnerAssignment.color).frame(width: 8, height: 8)
                                Text(guest.fullName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle(tag.name)
    }
}
#endif
