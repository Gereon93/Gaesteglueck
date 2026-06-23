#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import AppKit

// MARK: - Run export
//
// Erzeugung der gewählten Dateien und die NSPanel-basierte Speicher-Logik.
// Als Extension auf ExportView, damit alle Options-Properties (@State /
// @AppStorage / @Query) direkt verfügbar sind.
extension ExportView {

    struct ExportItem {
        let filename: String
        let data: Data
    }

    func runExport() {
        guard let event else { return }

        let safeName = sanitizeFilenameSegment(event.name)

        var items: [ExportItem] = []
        if includeTableLists || includeCatererSummary {
            let opts = PDFExporter.Options(
                includeTableLists: includeTableLists,
                includeCatererSummary: includeCatererSummary,
                highlightAllergies: highlightAllergies,
                blackAndWhite: blackAndWhite
            )
            items.append(ExportItem(filename: "Sitzplan-\(safeName).pdf",
                                    data: PDFExporter.generatePDF(tables: tables, eventName: event.name,
                                                                  date: event.date, options: opts,
                                                                  partner1Name: event.partner1Name,
                                                                  partner2Name: event.partner2Name)))
        }
        if includeTableCards {
            items.append(ExportItem(filename: "Tischkarten-\(safeName).pdf",
                                    data: TableCardExporter.generatePDF(guests: guests.filter(\.countsForSeating),
                                                                        eventName: event.name,
                                                                        withTitle: tableCardsWithTitle)))
        }
        if includePoster {
            items.append(ExportItem(filename: "Plakat-\(safeName).pdf",
                                    data: PosterExporter.generatePDF(
                                        tables: tables,
                                        unassignedGuests: guests.filter { $0.countsForSeating && $0.table == nil },
                                        eventName: event.name,
                                        date: event.date)))
        }
        if includeVisualPlan {
            let style = VisualSeatingPlanExporter.NameStyle(rawValue: visualPlanNameStyleRaw) ?? .smartDeduped
            items.append(ExportItem(filename: "Bildlicher-Sitzplan-\(safeName).pdf",
                                    data: VisualSeatingPlanExporter.generatePDF(
                                        tables: tables, eventName: event.name,
                                        date: event.date, nameStyle: style)))
        }
        if includeGameCards {
            items.append(ExportItem(filename: "FunFact-Spielkarten-\(safeName).pdf",
                                    data: FunFactGameCardsExporter.generatePDF(guests: guests, eventName: event.name)))
        }
        if includePhoneVCards {
            items.append(ExportItem(filename: "Telefonnummern-\(safeName).vcf",
                                    data: PhoneVCardExporter.generate(guests: guests.filter(\.countsForSeating), eventName: event.name)))
        }
        if includeSpeechGuests {
            items.append(ExportItem(filename: "Gaeste-Rede-\(safeName).md",
                                    data: SpeechGuestExporter.generate(guests: guests, tags: tags, event: event)))
        }
        if includeCanvasPNG {
            let style = VisualSeatingPlanExporter.NameStyle(rawValue: canvasSeatNameStyleRaw) ?? .full
            let names = canvasShowSeatNames
                ? VisualSeatingPlanExporter.displayNames(for: tables.flatMap(\.attendingGuests), style: style)
                : [:]
            let bg = event.roomPlanImageData.flatMap { NSImage(data: $0) }
            let infoMode = SeatInfoDisplay(rawValue: canvasSeatInfoModeRaw) ?? .none
            let chipContent = SeatChipContent(rawValue: canvasSeatChipContentRaw) ?? .initials
            let legend = SeatingLegend(guests: tables.flatMap(\.attendingGuests))
            if let png = CanvasImageExporter.generatePNG(
                tables: tables,
                displayNames: names,
                rules: event.seatingRules,
                scale: CGFloat(lastCanvasScale),
                labels: event.labels,
                background: bg,
                showSeatNames: canvasShowSeatNames,
                infoDisplay: infoMode,
                showAgeMarkers: canvasShowAgeMarkers,
                chipContent: chipContent,
                showTableWarnings: canvasShowTableWarnings,
                showRoomLabels: canvasShowRoomLabels,
                showLegend: canvasShowLegend,
                legend: legend,
                nameFontSize: CGFloat(canvasSeatNameSize),
                showCoupleMarker: canvasShowCoupleMarker,
                coupleNames: [event.partner1Name, event.partner2Name]
            ) {
                items.append(ExportItem(filename: "Sitzplan-Canvas-\(safeName).png", data: png))
            }
        }

        guard !items.isEmpty else { return }
        saveBatch(items, eventName: safeName)
    }

    /// Entfernt Path-Separator und andere Zeichen die im Dateisystem
    /// problematisch sind (`/`, `:` auf macOS, plus Backslash für Cross-OS).
    func sanitizeFilenameSegment(_ raw: String) -> String {
        let invalid: [Character] = ["/", ":", "\\"]
        let cleaned = String(raw.map { invalid.contains($0) ? "-" : $0 })
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Export" : trimmed
    }

    func saveBatch(_ items: [ExportItem], eventName: String) {
        if items.count == 1, let only = items.first {
            saveSingle(data: only.data, name: only.filename)
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Zielordner waehlen"
        panel.message = "Alle Exporte werden in einen neuen Unterordner geschrieben."
        panel.prompt = "Exportieren"

        panel.begin { response in
            guard response == .OK, let parent = panel.url else { return }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd-HHmm"
            // eventName kommt bereits sanitized rein
            let folderName = "Export-\(eventName)-\(fmt.string(from: .now))"
            let target = parent.appendingPathComponent(folderName, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
                for item in items {
                    let fileURL = target.appendingPathComponent(item.filename)
                    try item.data.write(to: fileURL)
                }
                NSWorkspace.shared.activateFileViewerSelecting([target])
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    func saveSingle(data: Data, name: String) {
        let panel = NSSavePanel()
        let suffix = (name as NSString).pathExtension.lowercased()
        let type: UTType = suffix == "vcf" ? .vCard : (suffix == "png" ? .png : .pdf)
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = name
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
}
#endif
#endif
