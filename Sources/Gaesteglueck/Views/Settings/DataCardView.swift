#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Daten — Speicherort, Backups, Restore und destruktive Reset-Aktionen.
struct DataCardView: View {
    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage(LLMDebugLog.enabledKey) private var llmDebugLogEnabled = false

    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @Query private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var tables: [GuestTable]
    @Query private var roomPlans: [RoomPlan]

    @State private var resetTarget: ResetTarget? = nil
    @State private var restoreCandidate: BackupSet? = nil
    @State private var restoreArmed: Bool = false
    @State private var dataActionMessage: String? = nil
    @State private var dataActionMessageIsError: Bool = false

    struct BackupSet: Identifiable, Equatable {
        let prefix: String
        let label: String
        var id: String { prefix }
    }

    enum ResetTarget: String, Identifiable {
        case guests, tags, tables, guestsAndTags, everything
        var id: String { rawValue }
    }

    var body: some View {
        dataCard
            .alert(
                "Aus Backup wiederherstellen?",
                isPresented: Binding(
                    get: { restoreCandidate != nil },
                    set: { if !$0 { restoreCandidate = nil } }
                ),
                presenting: restoreCandidate
            ) { set in
                Button("Abbrechen", role: .cancel) { restoreCandidate = nil }
                Button("Wiederherstellen & neu starten", role: .destructive) {
                    armRestore(set)
                }
            } message: { set in
                Text("Überschreibt ALLE aktuellen Daten mit dem Stand vom \(set.label). "
                     + "Der jetzige Stand wird vorher automatisch als Sicherheits-Backup "
                     + "gespeichert. Die App muss dafür neu starten.")
            }
            .alert("Neustart nötig", isPresented: $restoreArmed) {
                Button("Jetzt beenden") {
                    #if canImport(AppKit)
                    NSApplication.shared.terminate(nil)
                    #endif
                }
                Button("Später", role: .cancel) {}
            } message: {
                Text("Beim nächsten Start wird das Backup eingespielt. Beende die App "
                     + "jetzt und starte sie neu.")
            }
    }

    // MARK: - Data Card

