#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S6a — Saal & Tische einrichten (siehe design_handoff_gaesteglueck →
/// screens-4 → S6a_TablesSetup). Drei Spalten: links Tisch-Vorlagen-
/// Bibliothek, Mitte Saal-Maße + Visualisierung, rechts Inventar +
/// Auto-Vorschlag + Sitzregeln. Wird **vor** S6 (RoomCanvasView)
/// durchlaufen — sobald Tische da sind, geht's weiter zum Sitzplan.
struct RoomSetupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var events: [Event]
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]
    @Query private var guests: [Guest]

    @State private var roomWidthMeters: String = ""
    @State private var roomDepthMeters: String = ""
    @State private var hasInitializedDimensions = false

    // Custom-Tisch State — eigene Maße statt Template
    @State private var customShape: TableShape = .round
    @State private var customDiameter: String = "150"
    @State private var customWidth: String = "180"
    @State private var customDepth: String = "90"
    @State private var customName: String = ""
    @State private var customIsBridal: Bool = false
    @State private var customIsChild: Bool = false
    @State private var showingKonfigurator = false
    @State private var showingFloorPlanSetup = false
    @Query private var roomPlans: [RoomPlan]

    private var event: Event? { events.first }

    private var totalCapacity: Int {
        tables.reduce(0) { $0 + $1.capacity }
    }

    private var guestCount: Int {
        guests.count
    }

    private var capacityState: CapacityState {
        guard guestCount > 0 else { return .neutral }
        if totalCapacity >= guestCount { return .ok(spare: totalCapacity - guestCount) }
        return .short(missing: guestCount - totalCapacity)
    }

    enum CapacityState {
        case neutral
        case ok(spare: Int)
        case short(missing: Int)
    }

    private static let templates: [TableTemplate] = [
        .init(shape: .round, diameter: 160, width: 0, depth: 0, capacity: 8, name: "Rund · 8 Plätze", size: "160 cm Ø", hint: "Klassisch", isBridal: false),
        .init(shape: .round, diameter: 130, width: 0, depth: 0, capacity: 6, name: "Rund · 6 Plätze", size: "130 cm Ø", hint: "Familienkreis", isBridal: false),
        .init(shape: .round, diameter: 180, width: 0, depth: 0, capacity: 10, name: "Rund · 10 Plätze", size: "180 cm Ø", hint: "Großtisch", isBridal: false),
        .init(shape: .rectangular, diameter: 0, width: 320, depth: 90, capacity: 10, name: "Brauttafel · 10 Plätze", size: "320 × 90 cm", hint: "Brautpaar + Trauzeugen", isBridal: true),
        .init(shape: .rectangular, diameter: 0, width: 420, depth: 90, capacity: 14, name: "Lange Tafel · 14", size: "420 × 90 cm", hint: "Familie", isBridal: false),
        .init(shape: .square, diameter: 0, width: 100, depth: 100, capacity: 4, name: "Quadrat · 4 Plätze", size: "100 × 100 cm", hint: "Kinder", isBridal: false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                templateLibrary
                    .frame(width: 260)
                Divider().background(Tokens.Colors.line)

                centerColumn
                    .frame(maxWidth: .infinity)

                Divider().background(Tokens.Colors.line)
                inventoryPane
                    .frame(width: 280)
            }
        }
        .background(Tokens.Colors.bg)
        .onAppear {
            if !hasInitializedDimensions {
                if let event {
                    if let w = event.roomWidthCM { roomWidthMeters = String(format: "%.0f", w / 100) }
                    if let l = event.roomLengthCM { roomDepthMeters = String(format: "%.0f", l / 100) }
                }
                hasInitializedDimensions = true
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(
            title: "Saal & Tische einrichten",
            subtitle: "Bevor wir Gäste platzieren — sag uns, was eure Location an Tischen hergibt."
        ) {
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
                showingKonfigurator = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("KI-Vorschlag")
                }
            }
            .warmButton(.secondary)
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text(tables.isEmpty ? "Schließen" : "Fertig — zum Sitzplan")
                }
            }
            .warmButton(.primary)
        }
        .sheet(isPresented: $showingKonfigurator) {
            SaalKonfiguratorView()
        }
        .sheet(isPresented: $showingFloorPlanSetup) {
            FloorPlanSetupView(roomPlan: RoomPlanFactory.ensure(in: modelContext, existing: roomPlans))
        }
    }

    // MARK: - Template Library

    private var templateLibrary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BIBLIOTHEK")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                    Text("Tisch-Vorlagen")
                        .font(Tokens.Typography.displayXS)
                        .foregroundStyle(Tokens.Colors.ink)
                    Text("Klick zum Hinzufügen oder zieh in den Saal rechts.")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineSpacing(2)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    ForEach(Self.templates) { template in
                        templateRow(template)
                    }
                }
                .padding(.horizontal, 12)

                Rectangle()
                    .fill(Tokens.Colors.line)
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                customTableSection
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    @ViewBuilder
    private var customTableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EIGENER TISCH")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.5)
                .padding(.horizontal, 6)
                .padding(.top, 4)

            VStack(spacing: 8) {
                Picker("Form", selection: $customShape) {
                    ForEach(TableShape.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                if customShape == .round {
                    customField(label: "Durchmesser (cm)", value: $customDiameter)
                } else {
                    HStack(spacing: 6) {
                        customField(label: "Breite (cm)", value: $customWidth)
                        customField(label: "Tiefe (cm)", value: $customDepth)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 10))
                    Text("Plätze: \(customComputedCapacity) (60 cm pro Platz)")
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundStyle(Tokens.Colors.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)

                customField(label: "Name (optional)", value: $customName, isNumeric: false, placeholder: nameForCustomTable())

                Toggle("Brautpaartisch", isOn: $customIsBridal)
                    .font(.system(size: 11.5, design: .rounded))
                Toggle("Kindertisch", isOn: $customIsChild)
                    .font(.system(size: 11.5, design: .rounded))

                Button {
                    addCustomTable()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Tisch hinzufügen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .warmButton(.primary, size: .sm)
                .disabled(!customTableValid)
            }
            .padding(10)
            .background(Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    @ViewBuilder
    private func customField(label: String, value: Binding<String>, isNumeric: Bool = true, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var customTableValid: Bool {
        switch customShape {
        case .round:
            return Double(customDiameter).map { $0 > 0 } ?? false
        case .rectangular, .square:
            let w = Double(customWidth) ?? 0
            let d = Double(customDepth) ?? 0
            return w > 0 && d > 0
        }
    }

    /// Live-Preview der Kapazität wie sie GuestTable.capacity berechnen würde.
    /// 60 cm pro Sitzplatz, Rechtecke bekommen 2 Plätze Abzug für die Schmalseiten.
    private var customComputedCapacity: Int {
        let seatWidth: Double = 60
        switch customShape {
        case .round:
            let dia = Double(customDiameter) ?? 0
            guard dia > 0 else { return 0 }
            return Int(Double.pi * dia / seatWidth)
        case .rectangular:
            let w = Double(customWidth) ?? 0
            let d = Double(customDepth) ?? 0
            let perimeter = 2 * (w + d)
            return max(Int(perimeter / seatWidth) - 2, 4)
        case .square:
            let w = Double(customWidth) ?? 0
            return Int(4 * w / seatWidth)
        }
    }

    private func nameForCustomTable() -> String {
        let nextNumber = tables.count + 1
        if customIsBridal { return "Brauttafel" }
        if customIsChild { return "Kindertisch" }
        switch customShape {
        case .rectangular: return "Tafel \(nextNumber)"
        case .square: return "Tisch \(nextNumber)"
        case .round: return "T\(nextNumber)"
        }
    }

    private func addCustomTable() {
        let name = customName.trimmingCharacters(in: .whitespaces).isEmpty
            ? nameForCustomTable()
            : customName.trimmingCharacters(in: .whitespaces)
        let dia = Double(customDiameter) ?? 0
        let w = Double(customWidth) ?? 0
        let d = Double(customDepth) ?? 0
        // Kapazität ergibt sich aus den Maßen (siehe GuestTable.capacity).
        // Wer mehr Plätze braucht muss die Maße anpassen.
        let table = GuestTable(
            name: name,
            shape: customShape,
            diameter: customShape == .round ? dia : 0,
            width: customShape == .round ? 0 : w,
            depth: customShape == .round ? 0 : d,
            positionX: nextPosition().x,
            positionY: nextPosition().y,
            isChildTable: customIsChild,
            isBridalTable: customIsBridal
        )
        modelContext.insert(table)
        customName = ""
        customIsBridal = false
        customIsChild = false
    }

    private func templateRow(_ template: TableTemplate) -> some View {
        Button {
            addTable(from: template)
        } label: {
            HStack(spacing: 12) {
                miniShape(template.shape)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                    Text("\(template.size) · \(template.hint)")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("+")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Tokens.Colors.accentTint)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func miniShape(_ shape: TableShape) -> some View {
        switch shape {
        case .round:
            Circle()
                .fill(Tokens.Colors.accentTint)
                .overlay(Circle().strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.5))
                .frame(width: 26, height: 26)
        case .square:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Tokens.Colors.sageTint)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Tokens.Colors.sageSoft, lineWidth: 1.5))
                .frame(width: 26, height: 26)
        case .rectangular:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(hex: "#f5ede0"))
                .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(Color(hex: "#ecdfc7"), lineWidth: 1.5))
                .frame(width: 32, height: 18)
        }
    }

    // MARK: - Center column

    private var centerColumn: some View {
        VStack(spacing: 0) {
            roomHeader
            Divider().background(Tokens.Colors.line)
            roomVisualization
        }
    }

    private var roomHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FESTSAAL")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text(event?.venue ?? "Location noch offen")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
            }
            Rectangle()
                .fill(Tokens.Colors.line)
                .frame(width: 1, height: 32)

            dimInputCell(label: "BREITE", value: $roomWidthMeters, unit: "m") {
                event?.roomWidthCM = (Double(roomWidthMeters) ?? 0) * 100
            }
            dimInputCell(label: "TIEFE", value: $roomDepthMeters, unit: "m") {
                event?.roomLengthCM = (Double(roomDepthMeters) ?? 0) * 100
            }
            dimReadCell(label: "TISCHE", value: "\(tables.count)")
            dimReadCell(label: "PLÄTZE", value: "\(totalCapacity)")
            Spacer()

            capacityIndicator
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Tokens.Colors.surface)
    }

    private func dimInputCell(label: String, value: Binding<String>, unit: String?, onSubmit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.5)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                TextField("", text: value)
                    .textFieldStyle(.plain)
                    .font(Tokens.Typography.display(size: 18))
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(width: 36)
                    .monospacedDigit()
                    .onSubmit(onSubmit)
                if let unit {
                    Text(unit)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func dimReadCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.5)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Text(value)
                .font(Tokens.Typography.display(size: 18))
                .foregroundStyle(Tokens.Colors.ink)
                .monospacedDigit()
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    @ViewBuilder
    private var capacityIndicator: some View {
        switch capacityState {
        case .neutral:
            EmptyView()
        case .ok(let spare):
            HStack(spacing: 6) {
                Circle().fill(Tokens.Colors.sage).frame(width: 7, height: 7)
                Text("Reicht für \(guestCount) Gäste · +\(spare) Plätze frei")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.sage)
            }
        case .short(let missing):
            HStack(spacing: 6) {
                Circle().fill(Tokens.Colors.warn).frame(width: 7, height: 7)
                Text("Noch \(missing) Plätze fehlen für \(guestCount) Gäste")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.warn)
            }
        }
    }

    // MARK: - Visualization

    private var roomVisualization: some View {
        ZStack {
            Tokens.Colors.bg3
            CanvasGridDots()

            // Floor outline
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    Tokens.Colors.line2,
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .padding(32)

            // Tables
            ForEach(tables) { table in
                SetupTableShape(table: table)
                    .position(
                        x: max(60, table.positionX),
                        y: max(60, table.positionY)
                    )
            }

            // Floor label
            VStack {
                HStack {
                    if !roomWidthMeters.isEmpty || !roomDepthMeters.isEmpty {
                        Text("\(roomWidthMeters.isEmpty ? "?" : roomWidthMeters) × \(roomDepthMeters.isEmpty ? "?" : roomDepthMeters) m")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .tracking(0.5)
                            .padding(.leading, 46)
                            .padding(.top, 42)
                    }
                    Spacer()
                }
                Spacer()
            }

            // Stage label
            VStack {
                Spacer()
                Text("BÜHNE")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .tracking(0.6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Tokens.Colors.ink4)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(.bottom, 44)
            }

            // Floating Tipp
            VStack {
                HStack {
                    Spacer()
                    floatingTipp
                        .frame(maxWidth: 280)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
                Spacer()
            }
        }
        .background(Tokens.Colors.bg3)
    }

    private var floatingTipp: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Tokens.Colors.accent)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tipp")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Lass die Position grob — wir feinjustieren beim Platzieren der Gäste.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Tokens.Colors.accentTint)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous))
    }

    // MARK: - Inventory

    private var inventoryPane: some View {
        ScrollView {
            VStack(spacing: 0) {
                InspectorSection("Inventar") {
                    if tables.isEmpty {
                        Text("Noch keine Tische — wähl links eine Vorlage.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(inventoryGroups, id: \.id) { group in
                                inventoryRow(group: group)
                            }
                        }
                    }
                }

                if guestCount > 0 {
                    InspectorSection("Auto-Vorschlag") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(autoSuggestionText)
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink2)
                                .lineSpacing(3)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Tokens.Colors.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(Tokens.Colors.line, lineWidth: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            HStack(spacing: 6) {
                                Button("Anwenden") { applyAutoSuggestion() }
                                    .warmButton(.primary, size: .sm)
                                Button("Anpassen…") {}
                                    .warmButton(.secondary, size: .sm)
                            }
                        }
                    }
                }

                InspectorSection("Sitzregeln") {
                    VStack(spacing: 4) {
                        ruleRow("Sitz-Abstand", "60 cm/Pers.")
                        ruleRow("Mindestabstand Tische", "80 cm")
                        ruleRow("Gangbreite", "120 cm")
                    }
                }
            }
        }
        .background(Tokens.Colors.bg2)
    }

    private struct InventoryGroup: Identifiable {
        let id = UUID()
        let shape: TableShape
        let capacity: Int
        let count: Int
        let displayName: String
        let representativeID: UUID
    }

    private var inventoryGroups: [InventoryGroup] {
        let grouped = Dictionary(grouping: tables, by: { GroupKey(shape: $0.shape, capacity: $0.capacity) })
        return grouped.map { key, tablesInGroup in
            let count = tablesInGroup.count
            let display = displayName(for: key, count: count)
            return InventoryGroup(
                shape: key.shape,
                capacity: key.capacity,
                count: count,
                displayName: display,
                representativeID: tablesInGroup.first?.id ?? UUID()
            )
        }
        .sorted { $0.displayName < $1.displayName }
    }

    private struct GroupKey: Hashable {
        let shape: TableShape
        let capacity: Int
    }

    private func displayName(for key: GroupKey, count: Int) -> String {
        let shapeName: String
        switch key.shape {
        case .round: shapeName = "Rund"
        case .rectangular: shapeName = "Tafel"
        case .square: shapeName = "Quadrat"
        }
        return "\(shapeName) · \(key.capacity) Plätze"
    }

    private func inventoryRow(group: InventoryGroup) -> some View {
        HStack(spacing: 10) {
            miniShape(group.shape)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.displayName)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("\(group.capacity) Plätze\(group.count > 1 ? " · \(group.count)× = \(group.capacity * group.count)" : "")")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                counterButton("−") { removeOne(matching: group) }
                Text("\(group.count)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .frame(minWidth: 14)
                    .monospacedDigit()
                counterButton("+") { addOne(matching: group) }
            }
        }
        .padding(.vertical, 2)
    }

    private func counterButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .frame(width: 18, height: 18)
                .background(Tokens.Colors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func ruleRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
    }

    private var autoSuggestionText: String {
        guard guestCount > 0 else { return "Sobald Gäste angelegt sind, schlage ich eine Tisch-Konfiguration vor." }
        let mainCount = max(1, guestCount / 8)
        return "Für \(guestCount) Gäste schlage ich vor: 1 Brauttafel · \(mainCount) runde Tische à 8 · 1 Kindertisch."
    }

    // MARK: - Actions

    private func addTable(from template: TableTemplate) {
        let nextNumber = tables.count + 1
        let name = nameForNewTable(template: template, nextNumber: nextNumber)
        let table = GuestTable(
            name: name,
            shape: template.shape,
            diameter: template.diameter,
            width: template.width,
            depth: template.depth,
            positionX: nextPosition().x,
            positionY: nextPosition().y,
            isChildTable: template.capacity == 4,
            isBridalTable: template.isBridal
        )
        modelContext.insert(table)
    }

    private func nameForNewTable(template: TableTemplate, nextNumber: Int) -> String {
        if template.isBridal { return "Brauttafel" }
        switch template.shape {
        case .rectangular: return "Tafel \(nextNumber)"
        case .square: return "Kindertisch"
        case .round: return "T\(nextNumber)"
        }
    }

    private func nextPosition() -> (x: Double, y: Double) {
        let cols = 4
        let spacing: Double = 140
        let index = tables.count
        let col = index % cols
        let row = index / cols
        return (x: 100 + Double(col) * spacing, y: 100 + Double(row) * spacing)
    }

    private func addOne(matching group: InventoryGroup) {
        guard let template = Self.templates.first(where: { $0.shape == group.shape && $0.capacity == group.capacity }) else {
            // Falls keine passende Vorlage: dupliziere ein existierendes Tisch-Set
            if let existing = tables.first(where: { $0.shape == group.shape && $0.capacity == group.capacity }) {
                let duplicate = GuestTable(
                    name: "T\(tables.count + 1)",
                    shape: existing.shape,
                    diameter: existing.diameter,
                    width: existing.width,
                    depth: existing.depth,
                    positionX: nextPosition().x,
                    positionY: nextPosition().y,
                    isChildTable: existing.isChildTable
                )
                modelContext.insert(duplicate)
            }
            return
        }
        addTable(from: template)
    }

    private func removeOne(matching group: InventoryGroup) {
        guard let toRemove = tables.first(where: {
            $0.shape == group.shape && $0.capacity == group.capacity && $0.guests.isEmpty
        }) ?? tables.first(where: { $0.shape == group.shape && $0.capacity == group.capacity }) else { return }
        for guest in toRemove.guests { guest.table = nil }
        modelContext.delete(toRemove)
    }

    private func applyAutoSuggestion() {
        guard guestCount > 0 else { return }
        let mainCount = max(1, guestCount / 8)
        if let bridal = Self.templates.first(where: { $0.shape == .rectangular && $0.capacity == 10 }) {
            addTable(from: bridal)
        }
        if let round8 = Self.templates.first(where: { $0.shape == .round && $0.capacity == 8 }) {
            for _ in 0..<mainCount { addTable(from: round8) }
        }
        if let kids = Self.templates.first(where: { $0.shape == .square }) {
            addTable(from: kids)
        }
    }
}

