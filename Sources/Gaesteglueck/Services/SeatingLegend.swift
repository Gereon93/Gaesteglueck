import Foundation

/// Vergibt stabile Nummern für alle einzigartigen Unverträglichkeiten in der
/// Gästeliste. Die Nummern werden am Sitz-Chip + Namen angezeigt, die Auflösung
/// (Nr → "Gluten", "Laktose" …) steht in der Canvas-Legende unten. So weiß die
/// Catering-Crew was zu tun ist, ohne dass am Chip lange Texte stehen.
struct SeatingLegend: Sendable, Equatable {
    /// Stabile Reihenfolge: Eintrag i → Nummer (i+1) und ausgeschriebener Name.
    struct Entry: Sendable, Equatable, Identifiable {
        let number: Int
        let name: String
        var id: Int { number }
    }

    let entries: [Entry]
    private let indexByName: [String: Int]
    /// Vorhandene Nicht-Erwachsenen-Altersgruppen unter den Gästen, in
    /// natürlicher Reihenfolge (Teenager → Kind → Kleinkind → Baby). Für die
    /// Alters-Sektion der Legende.
    let ageCategories: [AgeCategory]

    init(guests: [Guest]) {
        // Dedup case/diakritika-insensitiv über einen Lookup-Key, aber den
        // zuerst gesehenen Originaltext als Anzeigenamen behalten. So zählen
        // "Gluten"/"gluten"/"GLUTEN" als EIN Allergen mit stabiler Nummer.
        var displayByKey: [String: String] = [:]
        // Nicht nach `hasIntolerances` filtern (das prüft nur !isEmpty, nicht
        // ob nach Trim was übrig bleibt). Die Trim-Prüfung steht eh unten.
        for g in guests {
            for raw in g.intolerances {
                let trimmed = Self.normalize(raw)
                guard !trimmed.isEmpty else { continue }
                let key = Self.dedupKey(trimmed)
                if displayByKey[key] == nil { displayByKey[key] = trimmed }
            }
        }
        // Sortierung mit fester POSIX-Locale, damit Nummern auf jedem Gerät
        // identisch sind (unabhängig von der System-Sprache).
        let sortedKeys = displayByKey.keys.sorted {
            (displayByKey[$0] ?? $0).lowercased(with: Self.stableLocale)
                < (displayByKey[$1] ?? $1).lowercased(with: Self.stableLocale)
        }
        var idx: [String: Int] = [:]
        var built: [Entry] = []
        for (i, key) in sortedKeys.enumerated() {
            let n = i + 1
            idx[key] = n
            built.append(Entry(number: n, name: displayByKey[key] ?? key))
        }
        self.entries = built
        self.indexByName = idx

        let present = Set(guests.map(\.ageCategory))
        self.ageCategories = AgeCategory.allCases.filter {
            $0.isMarkedAge && present.contains($0)
        }
    }

    var isEmpty: Bool { entries.isEmpty }
    var hasAgeMarkers: Bool { !ageCategories.isEmpty }

    /// Sortierte Nummern-Liste für einen Gast. Leer wenn der Gast keine
    /// (gelisteten) Unverträglichkeiten hat.
    func numbers(for guest: Guest) -> [Int] {
        Set(guest.intolerances
            .map(Self.normalize)
            .filter { !$0.isEmpty }
            .compactMap { indexByName[Self.dedupKey($0)] })
            .sorted()
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Feste Locale für deterministische Sortierung/Folding — System-Locale
    /// würde die Nummerierung zwischen Geräten variieren lassen.
    private static let stableLocale = Locale(identifier: "en_US_POSIX")

    /// Lookup-Key für Deduplizierung: case- und diakritika-insensitiv,
    /// mit fester Locale (deterministisch).
    private static func dedupKey(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: stableLocale)
    }
}
