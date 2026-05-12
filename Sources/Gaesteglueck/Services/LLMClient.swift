import Foundation

struct LLMMessage: Codable, Sendable {
    let role: String
    let content: String
}

protocol LLMClient: Sendable {
    func chat(messages: [LLMMessage], temperature: Double, maxTokens: Int, jsonMode: Bool) async throws -> String
    func prompt(system: String, user: String, temperature: Double, jsonMode: Bool) async throws -> String
}

extension LLMClient {
    func chat(messages: [LLMMessage], temperature: Double = 0.3, maxTokens: Int = 4096, jsonMode: Bool = false) async throws -> String {
        try await chat(messages: messages, temperature: temperature, maxTokens: maxTokens, jsonMode: jsonMode)
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
