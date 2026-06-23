#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Rechter Inspektor des Sitzplan-Canvas: Eigenschaften, Belegung und
/// Konflikte des ausgewählten Tisches — oder ein Platzhalter, solange
/// kein Tisch gewählt ist.
struct RoomInspectorPanel: View {
    let table: GuestTable?
    let violations: [Violation]

    @Query private var tags: [Tag]

    var body: some View {
        if let table {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TISCH AUSGEWÄHLT")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .tracking(0.5)
                        Text(table.name)
                            .font(Tokens.Typography.displayS)
                            .foregroundStyle(Tokens.Colors.ink)
                        Text("\(table.shape.rawValue) · \(table.capacity) Plätze · \(table.attendingGuests.count) belegt")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink2)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Tokens.Colors.line).frame(height: 1)
                    }

                    InspectorSection("Eigenschaften") {
                        VStack(alignment: .leading, spacing: 8) {
                            inspectorPropRow("Form", table.shape.rawValue)
                            inspectorPropRow(
                                table.shape == .round ? "Durchmesser" : "Maße",
                                table.shape == .round
                                    ? "\(Int(table.diameter)) cm"
                                    : "\(Int(table.width)) × \(Int(table.depth)) cm"
                            )
                            inspectorPropRow("Plätze", "\(table.capacity)")
                            inspectorPropRow("Position", "X \(Int(table.positionX)) · Y \(Int(table.positionY))")
                        }
                    }

                    InspectorSection("Belegung") {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(table.guests) { guest in
                                HStack(spacing: 10) {
                                    Avatar(name: guest.fullName, size: 26, tag: GuestDisplayFormatting.avatarKind(for: guest, tags: tags), diet: GuestDisplayFormatting.dietBadge(for: guest), pinned: guest.isPinned)
                                    Text(guest.fullName)
                                        .font(.system(size: 12.5, design: .rounded))
                                        .foregroundStyle(Tokens.Colors.ink)
                                    if guest.seatIndex == nil {
                                        Text("ohne Platz")
                                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Tokens.Colors.warn)
                                            .clipShape(Capsule())
                                            .help("Tisch ist voll — diesem Gast wurde noch kein Sitz zugewiesen.")
                                    }
                                    Spacer()
                                    Button {
                                        guest.isPinned.toggle()
                                    } label: {
                                        Image(systemName: guest.isPinned ? "pin.slash" : "pin")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Tokens.Colors.ink3)
                                    }
                                    .buttonStyle(.plain)
                                    Button {
                                        guard !guest.isPinned else { return }
                                        guest.table = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 12))
                                            .foregroundStyle(guest.isPinned ? Tokens.Colors.ink4 : Tokens.Colors.ink3)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(guest.isPinned)
                                }
                            }
                            if table.guests.isEmpty {
                                Text("Noch keine Gäste an diesem Tisch.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundStyle(Tokens.Colors.ink3)
                            }
                        }
                    }

                    let tableGuestIDs = Set(table.guests.map(\.id))
                    let tableViolations = violations.filter { v in
                        v.guestIDs.contains(where: { tableGuestIDs.contains($0) })
                    }
                    if !tableViolations.isEmpty {
                        InspectorSection("Konflikte") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(tableViolations.enumerated()), id: \.offset) { _, v in
                                    ConflictBanner(
                                        title: v.description,
                                        tone: .warn
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .background(Tokens.Colors.bg2)
        } else {
            VStack(spacing: 12) {
                Image(systemName: "square.dashed")
                    .font(.system(size: 32))
                    .foregroundStyle(Tokens.Colors.ink4)
                Text("Wähle einen Tisch")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                Text("Klick auf einen Tisch im Plan, um Belegung und Eigenschaften zu sehen.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Colors.bg2)
        }
    }

    private func inspectorPropRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
#endif
