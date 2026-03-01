#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

struct ExportButton: View {
    let tables: [GuestTable]
    let eventName: String
    let date: Date?

    @State private var showingShareSheet = false
    @State private var pdfURL: URL?

    var body: some View {
        Button {
            exportPDF()
        } label: {
            Label("PDF exportieren", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = pdfURL {
                ShareLink(item: url)
            }
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
        pdfURL = tempURL
        showingShareSheet = true
    }
}
#endif
