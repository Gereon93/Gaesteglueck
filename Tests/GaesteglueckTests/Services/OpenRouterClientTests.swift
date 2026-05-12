import Testing
import Foundation
@testable import Gaesteglueck

private struct StubSession: HTTPSession {
    let handler: @Sendable (URLRequest) -> (Data, URLResponse)

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        handler(request)
    }
}

private func makeResponse(status: Int, url: URL) -> HTTPURLResponse {
    HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
}

@Suite("OpenRouterClient")
struct OpenRouterClientTests {
    @Test("Chat schickt Bearer-Header und gibt Content zurück")
    func chatHappyPath() async throws {
        let payload: [String: Any] = [
            "model": "anthropic/claude-3.5-sonnet",
            "choices": [
                ["message": ["content": "Servus"], "finish_reason": "stop"]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)

        let stub = StubSession { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            #expect(request.value(forHTTPHeaderField: "X-Title") == "Gaesteglueck")
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            return (body, makeResponse(status: 200, url: request.url!))
        }

        let client = OpenRouterClient(
            apiKey: "test-key",
            model: "anthropic/claude-3.5-sonnet",
            session: stub
        )
        let result = try await client.chat(
            messages: [LLMMessage(role: "user", content: "Hi")],
            temperature: 0.5,
            maxTokens: 500,
            jsonMode: false
        )
        #expect(result == "Servus")
    }

    @Test("401 wirft unauthorized")
    func unauthorized() async {
        let stub = StubSession { request in
            (Data("unauthorized".utf8), makeResponse(status: 401, url: request.url!))
        }
        let client = OpenRouterClient(apiKey: "bad", model: "x/y", session: stub)
        await #expect(throws: OpenRouterClient.OpenRouterError.self) {
            _ = try await client.prompt(system: "s", user: "u")
        }
    }

    @Test("429 wirft rateLimited")
    func rateLimited() async {
        let stub = StubSession { request in
            (Data("rate".utf8), makeResponse(status: 429, url: request.url!))
        }
        let client = OpenRouterClient(apiKey: "k", model: "x/y", session: stub)
        await #expect(throws: OpenRouterClient.OpenRouterError.self) {
            _ = try await client.prompt(system: "s", user: "u")
        }
    }

    @Test("Leerer API-Key wirft missingAPIKey")
    func missingAPIKey() async {
        let client = OpenRouterClient(apiKey: "", model: "x/y", session: StubSession { _ in
            (Data(), URLResponse())
        })
        await #expect(throws: OpenRouterClient.OpenRouterError.self) {
            _ = try await client.chat(messages: [], temperature: 0.0, maxTokens: 10, jsonMode: false)
        }
    }
}

@Suite("OpenRouterModelsAPI")
struct OpenRouterModelsAPITests {
    @Test("Models werden geparst und alphabetisch sortiert")
    func parseModels() async throws {
        let payload: [String: Any] = [
            "data": [
                ["id": "x/zebra", "name": "Zebra"],
                ["id": "x/alpha", "name": "Alpha"],
                ["id": "x/no-name"]
            ]
        ]
        let body = try JSONSerialization.data(withJSONObject: payload)
        let stub = StubSession { request in
            #expect(request.url?.path.hasSuffix("/models") == true)
            return (body, makeResponse(status: 200, url: request.url!))
        }
        let models = try await OpenRouterModelsAPI.listModels(apiKey: "k", session: stub)
        #expect(models.count == 3)
        #expect(models.first?.name == "Alpha")
        #expect(models.contains { $0.id == "x/no-name" && $0.name == "x/no-name" })
    }

    @Test("401 wirft unauthorized")
    func modelsUnauthorized() async {
        let stub = StubSession { request in
            (Data("nope".utf8), makeResponse(status: 401, url: request.url!))
        }
        await #expect(throws: OpenRouterModelsAPI.Error.self) {
            _ = try await OpenRouterModelsAPI.listModels(apiKey: "bad", session: stub)
        }
    }
}

@Suite("LLMClientFactory")
struct LLMClientFactoryTests {
    private func defaults(_ suite: String) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test("Default ist LM Studio")
    func defaultProvider() {
        let d = defaults("ggtest.factory.default")
        let client = LLMClientFactory.makeFromSettings(defaults: d)
        #expect(client is LMStudioClient)
    }

    @Test("OpenRouter mit Key + Modell liefert OpenRouterClient")
    func openRouterClient() {
        let d = defaults("ggtest.factory.or")
        d.set(LLMProvider.openRouter.rawValue, forKey: LLMClientFactory.providerKey)
        d.set("x/y", forKey: LLMClientFactory.openRouterModelKey)
        let client = LLMClientFactory.makeFromSettings(defaults: d, apiKey: "k")
        #expect(client is OpenRouterClient)
    }

    @Test("OpenRouter ohne Key fällt auf LM Studio zurück")
    func openRouterFallback() {
        let d = defaults("ggtest.factory.fallback")
        d.set(LLMProvider.openRouter.rawValue, forKey: LLMClientFactory.providerKey)
        // Kein API-Key
        let client = LLMClientFactory.makeFromSettings(defaults: d)
        #expect(client is LMStudioClient)
    }
}
