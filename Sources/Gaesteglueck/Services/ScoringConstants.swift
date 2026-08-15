import Foundation

/// Gewichte des Sitzplan-Scorings.
///
/// `SeatingGraph` baut daraus die Kanten für den Optimierer, `HappinessScorer`
/// bewertet damit fertige Tische. Beide müssen dieselbe Skala benutzen, sonst
/// optimiert die App auf etwas anderes als sie anzeigt — deshalb liegen die
/// Werte hier zentral statt doppelt in beiden Typen.
enum ScoringConstants {

    // MARK: - Graph-Kanten

    /// Harte Constraints dominieren jede Tag- oder Familien-Kante.
    static let mustSitTogether: Double = 100
    static let mustNotSitTogether: Double = -500

    /// Familien-Tags binden stärker als Interessens-Tags.
    static let familyTagWeight: Double = 70
    static let otherTagWeight: Double = 40

    /// Paare bekommen extra Gewicht, damit Simulated Annealing sie zusammenhält.
    static let partnerPairWeight: Double = 150

    /// Kind-Eltern-Kante: hart, solange es keinen Kindertisch gibt — mit
    /// Kindertisch darf das Kind wechseln, die Kante wird weich und schwach.
    static let childParentWithChildTable: Double = 30
    static let childParentWithoutChildTable: Double = 100

    /// Gäste mit mindestens so vielen Tags verbinden Gruppen ("Brückenperson")
    /// und machen ihre Kanten etwas wertvoller.
    static let bridgePersonMinimumTags = 2
    static let bridgeEdgeBoost: Double = 10

    /// Tisch-Bonus bzw. -Malus für den Kindertisch.
    static let childAtChildTable: Double = 200
    static let adultAtChildTable: Double = -200

    // MARK: - Tisch-Bewertung

    /// Beide Partnerseiten am Tisch vertreten.
    static let partnerMixBonus: Double = 10

    /// Auslastung: fast voll ist besser als halb leer, aber kleine Ehrentische
    /// bekommen keinen Malus.
    static let nearFullFillRatio = 0.8
    static let nearFullFillBonus: Double = 15
    static let moderateFillRatio = 0.6
    static let moderateFillBonus: Double = 5

    static let bridgePersonBonus: Double = 15

    /// Mindestens ein Erwachsener an einem Tisch mit Kindern.
    static let generationMixBonus: Double = 20

    /// Anteil Kinder am Kindertisch, multipliziert mit diesem Faktor.
    static let childTableFractionBonus: Double = 30

    /// Gleiche Sonderkost an einem Tisch erleichtert der Küche die Arbeit.
    static let dietaryClusterBonus: Double = 3

    /// Rohscore → Anzeige-Note (0–100).
    static let displayScoreDivisor: Double = 2
    static let displayScoreMaximum: Double = 100
}

/// Parameter des Simulated-Annealing-Laufs im `SeatingOptimizer`.
/// Die Starttemperatur ist auf die realen Score-Deltas kalibriert
/// (Partner +150, Constraints +100).
enum SimulatedAnnealing {
    static let defaultIterations = 6000
    static let startTemperature = 60.0
    static let endTemperature = 0.05
}
