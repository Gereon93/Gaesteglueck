#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Linke Spalte des Sitzplan-Canvas: Inbox unzugewiesener Gäste mit
/// Tag-Filter. Gäste lassen sich von hier auf Tische ziehen.
struct RoomGuestInbox: View {
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var events: [Event]

    @State private var inboxTagFilter: UUID? = nil

    private var unassignedGuests: [Guest] {
        guests.filter(\.awaitsSeating)
    }

    private var unassignedSorted: [Guest] {
        let baseList = unassignedGuests.sorted { lhs, rhs in
            if lhs.firstName == rhs.firstName { return lhs.lastName < rhs.lastName }
            return lhs.firstName < rhs.firstName
        }
        if let tagID = inboxTagFilter,
           let tag = tags.first(where: { $0.id == tagID }) {
            return baseList.filter { tag.guestIDs.contains($0.id) }
        }
        return baseList
    }

    private var currentInboxFilterLabel: String {
        if let tagID = inboxTagFilter,
           let tag = tags.first(where: { $0.id == tagID }) {
            return tag.name
        }
        return "Alle Tags"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("INBOX")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                Text("Ohne Tisch · \(unassignedGuests.count)")
                    .font(Tokens.Typography.displayXS)
                    .foregroundStyle(Tokens.Colors.ink)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            if !tags.isEmpty {
                Menu {
                    Button("Alle anzeigen") { inboxTagFilter = nil }
                    Divider()
                    ForEach(tags.sorted(by: { $0.name < $1.name }), id: \.id) { tag in
                        Button(tag.name) { inboxTagFilter = tag.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                        Text(currentInboxFilterLabel)
                            .font(.system(size: 11, design: .rounded))
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5).fill(Tokens.Colors.bg)
                    )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .padding(.horizontal, 12)
                .padding(.top, 6)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(unassignedSorted) { guest in
                        inboxRow(guest: guest)
                    }

                    if unassignedSorted.isEmpty && unassignedGuests.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(Tokens.Colors.sage)
                            Text("Alle Gäste sitzen.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else if unassignedSorted.isEmpty {
                        Text("Keine Gäste mit diesem Tag — Filter ändern oder zurücksetzen.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40)
                            .padding(.horizontal, 16)
                    } else {
                        Text("Zieh Gäste auf einen Tisch oder benutze die KI.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.top, 16)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    private func inboxRow(guest: Guest) -> some View {
        HStack(spacing: 10) {
            Avatar(name: guest.fullName, size: 28, tag: GuestDisplayFormatting.avatarKind(for: guest, tags: tags), diet: GuestDisplayFormatting.dietBadge(for: guest))
            VStack(alignment: .leading, spacing: 1) {
                Text(guest.fullName)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                Text(firstTagLabel(for: guest))
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundStyle(Tokens.Colors.ink4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .draggable(guest.id.uuidString)
    }

    private func firstTagLabel(for guest: Guest) -> String {
        let firstTag = tags.first { $0.guestIDs.contains(guest.id) }
        return firstTag?.name ?? guest.partnerAssignment.displayName(for: events.first)
    }

    private func assignGuestAndPeersToTable(guest: Guest, table: GuestTable) -> Bool {
        let group = registrationGroupCompanions(for: guest)
        let allCandidates = [guest] + group.filter { !$0.isPinned && $0.table != table }
        let unpinned = allCandidates.filter { !$0.isPinned }
        let needsSeats = unpinned.count
        let availableSeats = table.capacity - table.attendingGuests.count + table.guests.filter { unpinned.contains($0) }.count
        guard needsSeats <= availableSeats else { return false }
        for peer in unpinned {
            if peer.table?.id != table.id {
                peer.seatIndex = nil
            }
            peer.table = table
            assignNextFreeSeat(to: peer, in: table)
        }
        return true
    }

    private func assignNextFreeSeat(to guest: Guest, in table: GuestTable) {
        if guest.seatIndex != nil { return }
        let used = Set(table.guests.compactMap { $0.id == guest.id ? nil : $0.seatIndex })
        let disabled = table.disabledSeatIndices
        for idx in 0..<table.capacity where !used.contains(idx) && !disabled.contains(idx) {
            guest.seatIndex = idx
            return
        }
    }

    private func registrationGroupCompanions(for guest: Guest) -> [Guest] {
        guard let group = guest.registrationGroup else { return [] }
        return guests.filter { $0.id != guest.id && $0.registrationGroup == group }
    }
}
#endif
