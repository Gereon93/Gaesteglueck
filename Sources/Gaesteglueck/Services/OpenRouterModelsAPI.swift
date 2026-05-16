import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OpenRouterModel: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    /// USD pro 1 Token (Prompt bzw. Completion). nil = unbekannt/kostenlos.
    var promptUSDPerToken: Double? = nil
    var completionUSDPerToken: Double? = nil

    /// USD pro 1 Mio Tokens, gemittelt grob (Prompt+Completion)/2 für die
    /// Anzeige. nil wenn keine Preisinfo vorhanden (z.B. ":free"-Modelle).
    var blendedUSDPerMillion: Double? {
        guard let p = promptUSDPerToken, let c = completionUSDPerToken else { return nil }
        return (p + c) / 2 * 1_000_000
    }

    var priceLabel: String {
        guard let perM = blendedUSDPerMillion else { return "kostenlos / unbekannt" }
        if perM == 0 { return "kostenlos" }
        return String(format: "$%.2f / 1M Token", perM)
    }
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
        struct Pricing: Codable {
            let prompt: String?
            let completion: String?
        }
        struct Entry: Codable {
            let id: String
            let name: String?
            let pricing: Pricing?
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
                .map { entry in
                    OpenRouterModel(
                        id: entry.id,
                        name: entry.name ?? entry.id,
                        promptUSDPerToken: entry.pricing?.prompt.flatMap(Double.init),
                        completionUSDPerToken: entry.pricing?.completion.flatMap(Double.init)
                    )
                }
                .sorted { $0.name.lowercased() < $1.name.lowercased() }
        } catch {
            let snippet = String(data: data, encoding: .utf8)?.prefix(400).description ?? "<binary>"
            throw Error.invalidJSON(snippet)
        }
    }
}
