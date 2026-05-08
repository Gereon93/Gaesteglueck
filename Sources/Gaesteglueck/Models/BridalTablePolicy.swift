import Foundation

/// User-konfigurierbare Regel: WER setzt sich an den Brautpaartisch (neben
/// dem Brautpaar)? Wird vom Sitzplaner als HARTE Regel respektiert. Default
/// ist Trauzeugen-Kreis weil das deutschlandweit am häufigsten ist; manche
/// Hochzeiten setzen aber lieber die Eltern hin.
enum BridalTablePolicy: String, CaseIterable, Identifiable, Sendable {
    /// Tags der Kategorie `.role` deren Name "Trauzeug"/"Bestman" enthält
    /// (egal ob Partner-Zuordnung Maria, Gereon oder Beide) → Brautpaartisch.
    case trauzeugen
    /// Gäste mit familyRole ∈ {Mutter, Vater} (beide Seiten) → Brautpaartisch.
    case eltern
    /// Trauzeugen UND Eltern beider Seiten am Brautpaartisch.
    case both
    /// Keine Auto-Regel — der User pinnt selbst per Hand.
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .trauzeugen: return "Trauzeugen"
        case .eltern: return "Eltern"
        case .both: return "Trauzeugen + Eltern"
        case .manual: return "Manuell"
        }
    }

    var explanation: String {
        switch self {
        case .trauzeugen: return "Trauzeugen / Brautjungfern sitzen automatisch am Brautpaartisch. Eltern bekommen einen eigenen Tisch."
        case .eltern: return "Eltern beider Seiten sitzen am Brautpaartisch. Trauzeugen kriegen einen eigenen oder werden vom Sitzplaner platziert."
        case .both: return "Trauzeugen UND Eltern beider Seiten am Brautpaartisch (kann eng werden — Brauttafel sollte mind. 10 Plätze haben)."
        case .manual: return "Keine Auto-Regel — du pinnst selbst wer am Brautpaartisch sitzt."
        }
    }
}
