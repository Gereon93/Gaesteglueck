#if os(macOS)
#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI

struct ExportButton: View {
    let tables: [GuestTable]
    let guests: [Guest]
    let eventName: String
    let date: Date?
    var partner1Name: String = ""
    var partner2Name: String = ""

    var body: some View {
        Menu {
            Button {
                exportSeatingPlan()
            } label: {
                Label("Sitzplan für Caterer", systemImage: "doc.richtext")
            }

            Button {
                exportTableCards()
            } label: {
                Label("Tischkarten zum Ausdrucken", systemImage: "rectangle.split.2x2")
            }
            .disabled(guests.isEmpty)

            Button {
                exportPoster()
            } label: {
                Label("Plakat (A3) für den Saal", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
            }
            .disabled(tables.isEmpty)
        } label: {
            Label("PDF exportieren", systemImage: "square.and.arrow.up")
        }
    }

    private var unassignedGuests: [Guest] {
        guests.filter { $0.table == nil }
    }

    private func exportPoster() {
        let data = PosterExporter.generatePDF(
            tables: tables,
            unassignedGuests: unassignedGuests,
            eventName: eventName,
            date: date
        )
        savePDF(data: data, suggestedName: "Plakat-\(eventName).pdf")
    }

    private func exportSeatingPlan() {
        let data = PDFExporter.generatePDF(
            tables: tables,
            eventName: eventName,
            date: date,
            partner1Name: partner1Name,
            partner2Name: partner2Name
        )
        savePDF(data: data, suggestedName: "Sitzplan-\(eventName).pdf")
    }

    private func exportTableCards() {
        let data = TableCardExporter.generatePDF(
            guests: guests,
            eventName: eventName
        )
        savePDF(data: data, suggestedName: "Tischkarten-\(eventName).pdf")
    }

    private func savePDF(data: Data, suggestedName: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedName
        panel.begin { response in
            if response == .OK, let url = panel.url {
                data.writeOrLog(to: url)
            }
        }
    }
}
#endif
#endif
