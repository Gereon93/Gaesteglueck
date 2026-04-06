#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct RoomCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var roomPlans: [RoomPlan]

    @State private var selectedTable: GuestTable?
    @State private var showingAddTable = false
    @State private var showingFloorPlanSetup = false

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil && $0.needsSeat }
    }

    private var happinessScore: Double {
        HappinessScorer.scoreAllTables(tables, tags: tags, constraints: constraints)
    }

    private var violations: [Violation] {
        HappinessScorer.findViolations(tables: tables, constraints: constraints)
    }

    // Group unassigned guests by their primary tag
    private var unassignedGrouped: [(String, [Guest])] {
        var result: [(String, [Guest])] = []
        var placed = Set<UUID>()

        for tag in tags.sorted(by: { $0.name < $1.name }) {
            let inTag = unassignedGuests.filter { tag.guestIDs.contains($0.id) && !placed.contains($0.id) }
            if !inTag.isEmpty {
                result.append((tag.name, inTag))
                inTag.forEach { placed.insert($0.id) }
            }
        }

        let ungrouped = unassignedGuests.filter { !placed.contains($0.id) }
        if !ungrouped.isEmpty {
            result.append(("Ohne Gruppe", ungrouped))
        }

        return result
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: unassigned guests grouped by tags
            guestInbox
                .frame(width: 250)

            Divider()

            // Center: room canvas
            ZStack {
                Color(nsColor: .controlBackgroundColor)
                    .ignoresSafeArea()

                ForEach(tables) { table in
                    TableCanvasItemView(
                        table: table,
                        isSelected: selectedTable?.id == table.id,
                        onTap: { selectedTable = table }
                    )
                    .dropDestination(for: String.self) { items, _ in
                        guard let guestIDString = items.first,
                              let guestID = UUID(uuidString: guestIDString),
                              let guest = guests.first(where: { $0.id == guestID }) else {
                            return false
                        }
                        guard !table.isFull else { return false }
                        guard !guest.isPinned else { return false }
                        guest.table = table
                        return true
                    }
                }
            }

            Divider()

            // Right panel: selected table details or empty
            detailPanel
                .frame(width: 280)
        }
        .navigationTitle("Raumplan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTable = true
                } label: {
                    Label("Tisch hinzufügen", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                AutoAssignButton()
            }
            ToolbarItem(placement: .secondaryAction) {
                AutoPlaceButton()
            }
            ToolbarItem(placement: .status) {
                ScoreBadgeView(score: happinessScore)
            }
            ToolbarItem(placement: .secondaryAction) {
                ExportButton(tables: tables, eventName: "Hochzeit", date: nil)
            }
        }
        .sheet(isPresented: $showingAddTable) {
            TableFormView()
        }
    }

    // MARK: - Guest Inbox

    private var guestInbox: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Nicht zugewiesen")
                    .font(.headline)
                Spacer()
                Text("\(unassignedGuests.count)")
                    .foregroundStyle(.secondary)
            }
            .padding()

            List {
                ForEach(unassignedGrouped, id: \.0) { groupName, groupGuests in
                    Section(groupName) {
                        ForEach(groupGuests) { guest in
                            HStack {
                                Circle().fill(guest.partnerAssignment.color).frame(width: 8, height: 8)
                                Text(guest.fullName)
                                    .font(.body)
                            }
                            .draggable(guest.id.uuidString)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(.background)
    }

    // MARK: - Detail Panel

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let table = selectedTable {
                VStack(alignment: .leading, spacing: 8) {
                    Text(table.name)
                        .font(.headline)
                    Text("\(table.guests.count)/\(table.capacity) Plätze")
                        .foregroundStyle(.secondary)
                    if table.isChildTable {
                        Label("Kindertisch", systemImage: "figure.child")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                .padding()

                List {
                    Section("Gäste am Tisch") {
                        ForEach(table.guests) { guest in
                            HStack {
                                if guest.isPinned {
                                    Image(systemName: "pin.fill")
                                        .foregroundStyle(.orange)
                                        .font(.caption)
                                }
                                Circle().fill(guest.partnerAssignment.color).frame(width: 8, height: 8)
                                Text(guest.fullName)
                                Spacer()
                                Button {
                                    guest.isPinned.toggle()
                                } label: {
                                    Image(systemName: guest.isPinned ? "pin.slash" : "pin")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    guard !guest.isPinned else { return }
                                    guest.table = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(guest.isPinned ? Color.secondary.opacity(0.3) : Color.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(guest.isPinned)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                ContentUnavailableView("Kein Tisch gewählt", systemImage: "hand.tap", description: Text("Tippe auf einen Tisch im Raumplan."))
            }

            Divider()

            // Violations banner
            if !violations.isEmpty {
                ViolationBannerView(violations: violations, allGuests: guests)
                    .padding()
            }
        }
        .background(.background)
    }
}

/// Placeholder for auto-assign functionality
struct AutoAssignButton: View {
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]

    var body: some View {
        Button {
            let unassigned = guests.filter { $0.table == nil }
            let result = SeatingOptimizer.solve(
                guests: unassigned,
                tables: tables,
                tags: tags,
                constraints: constraints
            )
            for (guestID, tableID) in result {
                if let guest = guests.first(where: { $0.id == guestID }),
                   let table = tables.first(where: { $0.id == tableID }) {
                    guest.table = table
                }
            }
        } label: {
            Label("Auto-Zuweisen", systemImage: "wand.and.stars")
        }
        .disabled(guests.filter { $0.table == nil }.isEmpty || tables.isEmpty)
    }
}
#endif
