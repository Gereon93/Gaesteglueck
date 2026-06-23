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
    @AppStorage("canvasShowSeatNames") private var showSeatNames = false
    @AppStorage("canvasSeatNameStyle") private var canvasSeatNameStyleRaw =
        VisualSeatingPlanExporter.NameStyle.full.rawValue
    @AppStorage("canvasSeatInfoMode") private var canvasSeatInfoModeRaw =
        SeatInfoDisplay.none.rawValue
    @AppStorage("canvasShowAgeMarkers") private var canvasShowAgeMarkers = false
    @AppStorage("canvasShowGrid") private var canvasShowGrid = true
    @AppStorage("canvasShowRoomLabels") private var canvasShowRoomLabels = true
    @AppStorage("canvasShowLegend") private var canvasShowLegend = true
    @AppStorage("canvasShowTableWarnings") private var canvasShowTableWarnings = true
    @AppStorage("canvasSeatChipContent") private var canvasSeatChipContentRaw = SeatChipContent.initials.rawValue
    @AppStorage("canvasSeatNameSize") private var canvasSeatNameSize: Double = 9
    @AppStorage("canvasShowCoupleMarker") private var canvasShowCoupleMarker = false

    private var event: Event? { events.first }

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
            for guest in table.guests where guest.seatIndex == nil && guest.countsForSeating {
                for idx in 0..<table.capacity where !used.contains(idx) && !disabled.contains(idx) {
                    guest.seatIndex = idx
                    used.insert(idx)
                    break
                }
            }
        }
    }

    private var lateCancellations: [Guest] { guests.filter(\.isLateCancellation) }

    @ViewBuilder
    private var lateCancellationBanner: some View {
        let ghosts = lateCancellations
        if !ghosts.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "person.fill.xmark")
                    .font(.system(size: 12, weight: .semibold))
                Text(ghosts.count == 1 ? "1 späte Absage"
                                       : "\(ghosts.count) späte Absagen")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("– Plätze sind frei und neu vergebbar; Catering & Service sehen den Wegfall im Caterer-Export")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Tokens.Colors.warn)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Tokens.Colors.warn.opacity(0.10))
        }
    }

    private var canvasLayout: some View {
        VStack(spacing: 0) {
            toolbar
            lateCancellationBanner
            HStack(spacing: 0) {
                RoomGuestInbox()
                    .frame(width: 240)
                Divider().background(Tokens.Colors.line)

                RoomCanvasContent(
                    selectedTable: $selectedTable,
                    showingVersionsSheet: $showingVersionsSheet
                )
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
            #if os(macOS)
            VSplitView {
                RoomInspectorPanel(table: selectedTable, violations: violations)
                    .frame(minHeight: 200)
                SitzplanCoPilotPanel()
                    .frame(minHeight: 280)
            }
            #else
            VStack(spacing: 0) {
                RoomInspectorPanel(table: selectedTable, violations: violations)
                    .frame(minHeight: 200)
                Divider()
                SitzplanCoPilotPanel()
                    .frame(minHeight: 280)
            }
            #endif
        } else {
            RoomInspectorPanel(table: selectedTable, violations: violations)
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
            Menu {
                Section("Sitze") {
                    Toggle("Namen anzeigen", isOn: $showSeatNames)
                    if showSeatNames {
                        Picker("Namen-Stil", selection: $canvasSeatNameStyleRaw) {
                            ForEach(VisualSeatingPlanExporter.NameStyle.allCases) { style in
                                Text(style.rawValue).tag(style.rawValue)
                            }
                        }
                        Picker("Namen-Größe", selection: $canvasSeatNameSize) {
                            Text("Klein").tag(9.0)
                            Text("Mittel").tag(11.0)
                            Text("Groß").tag(13.0)
                            Text("Sehr groß").tag(15.0)
                        }
                    }
                    Picker("Diät & Allergien", selection: $canvasSeatInfoModeRaw) {
                        ForEach(SeatInfoDisplay.allCases) { mode in
                            Label(mode.label, systemImage: mode.icon).tag(mode.rawValue)
                        }
                    }
                    Toggle("Alters-Marker (Kind, Baby …)", isOn: $canvasShowAgeMarkers)
                    Toggle("Brautpaar hervorheben (👰/🤵)", isOn: $canvasShowCoupleMarker)
                    Picker("Kreis-Inhalt", selection: $canvasSeatChipContentRaw) {
                        ForEach(SeatChipContent.allCases) { c in
                            Label(c.label, systemImage: c.icon).tag(c.rawValue)
                        }
                    }
                }
                Section("Raum") {
                    Toggle("Hintergrund-Gitter", isOn: $canvasShowGrid)
                    Toggle("Raum-Labels (Maße, WC, Treppe …)", isOn: $canvasShowRoomLabels)
                    Toggle("Tisch-Warnungen", isOn: $canvasShowTableWarnings)
                    Toggle("Legende", isOn: $canvasShowLegend)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "eye")
                    Text("Anzeige")
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Was im Sitzplan angezeigt wird — alles ein-/ausblendbar")
            AutoPlaceButton()
            #if os(macOS)
            if let event {
                ExportButton(
                    tables: tables,
                    guests: guests,
                    eventName: event.name,
                    date: event.date,
                    partner1Name: event.partner1Name,
                    partner2Name: event.partner2Name
                )
            }
            #endif
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
}
#endif
