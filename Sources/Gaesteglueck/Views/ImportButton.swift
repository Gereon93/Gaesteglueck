#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UniformTypeIdentifiers)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportButton: View {
    @Query private var events: [Event]
    private var event: Event? { events.first }

    @State private var showingFilePicker = false
    @State private var parsedRows: [RegistrationRow]?
    @State private var importError: String?
    @State private var importedCount: Int?

    var body: some View {
        Button {
            showingFilePicker = true
        } label: {
            Label("Gästeliste importieren", systemImage: "square.and.arrow.down")
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.commaSeparatedText, .plainText, .spreadsheet]
        ) { result in
            handleFile(result)
        }
        .sheet(item: Binding(
            get: { parsedRows.map { IdentifiableWrapper(value: $0) } },
            set: { parsedRows = $0?.value }
        )) { wrapper in
            ImportPreviewView(rows: wrapper.value) { count in
                importedCount = count
                parsedRows = nil
            }
        }
        .alert("Import fehlgeschlagen", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .alert("Import erfolgreich", isPresented: Binding(
            get: { importedCount != nil },
            set: { if !$0 { importedCount = nil } }
        )) {
            Button("OK") { importedCount = nil }
        } message: {
            Text("\(importedCount ?? 0) Gäste importiert.")
        }
    }

    private func handleFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }

                let parsed: [RegistrationRow]
                if url.pathExtension.lowercased() == "xlsx" {
                    let data = try Data(contentsOf: url)
                    parsed = try ExcelParser.parseRegistrations(data)
                } else {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    parsed = try CSVParser.parseRegistrations(content)
                }
                let skipped = Set(event?.skippedSourceIDs ?? [])
                parsedRows = skipped.isEmpty ? parsed : parsed.filter { !skipped.contains($0.sourceID) }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

private struct IdentifiableWrapper<T>: Identifiable {
    let id = UUID()
    let value: T
}
#endif
