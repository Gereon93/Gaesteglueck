#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// S9 — Einstellungen (siehe design_handoff_gaesteglueck → S9). Vier
/// Karten in zentrierter 720pt-Spalte: Lokale KI, Akzentfarbe (5 Swatches),
/// Event-Daten, Daten.
struct SettingsView: View {
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @AppStorage("llmProvider") private var llmProviderRaw: String = LLMProvider.lmStudio.rawValue
    @State private var openRouterAPIKey: String = KeychainStore.get(LLMClientFactory.openRouterAPIKeyAccount)
    @AppStorage("openRouterModel") private var openRouterModel: String = ""
    @AppStorage("openRouterModelPricePerM") private var openRouterModelPricePerM: Double = 0
    @AppStorage("accentColorHex") private var accentColorHex = "#c8788c"
    @AppStorage("autoBackup") private var autoBackup = true
    @AppStorage(LLMDebugLog.enabledKey) private var llmDebugLogEnabled = false
    @AppStorage("cacheResponses") private var cacheResponses = true
    @AppStorage("algorithmFallback") private var algorithmFallback = true
    @AppStorage("bridalIncludeTrauzeugen") private var bridalIncludeTrauzeugen: Bool = true
    @AppStorage("bridalIncludeEltern") private var bridalIncludeEltern: Bool = false
    @AppStorage("bridalIncludeGeschwister") private var bridalIncludeGeschwister: Bool = false
    @AppStorage("bridalManualMode") private var bridalManualMode: Bool = false

    // Spalten-Sichtbarkeit der Gästeliste
    @AppStorage("guestlist.col.funfact.visible") private var funfactVisible: Bool = true
    @AppStorage("guestlist.col.tags.visible") private var tagsVisible: Bool = true
    @AppStorage("guestlist.col.seite.visible") private var seiteVisible: Bool = true
    @AppStorage("guestlist.col.tisch.visible") private var tischVisible: Bool = true
    @AppStorage("guestlist.col.menu.visible") private var menuVisible: Bool = true

