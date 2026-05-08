#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// S6 — Tisch- & Raumplan-Canvas (siehe design_handoff_gaesteglueck → S6).
/// Drei Spalten: links 240pt Inbox unzugewiesener Gäste, Mitte Canvas mit
/// Grid-Hintergrund + gestrichelter Saal-Outline + Tischen, rechts 280pt
/// Inspector. KI-Vorschlag floated als AISuggestionCard oben rechts auf
/// dem Canvas, sobald die KI einen Vorschlag liefert.
struct RoomCanvasView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var roomPlans: [RoomPlan]
    @Query private var events: [Event]

    @State private var selectedTable: GuestTable?
    @State private var showingAddTable = false
    @State private var showingFloorPlanSetup = false
    @State private var showingAISheet = false
    @State private var showingRoomSetup = false
    @State private var showingCoPilot = false
    #if canImport(AppKit)
    @State private var cachedRoomPlanImageRef: NSImage?
    @State private var cachedImageDataLength: Int = 0
    #endif

    private var event: Event? { events.first }

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil && $0.needsSeat }
    }

    private var totalCapacity: Int {
        tables.reduce(0) { $0 + $1.capacity }
    }

    private var assigned: Int {
        guests.filter { $0.table != nil }.count
    }

    private var happinessScore: Double {
        HappinessScorer.scoreAllTables(tables, tags: tags, constraints: constraints)
    }

    private var violations: [Violation] {
        HappinessScorer.findViolations(tables: tables, constraints: constraints)
    }

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
        Group {
            if tables.isEmpty {
                RoomSetupView()
            } else {
                canvasLayout
            }
        }
        .sheet(isPresented: $showingRoomSetup) {
            RoomSetupView()
        }
        .sheet(isPresented: $showingAddTable) {
            TableFormView()
        }
        .sheet(isPresented: $showingAISheet) {
            AISuggestionSheet()
        }
        .sheet(isPresented: $showingFloorPlanSetup) {
            FloorPlanSetupView(roomPlan: ensureRoomPlan())
        }
    }

    private var canvasLayout: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                guestInbox
                    .frame(width: 240)
                Divider().background(Tokens.Colors.line)

                canvas
                    .frame(maxWidth: .infinity)

                Divider().background(Tokens.Colors.line)
                rightSideStack
                    .frame(width: 320)
            }
        }
        .background(Tokens.Colors.bg)
    }

    @ViewBuilder
    private var rightSideStack: some View {
        if showingCoPilot {
            VSplitView {
                detailPanel
                    .frame(minHeight: 200)
                SitzplanCoPilotPanel()
                    .frame(minHeight: 280)
            }
        } else {
            detailPanel
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(title: "Sitzplan", subtitle: toolbarSubtitle) {
            ScoreBadgeView(score: happinessScore)
            Button {
                showingRoomSetup = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.3x3")
                    Text("Saal")
                }
            }
            .warmButton(.secondary)
            Button {
                showingAddTable = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Tisch")
                }
            }
            .warmButton(.secondary)
            AutoPlaceButton()
            if let event {
                ExportButton(
                    tables: tables,
                    guests: guests,
                    eventName: event.name,
                    date: event.date
                )
            }
            Button {
                showingFloorPlanSetup = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "photo")
                    Text(roomPlans.first?.imageData == nil ? "Raumplan" : "Plan ändern")
                }
            }
            .warmButton(.secondary)
            Button {
                showingCoPilot.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: showingCoPilot ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                    Text("Co-Pilot")
                }
            }
            .warmButton(showingCoPilot ? .primary : .secondary)
            Button {
                showingAISheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("KI-Vorschlag")
                }
            }
            .warmButton(.primary)
        }
    }

    private var toolbarSubtitle: String {
        var parts: [String] = []
        if let event {
            if !event.venue.isEmpty { parts.append(event.venue) }
            if let w = event.roomWidthCM, let l = event.roomLengthCM {
                let m = String(format: "%.0f × %.0f m", w / 100, l / 100)
                parts.append(m)
            }
        }
        parts.append("\(tables.count) Tische")
        if totalCapacity > 0 {
            parts.append("\(assigned)/\(totalCapacity) Plätze")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Inbox

    private var guestInbox: some View {
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

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(unassignedGrouped, id: \.0) { groupName, group in
                        Text(groupName.uppercased())
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .tracking(0.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.top, 8)

                        ForEach(group) { guest in
                            inboxRow(guest: guest)
                        }
                    }

                    if unassignedGuests.isEmpty {
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
                    } else {
                        Text("Zieh Gäste auf einen Tisch oder benutze die KI.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
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
            Avatar(name: guest.fullName, size: 28, tag: avatarKind(for: guest), diet: dietBadge(for: guest))
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

    private func avatarKind(for guest: Guest) -> Avatar.TagKind {
        let tagsForGuest = tags.filter { $0.guestIDs.contains(guest.id) }
        return tagsForGuest.first.map { kindToAvatar(category: $0.category) } ?? .custom
    }

    private func kindToAvatar(category: TagCategory) -> Avatar.TagKind {
        switch category {
        case .family: .family
        case .friendGroup: .friends
        case .role: .role
        case .activity: .activity
        case .work: .work
        case .custom: .custom
        }
    }

    private func dietBadge(for guest: Guest) -> Avatar.DietBadge? {
        if guest.hasIntolerances { return .allergie }
        switch guest.dietaryChoice.lowercased() {
        case "vegetarisch": return .veg
        case "vegan": return .vegan
        default: return nil
        }
    }

    private func assignGuestAndPeersToTable(guest: Guest, table: GuestTable) -> Bool {
        let group = registrationGroupCompanions(for: guest)
        let allCandidates = [guest] + group.filter { !$0.isPinned && $0.table != table }
        let unpinned = allCandidates.filter { !$0.isPinned }
        let needsSeats = unpinned.count
        let availableSeats = table.capacity - table.guests.count + table.guests.filter { unpinned.contains($0) }.count
        guard needsSeats <= availableSeats else { return false }
        for peer in unpinned {
            peer.table = table
        }
        return true
    }

    private func registrationGroupCompanions(for guest: Guest) -> [Guest] {
        guard let group = guest.registrationGroup else { return [] }
        return guests.filter { $0.id != guest.id && $0.registrationGroup == group }
    }

    private func firstTagLabel(for guest: Guest) -> String {
        let firstTag = tags.first { $0.guestIDs.contains(guest.id) }
        return firstTag?.name ?? guest.partnerAssignment.displayName(for: events.first)
    }

    // MARK: - Canvas

    @MainActor
    private func ensureRoomPlan() -> RoomPlan {
        if let plan = roomPlans.first { return plan }
        let plan = RoomPlan()
        modelContext.insert(plan)
        return plan
    }

    @ViewBuilder
    private var roomPlanBackgroundIfAvailable: some View {
        #if canImport(AppKit)
        if let nsImage = cachedRoomPlanImage {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.35)
                .padding(28)
                .allowsHitTesting(false)
        }
        #endif
    }

    #if canImport(AppKit)
    private var cachedRoomPlanImage: NSImage? {
        guard let data = roomPlans.first?.imageData else { return nil }
        if cachedImageDataLength == data.count, let cached = cachedRoomPlanImageRef {
            return cached
        }
        let img = NSImage(data: data)
        Task { @MainActor in
            cachedImageDataLength = data.count
            cachedRoomPlanImageRef = img
        }
        return img
    }
    #endif

    private var canvas: some View {
        ZStack {
            roomPlanBackgroundIfAvailable
            CanvasGridBackground()
            // Floor outline
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    Tokens.Colors.line2,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .padding(28)

            // Door + Stage labels
            VStack {
                HStack {
                    Text("EINGANG ↓")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                        .padding(.leading, 28)
                        .padding(.top, 10)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    Text("BÜHNE ↑")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                        .padding(.trailing, 28)
                        .padding(.bottom, 10)
                }
            }

            // Tische
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
                    return assignGuestAndPeersToTable(guest: guest, table: table)
                }
            }
        }
        .background(Tokens.Colors.bg)
    }

    // MARK: - Inspector

    @ViewBuilder
    private var detailPanel: some View {
        if let table = selectedTable {
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
                        Text("\(table.shape.rawValue) · \(table.capacity) Plätze · \(table.guests.count) belegt")
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
                                    Avatar(name: guest.fullName, size: 26, tag: avatarKind(for: guest), diet: dietBadge(for: guest), pinned: guest.isPinned)
                                    Text(guest.fullName)
                                        .font(.system(size: 12.5, design: .rounded))
                                        .foregroundStyle(Tokens.Colors.ink)
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

// MARK: - Canvas Grid Background

private struct CanvasGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Tokens.Colors.line), lineWidth: 1)
                x += step
            }
            var y: CGFloat = 0
            while y < size.height {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(Tokens.Colors.line), lineWidth: 1)
                y += step
            }
        }
        .background(Tokens.Colors.bg)
    }
}
#endif
