import Foundation

enum LLMProvider: String, Sendable, CaseIterable, Identifiable {
    case lmStudio
    case openRouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lmStudio: "LM Studio (lokal)"
        case .openRouter: "OpenRouter"
        }
    }
}

enum LLMClientFactory {
    static let providerKey = "llmProvider"
    static let lmStudioEndpointKey = "lmStudioEndpoint"
    static let openRouterAPIKeyAccount = "openRouterAPIKey"
    static let openRouterModelKey = "openRouterModel"

    /// Liest die Provider-Wahl aus UserDefaults und liefert den passenden
    /// Client. Fällt bei OpenRouter ohne API-Key/Modell auf LM Studio zurück
    /// — Aufrufer erfahren das nicht, das Verhalten ist transparent.
    /// Verschiebt einen ggf. in UserDefaults liegenden API-Key ins Keychain
    /// und löscht ihn aus den Defaults — Idempotent. Soll beim App-Start
    /// einmalig laufen.
    static func migrateAPIKeyToKeychainIfNeeded(defaults: UserDefaults = .standard) {
        let legacyKey = defaults.string(forKey: openRouterAPIKeyAccount) ?? ""
        guard !legacyKey.isEmpty else { return }
        if KeychainStore.get(openRouterAPIKeyAccount).isEmpty {
            KeychainStore.set(legacyKey, for: openRouterAPIKeyAccount)
        }
        defaults.removeObject(forKey: openRouterAPIKeyAccount)
    }

    /// Welcher Provider EFFEKTIV verwendet wird — berücksichtigt den
    /// OpenRouter→LM-Studio-Fallback bei fehlendem Key/Modell. `apiKey`
    /// nur in Tests injizieren; Production liest aus dem Keychain.
    static func providerFromSettings(
        defaults: UserDefaults = .standard,
        apiKey: String? = nil
    ) -> LLMProvider {
        let providerRaw = defaults.string(forKey: providerKey) ?? LLMProvider.lmStudio.rawValue
        let provider = LLMProvider(rawValue: providerRaw) ?? .lmStudio
        if provider == .openRouter {
            let key = apiKey ?? KeychainStore.get(openRouterAPIKeyAccount)
            let model = defaults.string(forKey: openRouterModelKey) ?? ""
            if key.isEmpty || model.isEmpty { return .lmStudio }
        }
        return provider
    }

    static func makeFromSettings(
        defaults: UserDefaults = .standard,
        apiKey: String? = nil
    ) -> LLMClient {
        let providerRaw = defaults.string(forKey: providerKey) ?? LLMProvider.lmStudio.rawValue
        let provider = LLMProvider(rawValue: providerRaw) ?? .lmStudio

        switch provider {
        case .openRouter:
            let key = apiKey ?? KeychainStore.get(openRouterAPIKeyAccount)
            let model = defaults.string(forKey: openRouterModelKey) ?? ""
            if !key.isEmpty, !model.isEmpty {
                return OpenRouterClient(apiKey: key, model: model)
            }
            return makeLMStudio(defaults: defaults)
        case .lmStudio:
            return makeLMStudio(defaults: defaults)
        }
    }

    private static func makeLMStudio(defaults: UserDefaults) -> LMStudioClient {
        let endpoint = defaults.string(forKey: lmStudioEndpointKey) ?? "http://localhost:1234"
        return LMStudioClient(endpoint: endpoint)
    }
}
