import Foundation

enum PhoneFormatter {
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        var digitsAndPlus = ""
        for ch in trimmed.unicodeScalars {
            if ch == "+" || CharacterSet.decimalDigits.contains(ch) {
                digitsAndPlus.unicodeScalars.append(ch)
            }
        }
        let cleaned = digitsAndPlus.replacingOccurrences(of: "+0", with: "+")

        if cleaned.hasPrefix("+") { return cleaned }
        if cleaned.hasPrefix("00") { return "+" + cleaned.dropFirst(2) }
        if cleaned.hasPrefix("0") { return "+49" + cleaned.dropFirst() }
        return cleaned
    }

    static func display(_ raw: String) -> String {
        let n = normalize(raw)
        guard n.hasPrefix("+") else { return n }
        let cc = countryCode(in: n)
        let rest = String(n.dropFirst(cc.count))
        guard rest.count > 4 else { return "\(cc) \(rest)" }
        let prefix = String(rest.prefix(3))
        let suffix = String(rest.dropFirst(3))
        return "\(cc) \(prefix) \(suffix)"
    }

    static func areEquivalent(_ a: String, _ b: String) -> Bool {
        normalize(a) == normalize(b)
    }

    private static let threeDigitCountryCodes: Set<String> = [
        "+352", "+423", "+377", "+378", "+420", "+421", "+385", "+386"
    ]
    private static let oneDigitCountryCodes: Set<Character> = ["1", "7"]

    private static func countryCode(in normalized: String) -> String {
        if threeDigitCountryCodes.first(where: { normalized.hasPrefix($0) }) != nil {
            return String(normalized.prefix(4))
        }
        let afterPlus = normalized.dropFirst()
        if let firstDigit = afterPlus.first, oneDigitCountryCodes.contains(firstDigit) {
            return String(normalized.prefix(2))
        }
        return String(normalized.prefix(3))
    }
}
