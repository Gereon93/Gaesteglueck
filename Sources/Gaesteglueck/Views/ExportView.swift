#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import AppKit

/// S8 — Export (siehe design_handoff_gaesteglueck → S8). Vollscreen mit
/// linker A4-Vorschau auf Parchment-Hintergrund und rechter 320pt-Spalte
/// mit Optionen — was exportieren, mit welchen Optionen, welches Format.
///
/// Die einzelnen Bereiche sind über Extensions auf mehrere Dateien verteilt:
/// - `ExportView+Previews.swift` — die Per-Format-Vorschauen
/// - `ExportView+Options.swift` — die rechte Optionen-Spalte
/// - `ExportView+Export.swift` — Dateierzeugung und Speichern
/// - `ExportPhonePreview.swift` — der Telefon-Tab mit Kontakt-Abgleich
/// - `ExportComponents.swift` — `CheckRow` / `RadioRow`
struct ExportView: View {
    @Query var events: [Event]
    @Query var tables: [GuestTable]
    @Query(sort: \Guest.firstName) var guests: [Guest]
    @Query var tags: [Tag]

    @State var includeTableLists = true
    @State var includeCatererSummary = true
    @State var includeTableCards = false
    @State var includePoster = false
    @State var includeGameCards = false
    @State var includePhoneVCards = false
    @State var includeCanvasPNG = false
    @State var includeSpeechGuests = false
    @AppStorage("tableCardsWithTitle") var tableCardsWithTitle: Bool = false
    @Query var canvasLabels: [CanvasLabel]
    @AppStorage("includeVisualPlan") var includeVisualPlan: Bool = true
    @AppStorage("visualPlanNameStyle") var visualPlanNameStyleRaw: String = VisualSeatingPlanExporter.NameStyle.smartDeduped.rawValue
    @AppStorage("canvasSeatNameStyle") var canvasSeatNameStyleRaw: String = VisualSeatingPlanExporter.NameStyle.full.rawValue
    @AppStorage("lastCanvasScale") var lastCanvasScale: Double = 1.0 / 3.0
    // Live-Canvas-Anzeige-Toggles — werden in die Canvas-PNG übernommen.
    @AppStorage("canvasShowSeatNames") var canvasShowSeatNames = false
    @AppStorage("canvasSeatInfoMode") var canvasSeatInfoModeRaw = SeatInfoDisplay.none.rawValue
    @AppStorage("canvasShowAgeMarkers") var canvasShowAgeMarkers = false
    @AppStorage("canvasSeatChipContent") var canvasSeatChipContentRaw = SeatChipContent.initials.rawValue
    @AppStorage("canvasShowTableWarnings") var canvasShowTableWarnings = true
    @AppStorage("canvasShowRoomLabels") var canvasShowRoomLabels = true
    @AppStorage("canvasShowLegend") var canvasShowLegend = true
    @AppStorage("canvasSeatNameSize") var canvasSeatNameSize: Double = 9
    @AppStorage("canvasShowCoupleMarker") var canvasShowCoupleMarker = false

    @State var highlightAllergies = true
    @State var withWavePattern = true
    @State var blackAndWhite = false

    @State var format: ExportFormat = .pdf
    @State private var previewTab: PreviewTab = .sitzplan

    // Telefon-Abgleich-Status — bewusst hier im Parent, damit er beim
    // Tab-Wechsel erhalten bleibt (der Telefon-Subview wird sonst verworfen
    // und käme mit leerem Status zurück).
    @State private var phoneVerify: [UUID: ExportPhonePreview.PhoneVerifyStatus] = [:]
    @State private var phoneVerifyRunning = false
    @State private var phoneVerifyError: String?
    @State private var mismatchQueue: [ExportPhonePreview.PendingMismatch] = []

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case a3 = "Druckbogen A3"

        var subtitle: String {
            switch self {
            case .pdf: "Beste Qualität, druckfertig"
            case .a3: "Mehrere Tische pro Seite"
            }
        }
    }

    enum PreviewTab: String, CaseIterable, Identifiable {
        case sitzplan = "Sitzplan"
        case caterer = "Caterer"
        case tischkarten = "Tischkarten"
        case plakat = "Plakat"
        case bildlich = "Bildlich"
        case telefon = "Telefon"
        var id: String { rawValue }
    }

    var event: Event? { events.first }
    var firstTable: GuestTable? { tables.sorted { $0.name < $1.name }.first }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                previewPane
                    .frame(maxWidth: .infinity)
                Divider().background(Tokens.Colors.line)
                optionsPane
                    .frame(width: 320)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(
            title: "Export",
            subtitle: "PDFs für Caterer, Druckerei und Tischkarten."
        ) {
            Button {
                runExport()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Drucken / Speichern")
                }
            }
            .warmButton(.primary)
            .disabled(event == nil)
        }
    }

    // MARK: - Preview pane

    private var previewPane: some View {
        VStack(spacing: 0) {
            previewTabBar
            ScrollView {
                VStack {
                    Spacer().frame(height: 32)
                    selectedPreview
                    Spacer().frame(height: 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    private var previewTabBar: some View {
        HStack(spacing: 4) {
            ForEach(PreviewTab.allCases) { tab in
                Button {
                    previewTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(previewTab == tab ? Tokens.Colors.ink : Tokens.Colors.ink3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(previewTab == tab ? Tokens.Colors.accentTint : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    @ViewBuilder
    private var selectedPreview: some View {
        switch previewTab {
        case .sitzplan: a4Preview
        case .caterer: catererPreview
        case .tischkarten: tischkartenPreview
        case .plakat: plakatPreview
        case .bildlich: bildlichPreview
        case .telefon:
            ExportPhonePreview(
                phoneVerify: $phoneVerify,
                phoneVerifyRunning: $phoneVerifyRunning,
                phoneVerifyError: $phoneVerifyError,
                mismatchQueue: $mismatchQueue
            )
        }
    }
}
#endif
#endif
