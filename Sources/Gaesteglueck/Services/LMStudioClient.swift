import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

actor LMStudioClient {
    let endpoint: String
    private var modelOverride: String?

    init(endpoint: String = "http://localhost:1234", model: String? = nil) {
        self.endpoint = endpoint
        self.modelOverride = model
    }

    struct Message: Codable, Sendable {
        let role: String
        let content: String
    }

    struct ChatRequest: Codable, Sendable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
    }

    struct ChatResponse: Codable, Sendable {
        struct Choice: Codable, Sendable {
            struct Message: Codable, Sendable {
                let content: String
            }
            let message: Message
        }
        let choices: [Choice]
        let model: String?
    }

    struct ModelList: Codable, Sendable {
        struct Model: Codable, Sendable {
            let id: String
        }
        let data: [Model]
    }

    enum LMStudioError: Error, LocalizedError {
        case connectionFailed
        case noModelsLoaded
        case emptyResponse
        case invalidURL
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed: "Keine Verbindung zu LM Studio. Ist es gestartet?"
            case .noModelsLoaded: "Kein Modell in LM Studio geladen."
            case .emptyResponse: "Leere Antwort vom Modell."
            case .invalidURL: "Ungültige LM Studio URL."
            case .invalidJSON(let detail): "Ungültige JSON-Antwort: \(detail)"
            }
        }
    }

    func checkConnection() async throws -> String {
        guard let url = URL(string: "\(endpoint)/v1/models") else { throw LMStudioError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let models = try JSONDecoder().decode(ModelList.self, from: data)
        guard let first = models.data.first else { throw LMStudioError.noModelsLoaded }
        return first.id
    }

    func chat(messages: [Message], temperature: Double = 0.3, maxTokens: Int = 4096) async throws -> String {
        let model: String
        if let override = modelOverride {
            model = override
        } else {
            model = try await checkConnection()
        }
        guard let url = URL(string: "\(endpoint)/v1/chat/completions") else { throw LMStudioError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ChatRequest(model: model, messages: messages, temperature: temperature, max_tokens: maxTokens)
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = response.choices.first?.message.content, !content.isEmpty else { throw LMStudioError.emptyResponse }
        return content
    }

    func prompt(system: String, user: String, temperature: Double = 0.3) async throws -> String {
        try await chat(messages: [Message(role: "system", content: system), Message(role: "user", content: user)], temperature: temperature)
    }
}
