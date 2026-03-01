import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor OpenRouterClient {
    private let baseURL = URL(string: "https://openrouter.ai/api/v1/chat/completions")!
    private var apiKey: String?

    init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    struct Request: Codable, Sendable {
        let model: String
        let messages: [Message]
    }

    struct Response: Codable, Sendable {
        struct Choice: Codable, Sendable {
            struct Message: Codable, Sendable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
    }

    func suggest(prompt: String) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw AIError.noAPIKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = Request(
            model: "meta-llama/llama-3.1-8b-instruct:free",
            messages: [
                Message(role: "system", content: """
                    Du bist ein Hochzeitsplaner-Assistent. Du hilfst bei der Sitzordnung.
                    Antworte auf Deutsch, kurz und praktisch.
                    """),
                Message(role: "user", content: prompt)
            ]
        )

        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(Response.self, from: data)

        return response.choices.first?.message.content ?? "Keine Antwort erhalten."
    }
}

enum AIError: Error, LocalizedError {
    case noAPIKey
    case noSuggestion

    var errorDescription: String? {
        switch self {
        case .noAPIKey: "Kein OpenRouter API-Key konfiguriert. Gehe zu Einstellungen."
        case .noSuggestion: "Keine Vorschläge verfügbar."
        }
    }
}
