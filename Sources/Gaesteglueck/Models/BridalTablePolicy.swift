import Foundation

/// User-konfigurierbare Regel: WER setzt sich an den Brautpaartisch (neben
/// dem Brautpaar)? Wird vom Sitzplaner als HARTE Regel respektiert. Default
/// ist Trauzeugen-Kreis weil das deutschlandweit am häufigsten ist; manche
/// Hochzeiten setzen aber lieber die Eltern hin.
enum BridalTablePolicy: String, CaseIterable, Identifiable, Sendable {
    case brautpaarOnly
    case trauzeugen
    case eltern
    case both
    case trauzeugenGeschwister
    case manual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .brautpaarOnly: return "Nur Brautpaar"
        case .trauzeugen: return "+ Trauzeugen"
        case .eltern: return "+ Eltern"
        case .both: return "+ Trauzeugen + Eltern"
        case .trauzeugenGeschwister: return "+ Trauzeugen + Geschwister"
        case .manual: return "Manuell"
        }
    }

    var explanation: String {
        switch self {
        case .brautpaarOnly: return "Nur das Brautpaar selbst sitzt am Brauttisch. Alle anderen verteilen sich frei."
        case .trauzeugen: return "Trauzeugen / Brautjungfern sitzen mit am Brauttisch. Eltern bekommen einen eigenen Tisch."
        case .eltern: return "Eltern beider Seiten sitzen am Brauttisch. Trauzeugen kriegen einen eigenen Tisch."
        case .both: return "Trauzeugen UND Eltern beider Seiten am Brauttisch (kann eng werden — Brauttafel sollte mind. 10 Plätze haben)."
        case .trauzeugenGeschwister: return "Trauzeugen + Geschwister beider Seiten am Brauttisch. Eltern bekommen einen eigenen Tisch."
        case .manual: return "Keine Auto-Regel — du pinnst selbst wer am Brauttisch sitzt."
        }
    }
}
