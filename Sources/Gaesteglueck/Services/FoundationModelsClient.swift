import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Apples On-Device-Modell (Apple Intelligence) — läuft ohne Netzwerk und
/// API-Key direkt auf dem Gerät. Verfügbar ab macOS 26 / iOS 26 auf
/// Apple-Intelligence-fähiger Hardware; `isSupported` prüft beides zur
/// Laufzeit, ältere Systeme sehen den Provider gar nicht erst.
enum AppleOnDeviceModel {
    static var isSupported: Bool {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            if case .available = SystemLanguageModel.default.availability {
                return true
            }
        }
        #endif
        return false
    }
}

#if canImport(FoundationModels)
@available(macOS 26.0, iOS 26.0, *)
struct FoundationModelsClient: LLMClient {
    /// `jsonMode` hat beim System-Modell kein API-Pendant — die Prompts der
    /// App fordern das JSON-Format bereits im Text an.
    func chat(messages: [LLMMessage], temperature: Double, maxTokens: Int, jsonMode: Bool) async throws -> String {
        let instructions = messages
            .filter { $0.role == "system" }
            .map(\.content)
            .joined(separator: "\n\n")
        let prompt = messages
            .filter { $0.role != "system" }
            .map(\.content)
            .joined(separator: "\n\n")
        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens)
        let response = try await session.respond(to: prompt, options: options)
        return response.content
    }
}
#endif
