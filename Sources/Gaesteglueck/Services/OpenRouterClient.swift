import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPSession {}

actor OpenRouterClient: LLMClient {
    let apiKey: String
    let model: String
    private let session: HTTPSession
    private let baseURL: String

    init(
        apiKey: String,
        model: String,
        baseURL: String = "https://openrouter.ai/api/v1",
        session: HTTPSession = OpenRouterClient.defaultSession
    ) {
        self.apiKey = apiKey
        self.model = model
        self.baseURL = baseURL
        self.session = session
    }

    private static let longTimeout: TimeInterval = 300

    static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = longTimeout
        config.timeoutIntervalForResource = longTimeout
        return URLSession(configuration: config)
    }()

    struct ChatRequest: Codable, Sendable {
        let model: String
        let messages: [LLMMessage]
        let temperature: Double
        let max_tokens: Int
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
                let reasoning_content: String?
            }
            let message: Message?
            let finish_reason: String?
        }
        struct ErrorPayload: Codable, Sendable {
            let message: String?
            let code: Int?
        }
        let choices: [Choice]?
        let model: String?
        let error: ErrorPayload?
    }

    enum OpenRouterError: Error, LocalizedError {
        case missingAPIKey
        case invalidURL
        case unauthorized
        case rateLimited
        case http(Int, String?)
        case emptyResponse(finishReason: String?)
        case invalidJSON(String)
        case apiError(message: String, code: Int?)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey: return "Kein OpenRouter API-Key hinterlegt."
            case .invalidURL: return "Ungültige OpenRouter-URL."
            case .unauthorized: return "OpenRouter API-Key ist ungültig oder abgelaufen."
            case .rateLimited: return "OpenRouter Rate-Limit erreicht. Bitte später erneut versuchen."
            case .http(let code, let body):
                return "OpenRouter HTTP \(code)\(body.map { ": \($0)" } ?? "")."
            case .emptyResponse(let reason):
                return "Leere Antwort von OpenRouter\(reason.map { " (finish_reason: \($0))" } ?? "")."
            case .invalidJSON(let detail): return "Ungültige JSON-Antwort: \(detail)"
            case .apiError(let message, let code):
                return "OpenRouter API-Fehler\(code.map { " (Code \($0))" } ?? ""): \(message)"
            }
        }
    }

    func chat(messages: [LLMMessage], temperature: Double = 0.3, maxTokens: Int = 4096, jsonMode: Bool = false) async throws -> String {
        guard !apiKey.isEmpty else { throw OpenRouterError.missingAPIKey }
        guard let url = URL(string: "\(baseURL)/chat/completions") else { throw OpenRouterError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("https://gaesteglueck.app", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Gaesteglueck", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = Self.longTimeout
        let body = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: maxTokens,
            response_format: jsonMode ? .jsonObject : nil
        )
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 401: throw OpenRouterError.unauthorized
            case 429: throw OpenRouterError.rateLimited
            default:
                let snippet = String(data: data, encoding: .utf8)?.prefix(400).description
                throw OpenRouterError.http(http.statusCode, snippet)
            }
        }
        let decoded: ChatResponse
        do {
            decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            let snippet = String(data: data, encoding: .utf8)?.prefix(400).description ?? "<binary>"
            throw OpenRouterError.invalidJSON("Unerwartetes Antwort-Format. Roh: \(snippet)")
        }
        if let errMsg = decoded.error?.message, !errMsg.isEmpty {
            throw OpenRouterError.apiError(message: errMsg, code: decoded.error?.code)
        }
        let choice = decoded.choices?.first
        let content = (choice?.message?.content?.isEmpty == false ? choice?.message?.content : nil)
            ?? choice?.message?.reasoning_content
        if let content, !content.isEmpty { return content }
        throw OpenRouterError.emptyResponse(finishReason: choice?.finish_reason)
    }

    func prompt(system: String, user: String, temperature: Double = 0.3, jsonMode: Bool = false) async throws -> String {
        try await chat(
            messages: [LLMMessage(role: "system", content: system), LLMMessage(role: "user", content: user)],
            temperature: temperature,
            maxTokens: 4096,
            jsonMode: jsonMode
        )
    }
}
