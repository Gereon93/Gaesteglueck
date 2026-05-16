import Foundation

/// Nutzer-sichtbare KI-Funktionen. Jede kann in den Einstellungen einen
/// eigenen Provider (LM Studio / OpenRouter) + Modell bekommen. Die vielen
/// internen Call-Sites werden auf diese 5 Gruppen gemappt.
enum AIFeature: String, CaseIterable, Identifiable, Sendable {
    case chat          // KI-Chat, Co-Pilot, Wizard
    case tags          // Tag-Generator
    case seating       // Saal-Konfigurator, KI-Sitzvorschlag
    case funfact       // FunFact-Check & -Vereinheitlichung
    case importParse   // CSV/Excel-Import-Parsing

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chat: "Chat & Co-Pilot"
        case .tags: "Tag-Generator"
        case .seating: "Sitzplan-KI"
        case .funfact: "FunFact-KI"
        case .importParse: "Import-Parsing"
        }
    }

    var hint: String {
        switch self {
        case .chat: "Frei­text-Chat, Sitzplan-Co-Pilot, Wizard"
        case .tags: "Automatische Tag-Vorschläge aus Gästedaten"
        case .seating: "KI-generierte Sitzordnung"
        case .funfact: "Bewertet & vereinheitlicht FunFacts"
        case .importParse: "Spalten-Erkennung beim Import"
        }
    }

    var providerKey: String { "aiProvider.\(rawValue)" }
    var modelKey: String { "aiModel.\(rawValue)" }
    var modelPriceKey: String { "aiModelPricePerM.\(rawValue)" }
}
