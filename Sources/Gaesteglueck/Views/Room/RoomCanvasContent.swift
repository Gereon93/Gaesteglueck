#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Mittlere Spalte des Sitzplan-Canvas: Grid-Hintergrund, gestrichelte
/// Saal-Outline, Tische, Raum-Labels und Legende — plus die Overlay-Leiste
/// oben (Label/Versionen/Zuweisungen löschen) und der Lösch-Alert.
struct RoomCanvasContent: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var roomPlans: [RoomPlan]
    @Query private var events: [Event]

    @Binding var selectedTable: GuestTable?
    @Binding var showingVersionsSheet: Bool

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
    @AppStorage("canvasShowCoupleMarker") private var canvasShowCoupleMarker = false
    @AppStorage("canvasLegendOffsetX") private var legendOffsetX: Double = 0
    @AppStorage("canvasLegendOffsetY") private var legendOffsetY: Double = 0
    @AppStorage("lastCanvasScale") private var lastCanvasScale: Double = 1.0 / 3.0

    @State private var showingResetAssignmentsAlert = false
    @State private var cachedRoomPlanImageRef: PlatformImage?
    @State private var cachedRoomPlanImageDigest: Int = 0
    @State private var legendDrag: CGSize = .zero
    @State private var canvasSize: CGSize = .zero
    @State private var legendCursorPushed = false

    private var event: Event? { events.first }

    /// Anzeige-Namen für alle sitzenden Gäste gemäß gewähltem Stil. Dedup
    /// (smartDeduped) läuft global über alle Gäste, damit "Steffi F." vs
    /// "Steffi S." auch tischübergreifend eindeutig bleibt.
    /// Globale Nummerierung aller Unverträglichkeiten in der Hochzeit.
    /// Nur sitzende Gäste — wer in der Inbox liegt, taucht in der Legende
    /// noch nicht auf (sonst springen Nummern beim Auto-Place).
    private var canvasSeatingLegend: SeatingLegend {
        SeatingLegend(guests: guests.filter { $0.table != nil })
    }

    private var canvasInfoMode: SeatInfoDisplay {
        SeatInfoDisplay(rawValue: canvasSeatInfoModeRaw) ?? .none
    }

    /// Persistierter Legenden-Offset + laufender Drag, geklemmt.
    private var clampedLegendOffset: CGSize {
        clampLegend(CGSize(
            width: legendOffsetX + legendDrag.width,
            height: legendOffsetY + legendDrag.height
        ))
    }

    /// Hält die Legende auf dem Canvas — mind. ~160pt bleiben sichtbar, damit
    /// sie nie ganz vom Rand verschwindet und unauffindbar wird. Anker ist
    /// bottomLeading: x≥0 nach rechts, y≤0 nach oben.
    private func clampLegend(_ offset: CGSize) -> CGSize {
        guard canvasSize.width > 0, canvasSize.height > 0 else { return offset }
        let maxX = max(0, canvasSize.width - 160)
        let minY = -(max(0, canvasSize.height - 160))
        return CGSize(
            width: min(max(offset.width, 0), maxX),
            height: min(max(offset.height, minY), 0)
        )
    }

    private var canvasDisplayNames: [UUID: String] {
        guard showSeatNames else { return [:] }
        let style = VisualSeatingPlanExporter.NameStyle(rawValue: canvasSeatNameStyleRaw) ?? .full
        return VisualSeatingPlanExporter.displayNames(
            for: tables.flatMap(\.guests), style: style
        )
    }

    @ViewBuilder
    private var roomPlanBackgroundIfAvailable: some View {
        if let image = cachedRoomPlanImageRef {
            Image(platformImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .opacity(0.35)
                .padding(28)
                .allowsHitTesting(false)
        }
    }

    private func refreshRoomPlanImageCache() {
        guard let data = roomPlans.first?.imageData else {
            cachedRoomPlanImageRef = nil
            cachedRoomPlanImageDigest = 0
            return
        }
        let digest = data.hashValue
        if digest == cachedRoomPlanImageDigest, cachedRoomPlanImageRef != nil { return }
        cachedRoomPlanImageRef = PlatformImage(data: data)
        cachedRoomPlanImageDigest = digest
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

    var body: some View {
        canvasContents
    }

    private var canvasContents: some View {
        GeometryReader { geo in
            let scale = computeCanvasScale(canvasSize: geo.size)
            let floorWidth: CGFloat? = roomWidthInCM.map { CGFloat($0) * scale }
            let floorHeight: CGFloat? = roomDepthInCM.map { CGFloat($0) * scale }

            ZStack {
                roomPlanBackgroundIfAvailable
                if canvasShowGrid {
                    CanvasGridBackground()
                }

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

                if canvasShowRoomLabels, let w = floorWidth, let h = floorHeight,
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

                if canvasShowRoomLabels {
                    CanvasLabelsLayer(event: event)
                }
            }
            .environment(\.canvasScale, scale)
            .environment(\.seatDisplayNames, canvasDisplayNames)
            .environment(\.seatingLegend, canvasSeatingLegend)
            .background(Tokens.Colors.bg)
            .onChange(of: scale, initial: true) { _, newScale in
                lastCanvasScale = Double(newScale)
            }
            .onChange(of: geo.size, initial: true) { _, newSize in
                canvasSize = newSize
            }
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
        .overlay(alignment: .bottomLeading) {
            if canvasShowLegend {
            SeatingLegendView(
                legend: canvasSeatingLegend,
                infoDisplay: canvasInfoMode,
                showAge: canvasShowAgeMarkers,
                hasBridalTable: tables.contains(where: \.isBridalTable),
                showTableWarnings: canvasShowTableWarnings,
                showCoupleMarker: canvasShowCoupleMarker,
                chipContent: SeatChipContent(rawValue: canvasSeatChipContentRaw) ?? .initials
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .offset(clampedLegendOffset)
            .gesture(
                DragGesture()
                    .onChanged { legendDrag = $0.translation }
                    .onEnded { value in
                        let combined = CGSize(
                            width: legendOffsetX + value.translation.width,
                            height: legendOffsetY + value.translation.height
                        )
                        let clamped = clampLegend(combined)
                        legendOffsetX = clamped.width
                        legendOffsetY = clamped.height
                        legendDrag = .zero
                    }
            )
            .onHover { inside in
                #if canImport(AppKit)
                // State-Flag verhindert unbalancierten Cursor-Stack (push nur
                // einmal pro Hover; onDisappear räumt auf wenn die View
                // verschwindet während der Cursor noch gepusht ist).
                if inside, !legendCursorPushed {
                    NSCursor.openHand.push(); legendCursorPushed = true
                } else if !inside, legendCursorPushed {
                    NSCursor.pop(); legendCursorPushed = false
                }
                #endif
            }
            .onDisappear {
                #if canImport(AppKit)
                if legendCursorPushed { NSCursor.pop(); legendCursorPushed = false }
                #endif
            }
            .contextMenu {
                Button {
                    legendOffsetX = 0
                    legendOffsetY = 0
                    legendDrag = .zero
                } label: {
                    Label("Legende zurücksetzen", systemImage: "arrow.uturn.backward")
                }
            }
            }
        }
        .alert("Alle Sitzzuweisungen löschen?", isPresented: $showingResetAssignmentsAlert) {
            Button("Abbrechen", role: .cancel) {}
            Button("Löschen", role: .destructive) {
                for guest in guests where !guest.isPinned {
                    guest.table = nil
                    guest.seatIndex = nil
                }
                modelContext.saveOrLog()
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
        modelContext.saveOrLog()
    }
}
#endif