// MARK: - Template

private struct TableTemplate: Identifiable {
    let id = UUID()
    let shape: TableShape
    let diameter: Double
    let width: Double
    let depth: Double
    let capacity: Int
    let name: String
    let size: String
    let hint: String
    let isBridal: Bool
}

// MARK: - Setup Table Shape

private struct SetupTableShape: View {
    let table: GuestTable

    var body: some View {
        VStack(spacing: 2) {
            shape
            Text(table.name)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .lineLimit(1)
            Text("\(table.capacity) Pl.")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var shape: some View {
        switch table.shape {
        case .round:
            ZStack {
                Circle().fill(Tokens.Colors.surface)
                Circle().strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.5)
            }
            .frame(width: 86, height: 86)
            .cardShadow()
        case .rectangular:
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Tokens.Colors.surface)
                RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.5)
            }
            .frame(width: 180, height: 56)
            .cardShadow()
        case .square:
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Tokens.Colors.surface)
                RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Tokens.Colors.sageSoft, lineWidth: 1.5)
            }
            .frame(width: 70, height: 70)
            .cardShadow()
        }
    }
}

// MARK: - Grid

private struct CanvasGridDots: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 20
            var x: CGFloat = 0
            while x < size.width {
                var y: CGFloat = 0
                while y < size.height {
                    let dot = Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1))
                    context.fill(dot, with: .color(Color.black.opacity(0.05)))
                    y += step
                }
                x += step
            }
        }
    }
}
#endif
