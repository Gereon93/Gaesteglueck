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
        LLMClientFactory.migrateAPIKeyToKeychainIfNeeded()
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
        let schema = Schema(SchemaV5.models)
        let storeURL = try resolveStoreURL()
        // Restore muss VOR dem Öffnen des Containers laufen (offenes
        // SQLite-Handle würde die zurückgespielten Daten beim Beenden wieder
        // überschreiben).
        applyPendingRestoreIfNeeded(storeURL: storeURL)
        try migrateLegacyDefaultStoreIfNeeded(to: storeURL)
        try snapshotPreMigrationBackupIfNeeded(storeURL: storeURL)
        let config = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(
            for: schema,
            configurations: [config]
        )
        fixupLegacyTagCategories(container)
        return container
    }

    private static func resolveStoreURL() throws -> URL {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appDir = appSupport.appendingPathComponent("Gaesteglueck", isDirectory: true)
        try fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("Gaesteglueck.store")
    }

    private static func migrateLegacyDefaultStoreIfNeeded(to storeURL: URL) throws {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let oldStore = appSupport.appendingPathComponent("default.store")
        guard fm.fileExists(atPath: oldStore.path),
              !fm.fileExists(atPath: storeURL.path) else { return }
        for ext in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: oldStore.path + ext)
            let dst = URL(fileURLWithPath: storeURL.path + ext)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
    }

    /// Vor jeder Migration ein Sicherungs-Backup ablegen. Wenn die Migration
    /// destruktiv ausfällt (z.B. SwiftData entscheidet sich für Schema-Rebuild),
    /// kann der User aus diesem Snapshot manuell wiederherstellen.
    private static func snapshotPreMigrationBackupIfNeeded(storeURL: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        let backupDir = storeURL.deletingLastPathComponent().appendingPathComponent("Backups")
        try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
        let stamp = preMigrationTimestamp()
        let target = backupDir.appendingPathComponent("\(stamp)-pre-launch.store")
        if fm.fileExists(atPath: target.path) { return }
        for ext in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: storeURL.path + ext)
            let dst = URL(fileURLWithPath: target.path + ext)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: dst)
            }
        }
        pruneStartupBackups(in: backupDir, keep: 3)
    }

    static let pendingRestoreKey = "pendingRestorePrefix"

    private static func applyPendingRestoreIfNeeded(storeURL: URL) {
        let defaults = UserDefaults.standard
        guard let prefix = defaults.string(forKey: pendingRestoreKey),
              !prefix.isEmpty else { return }
        defaults.removeObject(forKey: pendingRestoreKey)

        let fm = FileManager.default
        let backupDir = storeURL.deletingLastPathComponent().appendingPathComponent("Backups")
        guard let entries = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil) else { return }
        let setFiles = entries.filter { $0.lastPathComponent.hasPrefix(prefix) }
        guard !setFiles.isEmpty else { return }

        let safety = backupDir.appendingPathComponent("\(preMigrationTimestamp())-before-restore.store")
        for ext in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: storeURL.path + ext)
            if fm.fileExists(atPath: src.path) {
                try? fm.copyItem(at: src, to: URL(fileURLWithPath: safety.path + ext))
            }
        }

        for ext in ["", "-shm", "-wal"] {
            let suffix = ext.isEmpty ? ".store" : ".store\(ext)"
            guard let match = setFiles.first(where: { $0.lastPathComponent.hasSuffix(suffix) }) else { continue }
            let dst = URL(fileURLWithPath: storeURL.path + ext)
            try? fm.removeItem(at: dst)
            try? fm.copyItem(at: match, to: dst)
        }
    }

    private static func preMigrationTimestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: Date())
    }

    private static func pruneStartupBackups(in dir: URL, keep: Int) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        var byPrefix: [String: [URL]] = [:]
        for url in entries where url.lastPathComponent.contains("-pre-launch") {
            let name = url.lastPathComponent
            guard name.count >= 13 else { continue }
            let prefix = String(name.prefix(13))
            byPrefix[prefix, default: []].append(url)
        }
        let sorted = byPrefix.keys.sorted(by: >)
        guard sorted.count > keep else { return }
        for prefix in sorted.dropFirst(keep) {
            for url in byPrefix[prefix] ?? [] { try? fm.removeItem(at: url) }
        }
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
