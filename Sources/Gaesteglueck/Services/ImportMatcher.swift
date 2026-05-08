import Foundation

/// Entscheidet beim Import ob ein Gast neu angelegt oder ein bestehender
/// aktualisiert werden soll. Reine Namens-Matches sind nicht ausreichend
/// (es gibt zwei Horst Maiers) — wir vergleichen primär die stabile
/// `sourceID` (Email > Telefon > Zeitstempel + Familienname > Zeilennummer)
/// aus der Import-Quelle. Nur wenn beide Seiten dieselbe sourceID haben UND
/// die Namen passen ist es ein eindeutiges Update.
enum ImportMatcher {
    enum MatchType: Equatable {
        /// Bisher unbekannter Gast — wird neu angelegt.
        case new
        /// Gleiche sourceID + passender Name → sicheres Update.
        case updateBySource
        /// Name passt, aber sourceID ist anders/leer → könnte derselbe Gast
        /// sein oder ein zweiter mit gleichem Namen. Default: neu anlegen,
        /// User kann im Edit-Sheet entscheiden.
        case nameMatchOnly
    }

    static func classify(
        guest: ImportedGuest,
        in row: RegistrationRow,
        among existing: [Guest]
    ) -> MatchType {
        if findBySource(guest: guest, in: row, among: existing) != nil {
            return .updateBySource
        }
        if findByNameOnly(guest: guest, among: existing) != nil {
            return .nameMatchOnly
        }
        return .new
    }

    /// Liefert den existierenden Gast zurück der definitiv zu diesem Import
    /// gehört (gleiche Quelle + Name). Für reine Name-Matches `nil` damit
    /// Caller bewusst entscheidet.
    static func findExisting(
        guest: ImportedGuest,
        in row: RegistrationRow,
        among existing: [Guest]
    ) -> Guest? {
        findBySource(guest: guest, in: row, among: existing)
    }

    private static func findBySource(
        guest: ImportedGuest,
        in row: RegistrationRow,
        among existing: [Guest]
    ) -> Guest? {
        let sourceID = row.sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sourceID.isEmpty else { return nil }
        let candidates = existing.filter { $0.sourceID == sourceID }
        guard !candidates.isEmpty else { return nil }
        // Bei einer Anmeldung mit nur EINER Person matchen wir per sourceID
        // direkt — auch wenn der Nachname leicht anders ist (z.B. Heirat
        // zwischen Anmeldung und Re-Import). Sonst würde aus einem Update
        // fälschlich ein Neuanlegen.
        if candidates.count == 1 { return candidates.first }
        // Mehrere Personen pro sourceID (Familie, Paar): erst kompletter
        // Name-Match, dann Vorname-Match damit Steffi Falk → Steffi Sturm
        // als Update erkannt wird (nur Nachname getauscht).
        if let exact = candidates.first(where: { matchesName(guest: guest, against: $0) }) {
            return exact
        }
        let normalizedFirst = normalize(guest.firstName)
        if !normalizedFirst.isEmpty,
           let firstNameMatch = candidates.first(where: { normalize($0.firstName) == normalizedFirst }) {
            return firstNameMatch
        }
        return nil
    }

    private static func findByNameOnly(
        guest: ImportedGuest,
        among existing: [Guest]
    ) -> Guest? {
        existing.first { matchesName(guest: guest, against: $0) }
    }

    private static func matchesName(guest: ImportedGuest, against other: Guest) -> Bool {
        let firstA = normalize(guest.firstName)
        let lastA = normalize(guest.lastName)
        let firstB = normalize(other.firstName)
        let lastB = normalize(other.lastName)
        guard !firstA.isEmpty else { return false }
        return firstA == firstB && lastA == lastB
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Einzelne Feld-Abweichung für die Diff-Anzeige im Import-Sheet.
struct ImportDiffField: Equatable, Sendable {
    let label: String
    let oldValue: String
    let newValue: String
}

extension ImportMatcher {
    /// Vergleicht den geparsten Gast mit dem bestehenden Datensatz und gibt
    /// nur die Felder zurück die wirklich unterschiedlich sind. funFact und
    /// notes werden bewusst ignoriert weil manuelle Pflege Vorrang vor
    /// Auto-Extraktion hat (siehe applyRow-Logik).
    static func diff(parsed: ImportedGuest, existing: Guest) -> [ImportDiffField] {
        var diffs: [ImportDiffField] = []
        let normFirst = parsed.firstName.trimmingCharacters(in: .whitespaces)
        let normLast = parsed.lastName.trimmingCharacters(in: .whitespaces)
        if existing.firstName.lowercased() != normFirst.lowercased(), !normFirst.isEmpty {
            diffs.append(ImportDiffField(label: "Vorname", oldValue: existing.firstName, newValue: normFirst))
        }
        if existing.lastName.lowercased() != normLast.lowercased() {
            diffs.append(ImportDiffField(label: "Nachname", oldValue: existing.lastName.isEmpty ? "—" : existing.lastName, newValue: normLast.isEmpty ? "—" : normLast))
        }
        if existing.dietaryChoice != parsed.dietaryChoice {
            diffs.append(ImportDiffField(label: "Menü", oldValue: existing.dietaryChoice, newValue: parsed.dietaryChoice))
        }
        let oldIntol = Set(existing.intolerances.map { $0.lowercased() })
        let newIntol = Set(parsed.intolerances.map { $0.lowercased() })
        if oldIntol != newIntol {
            let oldStr = existing.intolerances.isEmpty ? "—" : existing.intolerances.joined(separator: ", ")
            let newStr = parsed.intolerances.isEmpty ? "—" : parsed.intolerances.joined(separator: ", ")
            diffs.append(ImportDiffField(label: "Allergie", oldValue: oldStr, newValue: newStr))
        }
        if existing.ageCategory != parsed.ageCategory {
            diffs.append(ImportDiffField(label: "Alter", oldValue: existing.ageCategory.rawValue, newValue: parsed.ageCategory.rawValue))
        }
        return diffs
    }
}
