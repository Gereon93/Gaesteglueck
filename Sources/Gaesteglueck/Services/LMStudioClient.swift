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
        /// Optional. Wenn gesetzt erzwingt LM Studio JSON-Output via
        /// constrained sampling — robust gegen Modelle die sonst leeres
        /// content oder Markdown-Wrapper zurückgeben.
        let response_format: ResponseFormat?
    }

    struct ResponseFormat: Codable, Sendable {
        let type: String
        static let jsonObject = ResponseFormat(type: "json_object")
    }

    struct ChatResponse: Codable, Sendable {
        struct Choice: Codable, Sendable {
            struct Message: Codable, Sendable {
                let content: String?
                /// Manche Modelle (Reasoning-Varianten, einige Gemma-Builds)
                /// schreiben die eigentliche Antwort hierher statt in content.
                let reasoning_content: String?
            }
            let message: Message?
            let finish_reason: String?
        }
        struct ErrorPayload: Codable, Sendable {
            let message: String?
        }
        let choices: [Choice]?
        let model: String?
        /// LM Studio liefert bei Schiefläufen (z.B. response_format inkompatibel
        /// mit Reasoning-Modellen) keine `choices`, sondern ein `error`-Objekt.
        let error: ErrorPayload?
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
        case emptyResponse(finishReason: String?, rawSnippet: String?)
        case invalidURL
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed: return "Keine Verbindung zu LM Studio. Ist es gestartet?"
            case .noModelsLoaded: return "Kein Modell in LM Studio geladen."
            case .emptyResponse(let reason, _):
                if reason == "length" {
                    return "Modell hat alle Tokens für internes Nachdenken (Reasoning) verbraucht. Bitte in LM Studio Thinking-Mode deaktivieren oder ein non-reasoning Modell wählen (z.B. google/gemma-3-12b)."
                }
                return "Leere Antwort vom Modell\(reason.map { " (finish_reason: \($0))" } ?? "")."
            case .invalidURL: return "Ungültige LM Studio URL."
            case .invalidJSON(let detail): return "Ungültige JSON-Antwort: \(detail)"
            }
        }
    }

    /// macOS-Quelle vom Connection-refused-Stress: `localhost` resolved auf IPv4
    /// UND IPv6 — LM Studio bindet aber nur an 127.0.0.1, IPv6-Versuch failed.
    /// Wir normalisieren `localhost` direkt auf `127.0.0.1` damit URLSession
    /// gar nicht erst den IPv6-Pfad probiert.
    private var normalizedEndpoint: String {
        endpoint
            .replacingOccurrences(of: "://localhost:", with: "://127.0.0.1:")
            .replacingOccurrences(of: "://localhost/", with: "://127.0.0.1/")
    }

    /// Lange Sessions mit großen Modellen (27B+) brauchen mehr als die 60s
    /// Default. 5 Minuten pro Request, damit ein Batch-Call mit hoher
    /// Token-Generation durchgeht.
    private static let longTimeout: TimeInterval = 300

    private static let longTimeoutSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = longTimeout
        config.timeoutIntervalForResource = longTimeout
        return URLSession(configuration: config)
    }()

    func checkConnection() async throws -> String {
        guard let url = URL(string: "\(normalizedEndpoint)/v1/models") else { throw LMStudioError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, _) = try await URLSession.shared.data(for: request)
        let models = try JSONDecoder().decode(ModelList.self, from: data)
        guard let first = models.data.first else { throw LMStudioError.noModelsLoaded }
        return first.id
    }

    func chat(messages: [Message], temperature: Double = 0.3, maxTokens: Int = 4096, jsonMode: Bool = false) async throws -> String {
        let model: String
        if let override = modelOverride {
            model = override
        } else {
            model = try await checkConnection()
        }
        guard let url = URL(string: "\(normalizedEndpoint)/v1/chat/completions") else { throw LMStudioError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = Self.longTimeout
        let body = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens,
            response_format: jsonMode ? .jsonObject : nil
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, _) = try await Self.longTimeoutSession.data(for: request)
        let response: ChatResponse
        do {
            response = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            // Decoder-Fehler heißt: Body kam an, passt aber nicht zum erwarteten
            // Schema (z.B. nicht-JSON Error-Body, oder Felder fehlen). NICHT
            // emptyResponse — das wäre irreführend. Rohen Snippet mitgeben
            // damit der User sieht was LM Studio tatsächlich geschickt hat.
            let snippet = String(data: data, encoding: .utf8)?.prefix(400).description ?? "<binary>"
            throw LMStudioError.invalidJSON("Unerwartetes Antwort-Format. Roh: \(snippet)")
        }
        if let errMsg = response.error?.message, !errMsg.isEmpty {
            throw LMStudioError.invalidJSON(errMsg)
        }
        let choice = response.choices?.first
        let content = (choice?.message?.content?.isEmpty == false ? choice?.message?.content : nil)
            ?? choice?.message?.reasoning_content
        if let content, !content.isEmpty { return content }
        let snippet = String(data: data, encoding: .utf8)?.prefix(400).description
        throw LMStudioError.emptyResponse(
            finishReason: choice?.finish_reason,
            rawSnippet: snippet
        )
    }

    func prompt(system: String, user: String, temperature: Double = 0.3, jsonMode: Bool = false) async throws -> String {
        try await chat(
            messages: [Message(role: "system", content: system), Message(role: "user", content: user)],
            temperature: temperature,
            jsonMode: jsonMode
        )
    }
}
