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
    static let openRouterModelPriceKey = "openRouterModelPricePerM"

    static func effectiveOpenRouterPricePerM(
        for feature: AIFeature,
        defaults: UserDefaults = .standard
    ) -> Double {
        guard provider(for: feature, defaults: defaults) == .openRouter else { return 0 }
        let perFeatureModel = defaults.string(forKey: feature.modelKey) ?? ""
        if !perFeatureModel.isEmpty {
            return defaults.double(forKey: feature.modelPriceKey)
        }
        return defaults.double(forKey: openRouterModelPriceKey)
    }

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

    // MARK: - Pro-Feature-Routing

    /// Sentinel für "diesem Feature keinen eigenen Provider geben — globalen
    /// `llmProvider` nutzen". Default für alle Features bis der User in den
    /// Einstellungen explizit umstellt.
    static let autoProvider = "auto"

    /// Effektiver Provider für ein Feature: Feature-Override → globaler
    /// Provider → OpenRouter-Fallback auf LM Studio wenn Key/Modell fehlt.
    static func provider(
        for feature: AIFeature,
        defaults: UserDefaults = .standard,
        apiKey: String? = nil
    ) -> LLMProvider {
        let raw = defaults.string(forKey: feature.providerKey) ?? autoProvider
        let resolved: LLMProvider
        if raw == autoProvider {
            let globalRaw = defaults.string(forKey: providerKey) ?? LLMProvider.lmStudio.rawValue
            resolved = LLMProvider(rawValue: globalRaw) ?? .lmStudio
        } else {
            resolved = LLMProvider(rawValue: raw) ?? .lmStudio
        }
        if resolved == .openRouter {
            let key = apiKey ?? KeychainStore.get(openRouterAPIKeyAccount)
            let model = featureModel(for: feature, defaults: defaults)
            if key.isEmpty || model.isEmpty { return .lmStudio }
        }
        return resolved
    }

    /// Modell für ein Feature: Feature-Override → globales OpenRouter-Modell.
    static func featureModel(
        for feature: AIFeature,
        defaults: UserDefaults = .standard
    ) -> String {
        let perFeature = defaults.string(forKey: feature.modelKey) ?? ""
        if !perFeature.isEmpty { return perFeature }
        return defaults.string(forKey: openRouterModelKey) ?? ""
    }

    /// Liefert den Client für ein bestimmtes KI-Feature.
    static func makeClient(
        for feature: AIFeature,
        defaults: UserDefaults = .standard,
        apiKey: String? = nil
    ) -> LLMClient {
        switch provider(for: feature, defaults: defaults, apiKey: apiKey) {
        case .openRouter:
            let key = apiKey ?? KeychainStore.get(openRouterAPIKeyAccount)
            let model = featureModel(for: feature, defaults: defaults)
            if !key.isEmpty, !model.isEmpty {
                return LoggingLLMClient(
                    wrapped: OpenRouterClient(apiKey: key, model: model),
                    feature: feature.rawValue, provider: "openRouter", model: model
                )
            }
            let endpoint = defaults.string(forKey: lmStudioEndpointKey) ?? "http://localhost:1234"
            return LoggingLLMClient(
                wrapped: makeLMStudio(defaults: defaults),
                feature: feature.rawValue, provider: "lmStudio (fallback)", model: endpoint
            )
        case .lmStudio:
            let endpoint = defaults.string(forKey: lmStudioEndpointKey) ?? "http://localhost:1234"
            return LoggingLLMClient(
                wrapped: makeLMStudio(defaults: defaults),
                feature: feature.rawValue, provider: "lmStudio", model: endpoint
            )
        }
    }
}
