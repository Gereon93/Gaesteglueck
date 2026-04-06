#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI

struct ExportButton: View {
    let tables: [GuestTable]
    let eventName: String
    let date: Date?

    var body: some View {
        Button {
            exportPDF()
        } label: {
            Label("PDF exportieren", systemImage: "square.and.arrow.up")
        }
    }

    private func exportPDF() {
        let data = PDFExporter.generatePDF(
            tables: tables,
            eventName: eventName,
            date: date
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sitzplan-\(eventName).pdf")
        try? data.write(to: tempURL)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Sitzplan-\(eventName).pdf"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
}
#endif
