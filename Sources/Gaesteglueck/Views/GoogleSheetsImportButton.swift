#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct GoogleSheetsImportButton: View {
    @State private var showingDialog = false
    @State private var sheetURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var parsedRows: [RegistrationRow]?
    @State private var importedCount: Int?

    var body: some View {
        Button {
            showingDialog = true
        } label: {
            Label("Aus Google Sheets", systemImage: "link")
        }
        .sheet(isPresented: $showingDialog) {
            urlInputDialog
        }
        .sheet(item: Binding(
            get: { parsedRows.map { GoogleSheetsRowsWrapper(rows: $0) } },
            set: { parsedRows = $0?.rows }
        )) { wrapper in
            ImportPreviewView(rows: wrapper.rows) { count in
                importedCount = count
                parsedRows = nil
            }
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

    private var urlInputDialog: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aus Google Sheets importieren")
                    .font(.headline)
                Text("Öffne dein Sheet, klick rechts oben auf 'Teilen' und stell es auf 'Jeder mit dem Link kann ansehen'. Dann den Link hier einfügen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("https://docs.google.com/spreadsheets/d/…", text: $sheetURL, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .disabled(isLoading)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Abbrechen") {
                    showingDialog = false
                    resetDialog()
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isLoading)

                Spacer()

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 4)
                }

                Button("Importieren") {
                    Task { await runImport() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || sheetURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    @MainActor
    private func runImport() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let flow = GoogleSheetsImportFlow(importer: .live)
        await flow.submit(url: sheetURL)
        let state = await flow.state

        switch state {
        case .preview(let rows):
            showingDialog = false
            parsedRows = rows
            sheetURL = ""
        case .error(let message):
            errorMessage = message
        case .idle, .loading:
            break
        }
    }

    private func resetDialog() {
        sheetURL = ""
        errorMessage = nil
    }
}

private struct GoogleSheetsRowsWrapper: Identifiable {
    let id = UUID()
    let rows: [RegistrationRow]
}
#endif
