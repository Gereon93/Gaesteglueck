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
    @State private var showingVersionsSheet = false
    @State private var showingResetAssignmentsAlert = false
    @State private var inboxTagFilter: UUID? = nil
    #if canImport(AppKit)
    @State private var cachedRoomPlanImageRef: NSImage?
    @State private var cachedRoomPlanImageDigest: Int = 0
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
            FloorPlanSetupView(roomPlan: RoomPlanFactory.ensure(in: modelContext, existing: roomPlans))
        }
        .sheet(isPresented: $showingVersionsSheet) {
            if let event = event {
                LayoutVersionsSheet(event: event)
            }
        }
        .onAppear { backfillSeatIndices() }
        .onAppear {
            if let event = event {
                GuestTable.activeRules = event.seatingRules
            }
        }
        .onChange(of: event?.seatingRulesData) { _, _ in
            if let event = event {
                GuestTable.activeRules = event.seatingRules
            }
        }
    }

    private func backfillSeatIndices() {
        for table in tables {
            var used = Set(table.guests.compactMap(\.seatIndex))
            let disabled = table.disabledSeatIndices
            for guest in table.guests where guest.seatIndex == nil {
                for idx in 0..<table.capacity where !used.contains(idx) && !disabled.contains(idx) {
                    guest.seatIndex = idx
                    used.insert(idx)
                    break
                }
            }
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

    private func firstTagLabel(for guest: Guest) -> String {
        let firstTag = tags.first { $0.guestIDs.contains(guest.id) }
        return firstTag?.name ?? guest.partnerAssignment.displayName(for: events.first)
    }

    // MARK: - Canvas

    @ViewBuilder
    private var roomPlanBackgroundIfAvailable: some View {
        #if canImport(AppKit)
        if let nsImage = cachedRoomPlanImageRef {
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
    private func refreshRoomPlanImageCache() {
        guard let data = roomPlans.first?.imageData else {
            cachedRoomPlanImageRef = nil
            cachedRoomPlanImageDigest = 0
            return
        }
        let digest = data.hashValue
        if digest == cachedRoomPlanImageDigest, cachedRoomPlanImageRef != nil { return }
        cachedRoomPlanImageRef = NSImage(data: data)
        cachedRoomPlanImageDigest = digest
    }
    #endif

    private var canvas: some View {
        canvasContents
    }

    private func formatMeters(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(format: "%.1f", rounded)
    }

    private func computeCanvasScale(canvasSize: CGSize) -> CGFloat {
        let usableWidth = max(canvasSize.width - 56, 200)
        let usableHeight = max(canvasSize.height - 56, 200)
        let widthCM = roomWidthInCM
        let depthCM = roomDepthInCM
        let widthScale: CGFloat? = widthCM.flatMap { value in
            value > 0 ? usableWidth / CGFloat(value) : nil
        }
        let heightScale: CGFloat? = depthCM.flatMap { value in
            value > 0 ? usableHeight / CGFloat(value) : nil
        }
        if let widthScale, let heightScale {
            return min(widthScale, heightScale)
        }
        return widthScale ?? heightScale ?? (1.0 / 3.0)
    }

    /// Raum-Maße aus Event ODER RoomPlan ziehen — beide werden vom User an
    /// verschiedenen Stellen gepflegt. Event ist der Onboarding-Eintrag,
    /// RoomPlan kommt aus dem Floor-Plan-Setup.
    private var roomWidthInCM: Double? {
        event?.roomWidthCM ?? roomPlans.first?.roomWidthCM
    }

    private var roomDepthInCM: Double? {
        event?.roomLengthCM ?? roomPlans.first?.roomDepthCM
    }

    private var canvasContents: some View {
        GeometryReader { geo in
            let scale = computeCanvasScale(canvasSize: geo.size)
            let floorWidth: CGFloat? = roomWidthInCM.map { CGFloat($0) * scale }
            let floorHeight: CGFloat? = roomDepthInCM.map { CGFloat($0) * scale }

            ZStack {
                roomPlanBackgroundIfAvailable
                CanvasGridBackground()

                Group {
                    if let w = floorWidth, let h = floorHeight {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                Tokens.Colors.line2,
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .frame(width: w, height: h)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                Tokens.Colors.line2,
                                style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                            )
                            .padding(28)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if let w = floorWidth, let h = floorHeight,
                   let widthCM = roomWidthInCM, let depthCM = roomDepthInCM {
                    let widthM = widthCM / 100, depthM = depthCM / 100
                    Text("\(formatMeters(widthM)) × \(formatMeters(depthM)) m")
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                        .position(x: geo.size.width / 2 - w / 2 + 50, y: geo.size.height / 2 - h / 2 + 14)
                }

                ForEach(tables) { table in
                    TableCanvasItemView(
                        table: table,
                        isSelected: selectedTable?.id == table.id,
                        onTap: { selectedTable = table }
                    )
                }

                CanvasLabelsLayer(event: event)
            }
            .environment(\.canvasScale, scale)
            .background(Tokens.Colors.bg)
        }
        .overlay(alignment: .topLeading) {
            HStack {
                Button {
                    addNewLabel()
                } label: {
                    Label("Label", systemImage: "text.badge.plus")
                }
                .buttonStyle(.bordered)
                Button {
                    showingVersionsSheet = true
                } label: {
                    Label("Versionen", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(event == nil)
                Button(role: .destructive) {
                    showingResetAssignmentsAlert = true
                } label: {
                    Label("Zuweisungen löschen", systemImage: "person.fill.xmark")
                }
                .buttonStyle(.bordered)
                .disabled(guests.allSatisfy { $0.table == nil })
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .alert("Alle Sitzzuweisungen löschen?", isPresented: $showingResetAssignmentsAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                for guest in guests where !guest.isPinned {
                    guest.table = nil
                    guest.seatIndex = nil
                }
                try? modelContext.save()
            }
        } message: {
            Text("Tische, Labels und Versionen bleiben unverändert. Gepinnte Gäste behalten ihre Zuweisung. Alle anderen Gast-zu-Sitz-Zuordnungen werden entfernt.")
        }
    }

    private func addNewLabel() {
        guard let event = event else { return }
        let label = CanvasLabel(text: "Neues Label", positionX: 0, positionY: 0)
        label.event = event
        modelContext.insert(label)
        try? modelContext.save()
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
