#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Wizard Phase

enum WizardPhase: Int, CaseIterable {
    case clusters
    case harmony
    case childTable
    case tableConfig
    case seatingPlan
    case done

    var title: String {
        switch self {
        case .clusters: "Gruppen"
        case .harmony: "Harmonie"
        case .childTable: "Kindertisch"
        case .tableConfig: "Tischkonfiguration"
        case .seatingPlan: "Sitzplan"
        case .done: "Fertig"
        }
    }

    var icon: String {
        switch self {
        case .clusters: "person.3"
        case .harmony: "heart"
        case .childTable: "figure.child"
        case .tableConfig: "tablecells"
        case .seatingPlan: "list.bullet"
        case .done: "checkmark.circle"
        }
    }

    var prompt: String {
        switch self {
        case .clusters:
            return "Analysiere die Gruppen und Cluster in der Gästeliste. Welche Gruppen gibt es und wer verbindet sie? Gib konkrete Empfehlungen auf Deutsch."
        case .harmony:
            return "Analysiere potenzielle Spannungen oder Konflikte zwischen den Gästen basierend auf den Constraints und Tags. Was sollte bei der Tischzuweisung besonders beachtet werden?"
        case .childTable:
            return "Empfehle eine optimale Strategie für Kinder und Kleinkinder bei der Tischzuteilung. Welche Erwachsenen sollten in der Nähe sitzen?"
        case .tableConfig:
            return "Basierend auf der Gästeanzahl und den Gruppen: Wie viele Tische welcher Art werden empfohlen? Gib konkrete Tischgrößen und Konfigurationen an."
        case .seatingPlan:
            return "Erstelle einen konkreten Sitzplan: Welche Gäste sollen an welchen Tischen sitzen? Begründe die Zuteilungen kurz."
        case .done:
            return ""
        }
    }
}
#endif