    private var dataCard: some View {
        SettingsCard(
            title: "Daten",
            subtitle: "Gästeglück speichert alle Daten in einem lokalen SwiftData-Container."
        ) {
            VStack(spacing: 10) {
                SettingsRow(label: "Speicherort") {
                    Text("~/Library/Application Support/Gaesteglueck/")
                        .font(Tokens.Typography.mono)
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                SettingsRow(label: "Auto-Backup täglich") {
                    GGToggle(isOn: $autoBackup)
                }
                SettingsRow(label: "KI-Debug-Log (enthält Gästedaten!)") {
                    GGToggle(isOn: $llmDebugLogEnabled)
                }
                HStack(spacing: 8) {
                    Button("Im Finder anzeigen") { revealStoreInFinder() }
                        .warmButton(.secondary, size: .sm)
                    Button("Backup jetzt erstellen") { createBackupNow() }
                        .warmButton(.secondary, size: .sm)
                    let sets = availableBackupSets()
                    Menu("Aus Backup wiederherstellen") {
                        if sets.isEmpty {
                            Text("Keine Backups vorhanden")
                        } else {
                            ForEach(sets, id: \.prefix) { set in
                                Button(set.label) { restoreCandidate = set }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .disabled(sets.isEmpty)
                    Spacer()
                }
                .padding(.top, 4)

                if let dataActionMessage {
                    HStack(spacing: 6) {
                        Image(systemName: dataActionMessageIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(dataActionMessageIsError ? Tokens.Colors.warn : Tokens.Colors.sage)
                        Text(dataActionMessage)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink2)
                            .lineLimit(2)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background((dataActionMessageIsError ? Tokens.Colors.warn : Tokens.Colors.sage).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                // Reset / Wipe — explizit destruktive Aktionen am Ende
                Divider().background(Tokens.Colors.line).padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Daten zurücksetzen")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)

                    HStack(spacing: 6) {
                        Button("Gäste (\(guests.count))") { resetTarget = .guests }
                            .warmButton(.secondary, size: .sm)
                            .disabled(guests.isEmpty)
                        Button("Tags (\(tags.count))") { resetTarget = .tags }
                            .warmButton(.secondary, size: .sm)
                            .disabled(tags.isEmpty)
                        Button("Tische (\(tables.count))") { resetTarget = .tables }
                            .warmButton(.secondary, size: .sm)
                            .disabled(tables.isEmpty)
                        Spacer()
                    }

                    HStack(spacing: 6) {
                        Button("Gäste & Tags") { resetTarget = .guestsAndTags }
                            .warmButton(.ghost, size: .sm)
                            .disabled(guests.isEmpty && tags.isEmpty)
                        Button("Alles zurücksetzen") { resetTarget = .everything }
                            .warmButton(.ghost, size: .sm)
                            .foregroundStyle(Tokens.Colors.error)
                            .disabled(events.isEmpty && guests.isEmpty && tables.isEmpty)
                        Spacer()
                    }

                    Text("Die einzelnen Buttons löschen nur den jeweiligen Bereich. 'Alles zurücksetzen' bringt dich zum Welcome-Screen zurück — Event, Gäste, Tische, alles weg.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .alert(item: $resetTarget) { target in
            resetAlert(for: target)
        }
    }

    private func resetAlert(for target: ResetTarget) -> Alert {
        switch target {
        case .guests:
            return Alert(
                title: Text("\(guests.count) Gäste löschen?"),
                message: Text("Tags, Tische und das Event bleiben. Tags verlieren ihre Gast-Verknüpfungen."),
                primaryButton: .destructive(Text("Löschen")) { deleteGuests() },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        case .tags:
            return Alert(
                title: Text("\(tags.count) Tags löschen?"),
                message: Text("Gäste und Tische bleiben — sie verlieren nur ihre Tag-Zuordnungen."),
                primaryButton: .destructive(Text("Löschen")) { deleteTags() },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        case .tables:
            return Alert(
                title: Text("\(tables.count) Tische löschen?"),
                message: Text("Gäste werden vom Tisch gelöst, bleiben aber erhalten."),
                primaryButton: .destructive(Text("Löschen")) { deleteTables() },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        case .guestsAndTags:
            return Alert(
                title: Text("\(guests.count) Gäste & \(tags.count) Tags löschen?"),
                message: Text("Event und Tische bleiben — du kannst die Anmeldungen erneut importieren."),
                primaryButton: .destructive(Text("Löschen")) { deleteGuestsAndTags() },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        case .everything:
            return Alert(
                title: Text("Komplett zurücksetzen?"),
                message: Text("Event, alle Gäste, Tische, Tags und Constraints werden gelöscht. Du landest wieder auf dem Welcome-Screen."),
                primaryButton: .destructive(Text("Alles löschen")) { resetEverything() },
                secondaryButton: .cancel(Text("Abbrechen"))
            )
        }
    }

    private func deleteGuests() {
        for guest in guests { modelContext.delete(guest) }
        // Tag-Verknüpfungen aufräumen
        for tag in tags {
            tag.guestIDs.removeAll()
        }
    }

    private func deleteTags() {
        for tag in tags { modelContext.delete(tag) }
    }

    private func deleteTables() {
        // Gäste vom Tisch lösen, dann Tische löschen
        for guest in guests where guest.table != nil {
            guest.table = nil
        }
        for table in tables { modelContext.delete(table) }
    }

    private func deleteGuestsAndTags() {
        deleteGuests()
        deleteTags()
        for constraint in constraints { modelContext.delete(constraint) }
    }

    private func resetEverything() {
        for guest in guests { modelContext.delete(guest) }
        for tag in tags { modelContext.delete(tag) }
        for constraint in constraints { modelContext.delete(constraint) }
        for table in tables { modelContext.delete(table) }
        for plan in roomPlans { modelContext.delete(plan) }
        for event in events { modelContext.delete(event) }
    }

    // MARK: - Daten: Finder & Backup

    /// Findet den tatsächlichen Pfad der SwiftData-Store-Datei. Primär liegt
    /// die Datei seit dem Custom-Container-Setup unter
    /// `~/Library/Application Support/Gaesteglueck/Gaesteglueck.store`,
    /// fällt aber auf alte Standorte zurück damit Bestandsdaten gefunden
    /// werden falls noch nicht migriert wurde.
    private func storeURL() -> URL? {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let candidates: [URL] = [
            appSupport?.appendingPathComponent("Gaesteglueck/Gaesteglueck.store"),
            appSupport?.appendingPathComponent("default.store"),
            appSupport?.appendingPathComponent("Default.store"),
            URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Containers/Gaesteglueck/Data/Library/Application Support/default.store")
        ].compactMap { $0 }
        return candidates.first { fm.fileExists(atPath: $0.path) }
    }

    private func revealStoreInFinder() {
        #if canImport(AppKit)
        if let url = storeURL() {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            setDataMessage("Im Finder geöffnet: \(url.lastPathComponent)", isError: false)
        } else if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(appSupport)
            setDataMessage("Speicherort nicht gefunden — Application Support geöffnet.", isError: true)
        } else {
            setDataMessage("Kein Speicherort gefunden.", isError: true)
        }
        #endif
    }

    private func createBackupNow() {
        let fm = FileManager.default
        guard let store = storeURL() else {
            setDataMessage("Kein Speicherort gefunden — Backup nicht möglich.", isError: true)
            return
        }
        let backupDir = store.deletingLastPathComponent().appendingPathComponent("Backups")
        do {
            try fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let stamp = backupTimestamp()
            // SQLite-WAL-Triplets mitkopieren: .store, .store-shm, .store-wal
            let storePath = store.path
            let sources: [URL] = [store, URL(fileURLWithPath: storePath + "-shm"), URL(fileURLWithPath: storePath + "-wal")]
            var copied: [URL] = []
            for src in sources where fm.fileExists(atPath: src.path) {
                let dst = backupDir.appendingPathComponent("\(stamp)-\(src.lastPathComponent)")
                try fm.copyItem(at: src, to: dst)
                copied.append(dst)
            }
            // Retention: nur die 3 neuesten Backup-Sets behalten, Rest löschen.
            let pruned = pruneOldBackups(in: backupDir, keep: 3)
            #if canImport(AppKit)
            if let firstCopy = copied.first {
                NSWorkspace.shared.activateFileViewerSelecting([firstCopy])
            }
            #endif
            let prunedSuffix = pruned > 0 ? " · \(pruned) alte\(pruned == 1 ? "s" : "") Backup\(pruned == 1 ? "" : "s") gelöscht" : ""
            setDataMessage("Backup erstellt: \(stamp) (\(copied.count) Datei\(copied.count == 1 ? "" : "en"))\(prunedSuffix)", isError: false)
        } catch {
            setDataMessage("Backup-Fehler: \(error.localizedDescription)", isError: true)
        }
    }

    /// Behält die `keep` neuesten Backup-Sets und löscht den Rest.
    /// Ein "Backup-Set" sind alle Dateien mit gleichem Timestamp-Prefix
    /// (z.B. `2026-05-08_22-39-58-Gaesteglueck.store` + `-shm` + `-wal`).
    /// Liefert die Anzahl der gelöschten Sets zurück.
    @discardableResult
    private func pruneOldBackups(in dir: URL, keep: Int) -> Int {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return 0
        }
        // Timestamp-Prefix extrahieren: "2026-05-08_22-39-58" (19 Zeichen).
        // Dateien deren Name nicht mit einem solchen Prefix anfängt ignorieren wir.
        var setsByPrefix: [String: [URL]] = [:]
        for url in entries {
            let name = url.lastPathComponent
            guard name.count >= 19 else { continue }
            let prefix = String(name.prefix(19))
            // Sanity-Check: Pattern yyyy-MM-dd_HH-mm-ss — beginnt mit "20"
            guard prefix.hasPrefix("20") else { continue }
            setsByPrefix[prefix, default: []].append(url)
        }
        // Nach Timestamp absteigend sortieren — die neuesten zuerst
        let sortedPrefixes = setsByPrefix.keys.sorted(by: >)
        guard sortedPrefixes.count > keep else { return 0 }
        let toDelete = sortedPrefixes.dropFirst(keep)
        var deletedSets = 0
        for prefix in toDelete {
            for url in setsByPrefix[prefix] ?? [] {
                try? fm.removeItem(at: url)
            }
            deletedSets += 1
        }
        return deletedSets
    }

    private func availableBackupSets() -> [BackupSet] {
        guard let store = storeURL() else { return [] }
        let backupDir = store.deletingLastPathComponent().appendingPathComponent("Backups")
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: nil) else {
            return []
        }
        var prefixes = Set<String>()
        for url in entries {
            let n = url.lastPathComponent
            for suffix in [".store", ".store-shm", ".store-wal"] where n.hasSuffix(suffix) {
                prefixes.insert(String(n.dropLast(suffix.count)))
                break
            }
        }
        return prefixes.sorted(by: >).map { p in
            let stamp = String(p.prefix(19))
                .replacingOccurrences(of: "_", with: " ")
            let tail = p.count > 19 ? String(p.dropFirst(19)).replacingOccurrences(of: "-", with: " ").trimmingCharacters(in: .whitespaces) : ""
            let label = tail.isEmpty ? stamp : "\(stamp) (\(tail))"
            return BackupSet(prefix: p, label: label)
        }
    }

    private func armRestore(_ set: BackupSet) {
        UserDefaults.standard.set(set.prefix, forKey: GaesteglueckApp.pendingRestoreKey)
        restoreCandidate = nil
        restoreArmed = true
    }

    private func backupTimestamp() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: Date())
    }

    private func setDataMessage(_ text: String, isError: Bool) {
        dataActionMessage = text
        dataActionMessageIsError = isError
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            if dataActionMessage == text {
                dataActionMessage = nil
            }
        }
    }
}
#endif
