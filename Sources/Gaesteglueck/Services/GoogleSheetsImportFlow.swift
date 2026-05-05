import Foundation

/// Vermittelt zwischen UI und den reinen Services (`GoogleSheetsImporter`,
/// `CSVParser`). Hält den State (`idle`, `loading`, `preview`, `error`),
/// damit die SwiftUI-Schicht nur noch beobachten muss.
actor GoogleSheetsImportFlow {
    enum State: Equatable {
        case idle
        case loading
        case preview([RegistrationRow])
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var stateHistory: [State] = [.idle]

    private let importer: GoogleSheetsImporter

    init(importer: GoogleSheetsImporter) {
        self.importer = importer
    }

    func submit(url input: String) async {
        setState(.loading)
        do {
            let csv = try await importer.fetchCSV(from: input)
            let rows = try CSVParser.parseRegistrations(csv)
            guard !rows.isEmpty else {
                setState(.error("Aus dieser Antwort konnten wir keine Anmeldungen lesen. Ist das Sheet öffentlich freigegeben (Jeder mit dem Link kann ansehen)?"))
                return
            }
            setState(.preview(rows))
        } catch let error as GoogleSheetsImportError {
            setState(.error(error.errorDescription ?? "Unbekannter Fehler."))
        } catch let error as ImportError {
            setState(.error(error.errorDescription ?? "Unbekannter Fehler."))
        } catch {
            setState(.error(error.localizedDescription))
        }
    }

    func reset() {
        setState(.idle)
    }

    private func setState(_ s: State) {
        state = s
        stateHistory.append(s)
    }
}
