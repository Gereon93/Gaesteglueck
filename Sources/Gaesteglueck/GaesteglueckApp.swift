#if canImport(SwiftUI)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

@main
struct GaesteglueckApp: App {
    nonisolated(unsafe) private static var didActivate = false

    let container: ModelContainer

    init() {
        do {
            self.container = try Self.makeContainer()
        } catch {
            fatalError("ModelContainer konnte nicht erzeugt werden: \(error)")
        }
    }

    /// Persistenz-Setup: explizite ModelConfiguration mit einem dedizierten
    /// `~/Library/Application Support/Gaesteglueck/`-Verzeichnis. Vorteile:
    ///   1. .store-Datei + Backups liegen im gleichen App-eigenen Ordner —
    ///      User findet sie sofort, kein "default.store" mehr neben anderen
    ///      Apps.
    ///   2. Die Backup-Logik im Settings-Sheet legt ihre Snapshots direkt
    ///      daneben in `Backups/` ab.
    ///   3. Wenn vom alten Standardpfad (`default.store`) noch Daten da sind,
    ///      werden sie einmal-malig in den neuen Ordner kopiert — dadurch
    ///      gehen vorhandene Anmeldungen NICHT verloren.
    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Event.self, Guest.self, GuestTable.self,
            Tag.self, Constraint.self, RoomPlan.self,
            TableInventoryItem.self,
        ])
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDir = appSupport.appendingPathComponent("Gaesteglueck", isDirectory: true)
        try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        let storeURL = appDir.appendingPathComponent("Gaesteglueck.store")

        // Einmalige Migration: alte default.store von Apple's Default-Pfad
        // an unseren neuen Ort kopieren, falls noch nicht vorhanden. Wir
        // KOPIEREN statt verschieben — der alte Ort bleibt als Notnagel
        // bestehen bis der User selbst aufräumt.
        let oldStore = appSupport.appendingPathComponent("default.store")
        if fm.fileExists(atPath: oldStore.path),
           !fm.fileExists(atPath: storeURL.path) {
            for ext in ["", "-shm", "-wal"] {
                let src = URL(fileURLWithPath: oldStore.path + ext)
                let dst = URL(fileURLWithPath: storeURL.path + ext)
                if fm.fileExists(atPath: src.path) {
                    try? fm.copyItem(at: src, to: dst)
                }
            }
        }

        let config = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: [config])
        fixupLegacyTagCategories(container)
        return container
    }

    /// Bestehende Tags die VOR der Categorize-Heuristik-Korrektur erstellt
    /// wurden und falsch in `.family` gelandet sind (z.B. "Familien Freunde
    /// Gereon" wurde als Family-Tag geclasst weil "familie" als Substring in
    /// "Familienfreunde" steckt). Beim Start einmalig nachziehen — ist
    /// idempotent: wenn schon korrekt, passiert nichts.
    private static func fixupLegacyTagCategories(_ container: ModelContainer) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Tag>()
        guard let tags = try? context.fetch(descriptor) else { return }
        var changed = false
        for tag in tags {
            let n = tag.name.lowercased()
            if (n.contains("familienfreund") || n.contains("familien freund"))
                && tag.category == .family {
                tag.category = .friendGroup
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    @MainActor
    private static func activateOnceIfNeeded() {
        #if canImport(AppKit)
        guard !didActivate else { return }
        didActivate = true
        // SwiftPM-Executable wird sonst nicht als Foreground-App registriert,
        // dadurch landen Tastatureingaben in anderen Apps.
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .onAppear {
                    #if canImport(AppKit)
                    Self.activateOnceIfNeeded()
                    #endif
                }
        }
        .modelContainer(container)
    }
}
#endif
