import Foundation

/// Grobe Kostenschätzung für OpenRouter-Bulk-Läufe (FunFact-Check /
/// -Vereinheitlichung über die ganze Gästeliste). Bewusst grob: ~4 Zeichen
/// = 1 Token, plus fixer System-Prompt-Overhead. Dient nur als Hausnummer
/// vor/nach einem Lauf, kein Abrechnungsersatz.
enum LLMCostEstimator {
    /// Heuristik: 1 Token ≈ 4 Zeichen.
    static func tokens(forChars chars: Int) -> Int { max(1, chars / 4) }

    /// Schätzt Prompt- + Completion-Tokens für einen Batch-FunFact-Lauf.
    /// `texts` = die FunFact-Rohtexte. System-Prompt-Overhead pauschal.
    static func funfactBatchTokens(texts: [String]) -> (prompt: Int, completion: Int) {
        let systemOverhead = 600                       // System-Prompt + JSON-Gerüst
        let inputChars = texts.reduce(0) { $0 + $1.count + 12 }  // +Key/Quotes/Zeilen
        let prompt = systemOverhead + tokens(forChars: inputChars)
        // Completion ~ Eingabe-Funfacts (umformuliert, ähnlich lang) + JSON.
        let completion = tokens(forChars: inputChars) + texts.count * 8
        return (prompt, completion)
    }

    /// USD für gegebene Token-Mengen bei einem Modellpreis (USD pro 1 Token).
    static func usd(
        promptTokens: Int,
        completionTokens: Int,
        promptUSDPerToken: Double,
        completionUSDPerToken: Double
    ) -> Double {
        Double(promptTokens) * promptUSDPerToken
            + Double(completionTokens) * completionUSDPerToken
    }

    /// Bequeme Variante mit einem gemittelten $/1M-Preis (wie im UI gezeigt).
    static func usd(
        promptTokens: Int,
        completionTokens: Int,
        blendedUSDPerMillion: Double
    ) -> Double {
        Double(promptTokens + completionTokens) / 1_000_000 * blendedUSDPerMillion
    }

    /// Formatiert klein: unter 1 $ mit 4 Nachkommastellen, sonst 2.
    static func format(usd: Double) -> String {
        if usd <= 0 { return "≈ $0" }
        if usd < 1 { return String(format: "≈ $%.4f", usd) }
        return String(format: "≈ $%.2f", usd)
    }
}
