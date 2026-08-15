#if canImport(SwiftData)
import Testing
import Foundation
import SwiftData
@testable import Gaesteglueck

/// Deckt die Nicht-Werfen-Zusage der Logging-Wrapper ab: beide schlucken den
/// Fehler bewusst, damit der Aufrufer weiterläuft. Genau das muss stabil
/// bleiben — sonst kippt ein fehlgeschlagener Export künftig die UI-Aktion.
@Suite("Logging-Wrapper")
struct AppLogTests {

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV5.models)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @Test("writeOrLog schreibt an einen gültigen Pfad")
    func writeSucceeds() throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gaesteglueck-writeOrLog-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        Data("Tischkarte".utf8).writeOrLog(to: url)

        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(try Data(contentsOf: url) == Data("Tischkarte".utf8))
    }

    @Test("writeOrLog läuft bei nicht schreibbarem Ziel durch, ohne zu werfen")
    func writeFailureIsSwallowed() {
        let unwritable = URL(fileURLWithPath: "/System/gaesteglueck-darf-hier-nicht-schreiben.pdf")

        Data("Sitzplan".utf8).writeOrLog(to: unwritable)

        #expect(!FileManager.default.fileExists(atPath: unwritable.path))
    }

    @Test("writeOrLog läuft auch bei fehlendem Zwischenverzeichnis durch")
    func writeIntoMissingDirectoryIsSwallowed() {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("gaesteglueck-fehlt-\(UUID().uuidString)")
            .appendingPathComponent("export.pdf")

        Data("Sitzplan".utf8).writeOrLog(to: missing)

        #expect(!FileManager.default.fileExists(atPath: missing.path))
    }

    @Test("saveOrLog schreibt Änderungen in den Store")
    @MainActor
    func saveOrLogPersists() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)
        ctx.insert(GuestTable(name: "Tafel 1", shape: .rectangular))

        ctx.saveOrLog()

        let stored = try ctx.fetch(FetchDescriptor<GuestTable>())
        #expect(stored.count == 1)
        #expect(!ctx.hasChanges)
    }

    @Test("saveOrLog auf einem leeren Context ist ein No-op")
    @MainActor
    func saveOrLogWithoutChanges() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        ctx.saveOrLog()

        #expect(!ctx.hasChanges)
    }
}
#endif
