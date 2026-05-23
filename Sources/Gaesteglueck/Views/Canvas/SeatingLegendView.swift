#if canImport(SwiftUI)
import SwiftUI

/// Schwebende Legende am Canvas. Erklärt der Catering-Crew Diät-Farben,
/// Allergen-Nummern, Alters-Marker und Symbole (Brauttafel-Herz, Tisch-
/// Warnung). Sektionen erscheinen nur wenn sie laut Toggles aktiv sind und
/// es etwas zu erklären gibt.
struct SeatingLegendView: View {
    let legend: SeatingLegend
    let infoDisplay: SeatInfoDisplay
    var showAge: Bool = false
    var hasBridalTable: Bool = false
    var showTableWarnings: Bool = false
    var showCoupleMarker: Bool = false
    /// Kreis-Inhalt kann Allergen-Nummern/Alters-Icons zeigen, auch wenn der
    /// jeweilige Anzeigemodus aus ist — dann muss die Legende sie trotzdem erklären.
    var chipContent: SeatChipContent = .initials

    private var showDiet: Bool { infoDisplay.showsDiet }
    private var showIntol: Bool {
        (infoDisplay.showsIntolerance || chipContent.showsIntolerance) && !legend.isEmpty
    }
    private var showAgeSection: Bool {
        (showAge || chipContent.showsAge) && legend.hasAgeMarkers
    }
    private var showWarningSymbol: Bool { showTableWarnings && !legend.isEmpty }
    private var showSymbols: Bool { hasBridalTable || showWarningSymbol || showCoupleMarker }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: 8) {
                Text("Legende")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .textCase(.uppercase)
                    .tracking(0.5)

                if showDiet {
                    let columns = [GridItem(.adaptive(minimum: 95), spacing: 6, alignment: .leading)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                        // Fleisch nutzt accentTint (= echter Chip-Fill) statt einer
                        // hellen Variante von accent, damit Swatch und Chip 1:1 matchen.
                        dietSwatch(fill: Tokens.Colors.accentTint,
                                   border: Tokens.Colors.accent.opacity(0.7),
                                   label: "Fleisch")
                        dietSwatch(fill: Tokens.Colors.dietVegan.opacity(0.20),
                                   border: Tokens.Colors.dietVegan,
                                   label: "Vegan")
                        dietSwatch(fill: Tokens.Colors.dietVegetarian.opacity(0.20),
                                   border: Tokens.Colors.dietVegetarian,
                                   label: "Vegetarisch")
                    }
                }

                if showIntol {
                    if showDiet { divider }
                    sectionHeader("Unverträglichkeiten")
                    legendNumberGrid
                }

                if showAgeSection {
                    if showDiet || showIntol { divider }
                    sectionHeader("Alter")
                    legendAgeGrid
                }

                if showSymbols {
                    if showDiet || showIntol || showAgeSection { divider }
                    sectionHeader("Symbole")
                    if showCoupleMarker { coupleLegendRow }
                    if hasBridalTable { heartLegendRow }
                    if showWarningSymbol { warningLegendRow }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Tokens.Colors.surface.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
            .frame(minWidth: 180, maxWidth: 300, alignment: .leading)
        }
    }

    private var shouldShow: Bool {
        showDiet || showIntol || showAgeSection || showSymbols
    }

    private var divider: some View { Divider().padding(.vertical, 1) }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.Colors.ink3)
            .textCase(.uppercase)
            .tracking(0.4)
    }

    /// Mini-Chip wie am Sitz — Fill und Border explizit, damit Fleisch
    /// (accentTint + accent-Border) exakt wie der Chip aussieht.
    @ViewBuilder
    private func dietSwatch(fill: Color, border: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(fill)
                .overlay(Circle().strokeBorder(border, lineWidth: 1.5))
                .frame(width: 11, height: 11)
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
        }
    }

    @ViewBuilder
    private var coupleLegendRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            coupleEntry(glyph: "👰", label: "Braut")
            coupleEntry(glyph: "🤵", label: "Bräutigam")
        }
    }

    @ViewBuilder
    private func coupleEntry(glyph: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(glyph)
                .font(.system(size: 12))
                .frame(width: 14, height: 14)
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
        }
    }

    @ViewBuilder
    private var heartLegendRow: some View {
        HStack(spacing: 6) {
            ZStack {
                Circle().fill(Tokens.Colors.accent)
                Image(systemName: "heart.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.white)
            }
            .frame(width: 14, height: 14)
            Text("Brauttafel")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
        }
    }

    @ViewBuilder
    private var warningLegendRow: some View {
        HStack(spacing: 6) {
            ZStack {
                Capsule().fill(Tokens.Colors.error)
                HStack(spacing: 1) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 6, weight: .bold))
                    Text("n")
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
            }
            .frame(width: 22, height: 13)
            Text("Gäste mit Unverträglichkeit am Tisch")
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var legendAgeGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 6, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(legend.ageCategories) { age in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Tokens.Colors.tagActivity)
                        Image(systemName: age.iconName)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 14, height: 14)
                    Text(age.rawValue)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                }
            }
        }
    }

    @ViewBuilder
    private var legendNumberGrid: some View {
        let columns = [GridItem(.adaptive(minimum: 110), spacing: 6, alignment: .leading)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
            ForEach(legend.entries) { entry in
                HStack(spacing: 6) {
                    Text("\(entry.number)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(minWidth: 14, minHeight: 14)
                        .padding(.horizontal, 2)
                        .background(Capsule().fill(Tokens.Colors.error))
                        .fixedSize()
                    Text(entry.name)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                }
            }
        }
    }
}
#endif
