import Foundation

/// Hängt jeden LLM-Request/Response (oder Fehler) als JSON-Zeile an
/// `~/Library/Application Support/Gaesteglueck/llm-debug.log`. Damit ist nie
/// wieder ein Call "silent" — bei jedem komischen Verhalten kann man genau
/// nachsehen was rein- und rausging. Bewusst best-effort: Logging-Fehler
/// dürfen den eigentlichen Aufruf NICHT beeinflussen.
enum LLMDebugLog {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Gaesteglueck", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("llm-debug.log")
    }

    private static func timestamp() -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: Date())
    }

    private static func trunc(_ s: String, _ max: Int = 4000) -> String {
        s.count <= max ? s : String(s.prefix(max)) + "…[\(s.count - max) gekürzt]"
    }

    static let enabledKey = "llmDebugLogEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func record(
        feature: String,
        provider: String,
        model: String,
        request: [LLMMessage],
        response: String?,
        error: String?,
        durationMS: Int
    ) {
        guard isEnabled else { return }
        let reqJoined = request
            .map { "[\($0.role)] \(trunc($0.content, 2000))" }
            .joined(separator: "\n")
        let entry: [String: Any] = [
            "ts": timestamp(),
            "feature": feature,
            "provider": provider,
            "model": model,
            "durationMS": durationMS,
            "request": trunc(reqJoined),
            "response": response.map { trunc($0) } ?? NSNull(),
            "error": error ?? NSNull()
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: entry),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        let url = fileURL
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? line.data(using: .utf8)?.write(to: url)
        }
    }
}

/// Transparenter LLMClient-Wrapper der jeden Aufruf protokolliert und das
/// Ergebnis 1:1 durchreicht. Logging ist best-effort und ändert das
/// Verhalten des inneren Clients nicht.
extension LLMClient {
    var lmStudioClient: LMStudioClient? {
        if let lm = self as? LMStudioClient { return lm }
        if let logged = self as? LoggingLLMClient { return logged.wrapped as? LMStudioClient }
        return nil
    }
}

struct LoggingLLMClient: LLMClient {
    let wrapped: LLMClient
    let feature: String
    let provider: String
    let model: String

    func chat(
        messages: [LLMMessage],
        temperature: Double,
        maxTokens: Int,
        jsonMode: Bool
    ) async throws -> String {
        let start = Date()
        do {
            let out = try await wrapped.chat(
                messages: messages, temperature: temperature,
                maxTokens: maxTokens, jsonMode: jsonMode
            )
            LLMDebugLog.record(
                feature: feature, provider: provider, model: model,
                request: messages, response: out, error: nil,
                durationMS: Int(Date().timeIntervalSince(start) * 1000)
            )
            return out
        } catch {
            LLMDebugLog.record(
                feature: feature, provider: provider, model: model,
                request: messages, response: nil,
                error: String(describing: error),
                durationMS: Int(Date().timeIntervalSince(start) * 1000)
            )
            throw error
        }
    }

    func prompt(
        system: String,
        user: String,
        temperature: Double,
        jsonMode: Bool
    ) async throws -> String {
        try await chat(
            messages: [
                LLMMessage(role: "system", content: system),
                LLMMessage(role: "user", content: user)
            ],
            temperature: temperature,
            maxTokens: 4096,
            jsonMode: jsonMode
        )
    }
}
