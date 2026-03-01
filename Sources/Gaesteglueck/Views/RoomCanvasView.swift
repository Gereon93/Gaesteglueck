#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct RoomCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.name) private var guests: [Guest]
    @Query private var relationships: [Relationship]
    @Query private var roomPlans: [RoomPlan]

    @State private var selectedTable: GuestTable?
    @State private var showingAddTable = false
    @State private var showingFloorPlanSetup = false

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil }
    }

    private var happinessScore: Double {
        HappinessScorer.scoreAllTables(tables, relationships: relationships)
    }

    private var violations: [Violation] {
        HappinessScorer.findViolations(tables: tables, relationships: relationships)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left panel: unassigned guests
            guestInbox
                .frame(width: 250)

            Divider()

            // Center: room canvas
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                #if canImport(UIKit)
                if let roomPlan = roomPlans.first, let imageData = roomPlan.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .opacity(0.3)
                }
                #endif

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

            // Right panel: selected table details + score
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
            #if canImport(UIKit)
            ToolbarItem(placement: .secondaryAction) {
                ExportButton(tables: tables, eventName: "Hochzeit", date: nil)
            }
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    showingFloorPlanSetup = true
                } label: {
                    Label("Raumplan-Foto", systemImage: "photo.badge.plus")
                }
            }
            #endif
        }
        .sheet(isPresented: $showingAddTable) {
            TableFormView()
        }
        #if canImport(UIKit)
        .sheet(isPresented: $showingFloorPlanSetup) {
            if let roomPlan = roomPlans.first {
                FloorPlanSetupView(roomPlan: roomPlan)
            }
        }
        .onAppear {
            // Ensure a RoomPlan exists for floor plan import
            if roomPlans.isEmpty {
                let plan = RoomPlan()
                modelContext.insert(plan)
            }
        }
        #endif
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
                ForEach(unassignedGuests) { guest in
                    GuestRowView(guest: guest)
                        .draggable(guest.id.uuidString)
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
                                Circle().fill(guest.side.color).frame(width: 8, height: 8)
                                Text(guest.name)
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
                                        .foregroundStyle(guest.isPinned ? .secondary.opacity(0.3) : .secondary)
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

            // Violations
            if !violations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Warnungen", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    ForEach(violations) { v in
                        Text(v.description)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }

            Divider()

            AISuggestionView()
        }
        .background(.background)
    }
}
#endif
