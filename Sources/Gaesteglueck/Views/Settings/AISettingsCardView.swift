#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// KI-Anbieter + Pro-Feature-Routing. Beide Karten teilen sich den State
/// `openRouterModels`/`openRouterAPIKey` und liegen daher in einer View.
struct AISettingsCardView: View {
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @AppStorage("llmProvider") private var llmProviderRaw: String = LLMProvider.lmStudio.rawValue
    @State private var openRouterAPIKey: String = KeychainStore.get(LLMClientFactory.openRouterAPIKeyAccount)
    @AppStorage("openRouterModel") private var openRouterModel: String = ""
    @AppStorage("openRouterModelPricePerM") private var openRouterModelPricePerM: Double = 0
    @AppStorage(LLMDebugLog.enabledKey) private var llmDebugLogEnabled = false
    @AppStorage("cacheResponses") private var cacheResponses = true
    @AppStorage("algorithmFallback") private var algorithmFallback = true

    @State private var connectionState: ConnectionState = .unknown
    @State private var connectedModel: String = ""
    @State private var isTestingConnection = false
    @State private var featureProviderRaw: [String: String] = [:]
    @State private var featureModelRaw: [String: String] = [:]
    @State private var openRouterModels: [OpenRouterModel] = []
    @State private var isLoadingModels: Bool = false
    @State private var openRouterError: String? = nil

    enum ConnectionState {
        case unknown, connected, offline, checking
    }

    var body: some View {
        VStack(spacing: 16) {
            aiCard
            featureRoutingCard
        }
        .task {
            await checkConnection()
        }
        .onAppear { loadFeatureRouting() }
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
                        ForEach(LLMProvider.selectableCases) { p in
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
            .onAppear { resetStaleAppleOnDeviceSelectionIfNeeded() }
        }
    }

    private var aiCardSubtitle: String {
        switch llmProvider {
        case .lmStudio:
            return "Deine Gästeliste verlässt nie den Mac. Wir sprechen nur mit LM Studio auf dieser Maschine."
        case .openRouter:
            return "OpenRouter ruft Modelle über die Cloud auf. Daten verlassen den Mac — nur nutzen, wenn das ok ist."
        case .appleOnDevice:
            return "Apples System-Modell läuft komplett auf diesem Gerät — keine Cloud, kein API-Key."
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
            featureProviderRaw[f.rawValue] = normalizedFeatureProvider(for: f)
            featureModelRaw[f.rawValue] =
                UserDefaults.standard.string(forKey: f.modelKey) ?? ""
        }
    }

    /// Eine gespeicherte Provider-Wahl, die der Picker auf diesem Gerät gar
    /// nicht anbietet (Apple Intelligence ohne System-Support), wäre eine
    /// Selektion ohne Tag — solche Werte werden auf Auto zurückgesetzt.
    private func normalizedFeatureProvider(for feature: AIFeature) -> String {
        let provider = UserDefaults.standard.string(forKey: feature.providerKey) ?? autoTag
        guard provider == LLMProvider.appleOnDevice.rawValue,
              !AppleOnDeviceModel.isSupported else { return provider }
        UserDefaults.standard.set(autoTag, forKey: feature.providerKey)
        return autoTag
    }

    /// Gleicher Fall für den Standard-Provider: ohne Geräte-Support zurück
    /// auf LM Studio — die Factory fällt dahin ohnehin schon zurück.
    private func resetStaleAppleOnDeviceSelectionIfNeeded() {
        if llmProvider == .appleOnDevice, !AppleOnDeviceModel.isSupported {
            llmProviderRaw = LLMProvider.lmStudio.rawValue
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
                                if AppleOnDeviceModel.isSupported {
                                    Text("Apple Intelligence").tag(LLMProvider.appleOnDevice.rawValue)
                                }
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
}
#endif