    @Environment(\.modelContext) private var modelContext
    @Query private var events: [Event]
    @Query private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var tables: [GuestTable]
    @Query private var roomPlans: [RoomPlan]
    @State private var connectionState: ConnectionState = .unknown
    @State private var connectedModel: String = ""
    @State private var isTestingConnection = false
    @State private var showingEventSetup = false
    @State private var featureProviderRaw: [String: String] = [:]
    @State private var featureModelRaw: [String: String] = [:]
    @State private var openRouterModels: [OpenRouterModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var openRouterError: String? = nil
    @State private var resetTarget: ResetTarget? = nil
    @State private var restoreCandidate: BackupSet? = nil
    @State private var restoreArmed: Bool = false

    struct BackupSet: Identifiable, Equatable {
        let prefix: String
        let label: String
        var id: String { prefix }
    }
    @State private var dataActionMessage: String? = nil
    @State private var dataActionMessageIsError: Bool = false

    enum ResetTarget: String, Identifiable {
        case guests, tags, tables, guestsAndTags, everything
        var id: String { rawValue }
    }

    enum ConnectionState {
        case unknown, connected, offline, checking
    }

    private static let accentSwatches: [String] = [
        "#c8788c", // Rose (default)
        "#b88a5c", // Amber
        "#7a8b6c", // Sage
        "#6e8aab", // Slate Blue
        "#9b7bae", // Mauve
    ]

    private var event: Event? { events.first }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                VStack(spacing: 16) {
                    aiCard
                    featureRoutingCard
                    accentCard
                    eventCard
                    seatingCard
                    listColumnsCard
                    dataCard
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            }
        }
        .background(Tokens.Colors.bg)
        .sheet(isPresented: $showingEventSetup) {
            EventSetupView()
        }
        .task {
            await checkConnection()
        }
        .onAppear { loadFeatureRouting() }
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

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(
            title: "Einstellungen",
            subtitle: "Lokale Konfiguration · ändert nichts außerhalb dieses Macs."
        )
    }

    // MARK: - KI Card

    private var llmProvider: LLMProvider {
        LLMProvider(rawValue: llmProviderRaw) ?? .lmStudio
    }

    private var aiCard: some View {
        SettingsCard(
            title: "KI-Anbieter",
            subtitle: aiCardSubtitle
        ) {
            VStack(spacing: 10) {
                SettingsRow(label: "Standard-Provider") {
                    Picker("", selection: $llmProviderRaw) {
                        ForEach(LLMProvider.allCases) { p in
                            Text(p.displayName).tag(p.rawValue)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 240, alignment: .leading)
                }
                Text("Gilt für alle KI-Funktionen die unten auf „Auto“ stehen. Beide Anbieter können parallel konfiguriert sein.")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().padding(.vertical, 2)
                Text("LM Studio (lokal)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                lmStudioRows

                Divider().padding(.vertical, 2)
                Text("OpenRouter (Cloud)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                openRouterRows

                Divider().padding(.vertical, 2)
                SettingsRow(label: "Antworten zwischenspeichern") {
                    GGToggle(isOn: $cacheResponses)
                }
                SettingsRow(label: "Algorithmus als Fallback") {
                    GGToggle(isOn: $algorithmFallback)
                }
            }
        }
    }

    private var aiCardSubtitle: String {
        switch llmProvider {
        case .lmStudio:
            return "Deine Gästeliste verlässt nie den Mac. Wir sprechen nur mit LM Studio auf dieser Maschine."
        case .openRouter:
            return "OpenRouter ruft Modelle über die Cloud auf. Daten verlassen den Mac — nur nutzen, wenn das ok ist."
        }
    }

    // MARK: - Pro-Feature-Routing

    private let autoTag = LLMClientFactory.autoProvider

    private func providerBinding(_ feature: AIFeature) -> Binding<String> {
        Binding(
            get: { featureProviderRaw[feature.rawValue] ?? autoTag },
            set: { newValue in
                featureProviderRaw[feature.rawValue] = newValue
                UserDefaults.standard.set(newValue, forKey: feature.providerKey)
            }
        )
    }

    private func modelBinding(_ feature: AIFeature) -> Binding<String> {
        Binding(
            get: { featureModelRaw[feature.rawValue] ?? "" },
            set: { newValue in
                featureModelRaw[feature.rawValue] = newValue
                UserDefaults.standard.set(newValue, forKey: feature.modelKey)
                let price = openRouterModels.first { $0.id == newValue }?.blendedUSDPerMillion ?? 0
                UserDefaults.standard.set(price, forKey: feature.modelPriceKey)
            }
        )
    }

    private func loadFeatureRouting() {
        for f in AIFeature.allCases {
            featureProviderRaw[f.rawValue] =
                UserDefaults.standard.string(forKey: f.providerKey) ?? autoTag
            featureModelRaw[f.rawValue] =
                UserDefaults.standard.string(forKey: f.modelKey) ?? ""
        }
    }

    private var featureRoutingCard: some View {
        SettingsCard(
            title: "KI pro Funktion",
            subtitle: "Jede KI-Funktion kann einen eigenen Anbieter + Modell nutzen. „Auto“ = Standard-Provider von oben."
        ) {
            VStack(spacing: 14) {
                ForEach(AIFeature.allCases) { feature in
                    VStack(spacing: 6) {
                        SettingsRow(label: feature.displayName) {
                            Picker("", selection: providerBinding(feature)) {
                                Text("Auto").tag(autoTag)
                                Text("LM Studio").tag(LLMProvider.lmStudio.rawValue)
                                Text("OpenRouter").tag(LLMProvider.openRouter.rawValue)
                            }
                            .labelsHidden()
                            .frame(maxWidth: 200, alignment: .leading)
                        }
                        if providerBinding(feature).wrappedValue == LLMProvider.openRouter.rawValue {
                            SettingsRow(label: "↳ Modell") {
                                if openRouterModels.isEmpty {
                                    Text(modelBinding(feature).wrappedValue.isEmpty
                                         ? "Standard-Modell (oben)" : modelBinding(feature).wrappedValue)
                                        .font(Tokens.Typography.mono)
                                        .foregroundStyle(Tokens.Colors.ink3)
                                } else {
                                    Picker("", selection: modelBinding(feature)) {
                                        Text("Standard-Modell (oben)").tag("")
                                        ForEach(openRouterModels) { m in
                                            Text("\(m.name) · \(m.priceLabel)").tag(m.id)
                                        }
                                    }
                                    .labelsHidden()
                                    .frame(maxWidth: 360, alignment: .leading)
                                }
                            }
                        }
                        Text(feature.hint)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var lmStudioRows: some View {
        SettingsRow(label: "Status") {
            HStack(spacing: 6) {
                Circle()
                    .fill(connectionDotColor)
                    .frame(width: 8, height: 8)
                Text(connectionLabel)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(connectionDotColor)
            }
        }
        SettingsRow(label: "Endpoint") {
            HStack(spacing: 8) {
                TextField("http://localhost:1234", text: $lmStudioEndpoint)
                    .textFieldStyle(.plain)
                    .font(Tokens.Typography.mono)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Tokens.Colors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .frame(maxWidth: 240)
                Button {
                    Task { await checkConnection() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .warmButton(.ghost, size: .sm)
            }
        }
        if !connectedModel.isEmpty {
            SettingsRow(label: "Modell") {
                Text(connectedModel)
                    .font(Tokens.Typography.mono)
                    .foregroundStyle(Tokens.Colors.ink)
            }
        }
    }

    @ViewBuilder
    private var openRouterRows: some View {
        SettingsRow(label: "API-Key") {
            SecureField("sk-or-…", text: $openRouterAPIKey)
                .textFieldStyle(.plain)
                .font(Tokens.Typography.mono)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Tokens.Colors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .onChange(of: openRouterAPIKey) { _, newValue in
                    KeychainStore.set(newValue, for: LLMClientFactory.openRouterAPIKeyAccount)
                }
                .frame(maxWidth: 320)
        }
        SettingsRow(label: "Modell") {
            HStack(spacing: 8) {
                if openRouterModels.isEmpty {
                    Text(openRouterModel.isEmpty ? "Noch keine Modelle geladen" : openRouterModel)
                        .font(Tokens.Typography.mono)
                        .foregroundStyle(openRouterModel.isEmpty ? Tokens.Colors.ink3 : Tokens.Colors.ink)
                } else {
                    Picker("", selection: $openRouterModel) {
                        Text("— wählen —").tag("")
                        ForEach(openRouterModels) { m in
                            Text("\(m.name) · \(m.priceLabel)").tag(m.id)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 360, alignment: .leading)
                    .onChange(of: openRouterModel) { _, newID in
                        openRouterModelPricePerM =
                            openRouterModels.first { $0.id == newID }?.blendedUSDPerMillion ?? 0
                    }
                }
                Button {
                    Task { await loadOpenRouterModels() }
                } label: {
                    if isLoadingModels {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Modelle laden")
                    }
                }
                .warmButton(.secondary, size: .sm)
                .disabled(openRouterAPIKey.isEmpty || isLoadingModels)
            }
        }
        if let openRouterError {
            SettingsRow(label: "") {
                Text(openRouterError)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.warn)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @MainActor
    private func loadOpenRouterModels() async {
        openRouterError = nil
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            let models = try await OpenRouterModelsAPI.listModels(apiKey: openRouterAPIKey)
            openRouterModels = models
            // Aktuelle Auswahl beibehalten falls noch in der Liste, sonst leeren
            if !openRouterModel.isEmpty, !models.contains(where: { $0.id == openRouterModel }) {
                openRouterModel = ""
            }
        } catch {
            openRouterError = error.localizedDescription
        }
    }

    private var connectionDotColor: Color {
        switch connectionState {
        case .unknown, .checking: Tokens.Colors.ink4
        case .connected: Tokens.Colors.sage
        case .offline: Tokens.Colors.warn
        }
    }

    private var connectionLabel: String {
        switch connectionState {
        case .unknown: "Status unbekannt"
        case .checking: "Prüfe…"
        case .connected: "Verbunden"
        case .offline: "Nicht erreichbar"
        }
    }

    // MARK: - Accent Card

    private var accentCard: some View {
        SettingsCard(
            title: "Akzentfarbe",
            subtitle: "Erscheint auf Buttons, Sidebar-Selektionen und im Export."
        ) {
            HStack(spacing: 10) {
                ForEach(Self.accentSwatches, id: \.self) { hex in
                    Button {
                        accentColorHex = hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                            if accentColorHex == hex {
                                Circle()
                                    .strokeBorder(Tokens.Colors.surface, lineWidth: 3)
                                    .frame(width: 32, height: 32)
                                Circle()
                                    .strokeBorder(Color(hex: hex), lineWidth: 1.5)
                                    .frame(width: 38, height: 38)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Eigene Farbe…") {}
                    .warmButton(.secondary, size: .sm)
            }
        }
    }

    // MARK: - Event Card

    private var eventCard: some View {
        SettingsCard(
            title: "Event-Daten",
            subtitle: "Erscheinen auf jeder PDF-Seite und auf dem Dashboard."
        ) {
            if let event {
                VStack(spacing: 10) {
                    SettingsRow(label: "Partnernamen") {
                        Text("\(event.partnerDisplayName1) & \(event.partnerDisplayName2)")
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink)
                    }
                    SettingsRow(label: "Hochzeitsdatum") {
                        if let date = event.date {
                            Text(formatDate(date))
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink)
                        } else {
                            Text("Noch offen")
                                .font(.system(size: 12.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                    }
                    SettingsRow(label: "Location") {
                        Text(event.venue.isEmpty ? "Noch offen" : event.venue)
                            .font(.system(size: 12.5, design: .rounded))
                            .foregroundStyle(event.venue.isEmpty ? Tokens.Colors.ink3 : Tokens.Colors.ink)
                    }
                    SettingsRow(label: "Menüoptionen") {
                        HStack(spacing: 4) {
                            ForEach(event.menuOptions, id: \.self) { option in
                                TagChip(label: option, kind: chipKindFor(menu: option), size: .sm)
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        Button("Bearbeiten") { showingEventSetup = true }
                            .warmButton(.secondary, size: .sm)
                    }
                    .padding(.top, 4)
                }
            } else {
                HStack {
                    Text("Noch kein Event eingerichtet.")
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Spacer()
                    Button("Event einrichten") { showingEventSetup = true }
                        .warmButton(.primary, size: .sm)
                }
            }
        }
    }

    private func chipKindFor(menu: String) -> TagChip.Kind {
        switch menu.lowercased() {
        case "vegetarisch", "vegan": .friends
        case "fleisch": .role
        default: .custom
        }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        fmt.locale = Locale(identifier: "de_DE")
        return fmt.string(from: date)
    }

    // MARK: - Seating Card

    private var seatingCard: some View {
        SettingsCard(
            title: "Sitzplan-Regeln",
            subtitle: "Wer sitzt am Brautpaartisch? Wird vom Auto-Sitzplaner als harte Regel respektiert."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Trauzeugen / Brautjungfern", isOn: Binding(
                    get: { bridalIncludeTrauzeugen },
                    set: { bridalIncludeTrauzeugen = $0 }
                ))
                .disabled(bridalManualMode)

                Toggle("Eltern beider Seiten", isOn: Binding(
                    get: { bridalIncludeEltern },
                    set: { bridalIncludeEltern = $0 }
                ))
                .disabled(bridalManualMode)

                Toggle("Geschwister beider Seiten", isOn: Binding(
                    get: { bridalIncludeGeschwister },
                    set: { bridalIncludeGeschwister = $0 }
                ))
                .disabled(bridalManualMode)

                Divider()

                Toggle("Manuell — keine Auto-Regel", isOn: Binding(
                    get: { bridalManualMode },
                    set: { bridalManualMode = $0 }
                ))

                Text(bridalPolicyExplanation)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bridalPolicyExplanation: String {
        if bridalManualMode {
            return "Keine Auto-Regel — du pinnst selbst wer am Brauttisch sitzt."
        }
        var groups: [String] = []
        if bridalIncludeTrauzeugen { groups.append("Trauzeugen / Brautjungfern") }
        if bridalIncludeEltern { groups.append("Eltern") }
        if bridalIncludeGeschwister { groups.append("Geschwister") }
        if groups.isEmpty {
            return "Nur das Brautpaar selbst sitzt am Brauttisch. Alle anderen verteilen sich frei."
        }
        let suffix = groups.count >= 2 ? " (Brauttafel sollte genug Plätze haben.)" : ""
        return "\(groups.joined(separator: ", ")) sitzen mit am Brauttisch.\(suffix)"
    }

    // MARK: - List Columns Card

    private var listColumnsCard: some View {
        SettingsCard(
            title: "Gästeliste-Spalten",
            subtitle: "Welche Spalten sollen in der Gäste-Tabelle angezeigt werden?"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("FunFact", isOn: Binding(
                    get: { funfactVisible },
                    set: { funfactVisible = $0 }
                ))
                Toggle("Tags", isOn: Binding(
                    get: { tagsVisible },
                    set: { tagsVisible = $0 }
                ))
                Toggle("Seite", isOn: Binding(
                    get: { seiteVisible },
                    set: { seiteVisible = $0 }
                ))
                Toggle("Tisch", isOn: Binding(
                    get: { tischVisible },
                    set: { tischVisible = $0 }
                ))
                Toggle("Menü", isOn: Binding(
                    get: { menuVisible },
                    set: { menuVisible = $0 }
                ))
            }
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

    // MARK: - Connection check

    @MainActor
    private func checkConnection() async {
        connectionState = .checking
        let client = LMStudioClient(endpoint: lmStudioEndpoint)
        do {
            let model = try await client.checkConnection()
            connectionState = .connected
            connectedModel = model
        } catch {
            connectionState = .offline
            connectedModel = ""
        }
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

// MARK: - Settings Card

private struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Tokens.Colors.line).frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
        .cardShadow()
    }
}

// MARK: - Settings Row

private struct SettingsRow<Trailing: View>: View {
    let label: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Text(label)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .frame(width: 200, alignment: .leading)
            trailing()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }
}

// MARK: - Toggle

private struct GGToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? Tokens.Colors.accent : Tokens.Colors.bg3)
                    .frame(width: 34, height: 20)
                Circle()
                    .fill(.white)
                    .frame(width: 16, height: 16)
                    .padding(.horizontal, 2)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            .animation(.easeOut(duration: 0.12), value: isOn)
        }
        .buttonStyle(.plain)
    }
}
#endif
