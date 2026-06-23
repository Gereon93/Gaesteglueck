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
    @Query private var roomPlans: [RoomPlan]

    @State private var roomWidthMeters: String = ""
    @State private var roomDepthMeters: String = ""
    @State private var hasInitializedDimensions = false

    @State private var showingKonfigurator = false
    @State private var showingFloorPlanSetup = false

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

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                TableTemplateLibrary()
                    .frame(width: 260)
                Divider().background(Tokens.Colors.line)

                centerColumn
                    .frame(maxWidth: .infinity)

                Divider().background(Tokens.Colors.line)
                RoomInventoryPane()
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
                    .minimumScaleFactor(0.65)
                    .truncationMode(.middle)
            }
            .frame(minWidth: 110, alignment: .leading)
            .layoutPriority(1)
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
}
#endif
