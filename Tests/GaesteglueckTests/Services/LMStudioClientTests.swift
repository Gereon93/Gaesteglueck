import Testing
import Foundation
@testable import Gaesteglueck

@Suite("LMStudioClient")
struct LMStudioClientTests {
    @Test("Default endpoint is localhost:1234")
    func defaultEndpoint() async {
        let client = LMStudioClient()
        let endpoint = await client.endpoint
        #expect(endpoint == "http://localhost:1234")
    }

    @Test("Custom endpoint")
    func customEndpoint() async {
        let client = LMStudioClient(endpoint: "http://macmini.local:1234")
        let endpoint = await client.endpoint
        #expect(endpoint == "http://macmini.local:1234")
    }

    @Test("Request body encoding")
    func requestEncoding() throws {
        let request = LMStudioClient.ChatRequest(
            model: "gemma-4-12b",
            messages: [
                LMStudioClient.Message(role: "system", content: "Du bist ein Assistent."),
                LMStudioClient.Message(role: "user", content: "Hallo")
            ],
            temperature: 0.3,
            max_tokens: 4096,
            response_format: nil
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode(LMStudioClient.ChatRequest.self, from: data)
        #expect(json.model == "gemma-4-12b")
        #expect(json.messages.count == 2)
        #expect(json.temperature == 0.3)
    }
}
