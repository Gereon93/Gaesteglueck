import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OpenRouterModel: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
}

enum OpenRouterModelsAPI {
    enum Error: Swift.Error, LocalizedError {
        case invalidURL
        case unauthorized
        case rateLimited
        case http(Int, String?)
        case invalidJSON(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Ungültige Models-URL."
            case .unauthorized: return "API-Key ungültig oder fehlt."
            case .rateLimited: return "Rate-Limit erreicht — bitte gleich erneut versuchen."
            case .http(let code, let body):
                return "HTTP \(code)\(body.map { ": \($0)" } ?? "")"
            case .invalidJSON(let d): return "Ungültiges JSON: \(d)"
            }
        }
    }

    private struct Envelope: Codable {
        struct Entry: Codable {
            let id: String
            let name: String?
        }
        let data: [Entry]
    }

    static func listModels(
        apiKey: String?,
        baseURL: String = "https://openrouter.ai/api/v1",
        session: HTTPSession = OpenRouterClient.defaultSession
    ) async throws -> [OpenRouterModel] {
        guard let url = URL(string: "\(baseURL)/models") else { throw Error.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("Gaesteglueck", forHTTPHeaderField: "X-Title")
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200..<300: break
            case 401: throw Error.unauthorized
            case 429: throw Error.rateLimited
            default:
                let snippet = String(data: data, encoding: .utf8)?.prefix(400).description
                throw Error.http(http.statusCode, snippet)
            }
        }
        do {
            let env = try JSONDecoder().decode(Envelope.self, from: data)
            return env.data
                .map { OpenRouterModel(id: $0.id, name: $0.name ?? $0.id) }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
        } catch {
            let snippet = String(data: data, encoding: .utf8)?.prefix(400).description ?? "<binary>"
            throw Error.invalidJSON(snippet)
        }
    }
}
