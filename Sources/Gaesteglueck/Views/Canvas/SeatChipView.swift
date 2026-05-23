#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Kleiner Sitz-Punkt um den Tisch herum. Empty = grau-gestrichelt; Occupied
/// = farbig mit Initialen + ggf. Diät- und/oder Allergie-Indikator. Drop-Ziel
/// für Guest-IDs und draggable wenn besetzt — beides läuft über den
/// `String`-Pasteboard, genau wie bei der Gäste-Liste.
struct SeatChipView: View {
    /// Chip-Durchmesser in Punkten; Namen-Offsets leiten sich daraus ab.
    static let chipSize: CGFloat = 22
    /// Spalt zwischen Chip-Rand und Namens-Innenkante (für showName).
    static let nameGap: CGFloat = 6

    let seatIndex: Int
    let occupant: Guest?
    /// Wird gerufen wenn ein Gast (per UUID-String) auf diesen Sitz gedroppt wird.
    let onDrop: (UUID) -> Bool
    /// Wird gerufen wenn der User den Sitz leert (Doppelklick / Context-Menü).
    let onClear: () -> Void
    let isDisabled: Bool
    let onToggleDisabled: () -> Void
    /// Damit Initialen lesbar bleiben wenn der Tisch rotiert ist: wir
    /// drehen den Text gegen die Tisch-Rotation. Default 0 = nicht rotiert.
    var counterRotation: Double = 0
    /// Wenn true, wird der volle Name permanent neben dem Sitz angezeigt
    /// (statt nur bei Hover) — für Screenshot-taugliche Sitzpläne.
    var showName: Bool = false
    /// Bereits aufgelöste Seite (nie `.auto`) auf der der Name gezeichnet wird.
    /// Achsen-aligned & fixe Distanz → alle Namen einer Tischkante stehen auf
    /// gleicher Höhe/Spalte, kein radialer Stagger.
    var resolvedNameSide: SeatNameSide = .top
    /// Anzeige-Name gemäß gewähltem Namen-Stil. Nil → voller Name.
    var displayName: String? = nil
    /// Welche Zusatz-Indikatoren (Diät, Allergie) am Chip gezeichnet werden.
    var infoDisplay: SeatInfoDisplay = .none
    /// Sortierte Allergen-Nummern für diesen Gast aus der globalen Legende.
    /// Leer wenn keine Unverträglichkeiten ODER Legende nicht verfügbar.
    var intoleranceNumbers: [Int] = []
    /// Alters-Marker (Kind/Baby/…) am Chip einblenden. Unabhängig vom
    /// Diät/Allergie-Modus, da Alter eine orthogonale Information ist.
    var showAgeMarker: Bool = false
    /// Was im Kreis steht (Initialen / Allergen-Nummer / Alters-Icon). Fällt
    /// pro Gast auf Initialen zurück, wenn das Merkmal fehlt.
    var chipContent: SeatChipContent = .initials
    /// Schriftgröße des angezeigten Namens (px). Default 9; per Toolbar wählbar.
    var nameFontSize: CGFloat = 9
    /// Gast ist Teil des Brautpaars (Name = Event-Partner). Wenn zusätzlich
    /// `showCoupleMarker` an ist, bekommt der Kreis ein Kronen-Icon.
    var isCouple: Bool = false
    var showCoupleMarker: Bool = false

    @State private var isDropTargeted: Bool = false
    @State private var isHovering: Bool = false
    /// Gemessene Größe des Namens-Labels (vor Gegenrotation). Wird gebraucht um
    /// den Offset so zu wählen, dass die Label-Kante exakt am Chip + Gap sitzt —
    /// auch bei gedrehten Tischen, wo `rotationEffect` die Layout-Box nicht ändert.
    @State private var nameSize: CGSize = .zero

    private var initials: String {
        guard let g = occupant else { return "" }
        let first = g.firstName.prefix(1)
        let last = g.lastName.prefix(1)
        return (first + last).uppercased()
    }

    private var fillColor: Color {
        if isDisabled { return Tokens.Colors.surface.opacity(0.4) }
        if isDropTargeted { return Tokens.Colors.accentSoft }
        if occupant == nil { return Tokens.Colors.surface }
        // Diät färbt den ganzen Chip (heller Tint), damit Veggie/Vegan auf einen
        // Blick erkennbar ist — nicht nur ein Punkt. Initialen bleiben lesbar.
        if infoDisplay.showsDiet, let d = dietBadgeColor { return d.opacity(0.20) }
        return Tokens.Colors.accentTint
    }

    private var strokeColor: Color {
        if isDropTargeted { return Tokens.Colors.accent }
        if occupant == nil { return Tokens.Colors.line2 }
        if infoDisplay.showsDiet, let d = dietBadgeColor { return d }
        return Tokens.Colors.accent.opacity(0.7)
    }

    private var tooltip: String {
        if let g = occupant {
            var t = "Sitz \(seatIndex + 1) — \(g.fullName)"
            if g.ageCategory.isMarkedAge {
                t += " · \(g.ageCategory.rawValue)"
            }
            switch g.dietaryChoice.lowercased() {
            case "vegetarisch": t += " · Vegetarisch"
            case "vegan": t += " · Vegan"
            default: break
            }
            if g.hasIntolerances {
                t += " ⚠️ \(g.intolerances.joined(separator: ", "))"
            }
            return t
        }
        return "Sitz \(seatIndex + 1) — frei. Gast hierher ziehen."
    }

    /// Reiner Diät-Indikator (nur vegan/vegetarisch, ohne Allergie-Override).
    private var dietBadgeColor: Color? {
        guard let g = occupant else { return nil }
        switch g.dietaryChoice.lowercased() {
        case "vegan": return Tokens.Colors.dietVegan
        case "vegetarisch": return Tokens.Colors.dietVegetarian
        default: return nil
        }
    }

    private var hasIntolerance: Bool { occupant?.hasIntolerances ?? false }

    /// Brautpaar-Glyph nach Geschlecht: 👰 Braut, 🤵 Bräutigam, sonst 👑.
    private var coupleGlyph: String {
        switch occupant?.gender {
        case .female: return "👰"
        case .male: return "🤵"
        default: return "👑"
        }
    }

    /// Kompakter Text fürs Chip-Badge: "1" / "1,2" / "1+" wenn ≥ 3 Nummern.
    /// Bei leerem Legenden-Mapping (defensive Fallback) → "⚠".
    private var intoleranceChipText: String {
        guard !intoleranceNumbers.isEmpty else { return "⚠" }
        if intoleranceNumbers.count >= 3 {
            return "\(intoleranceNumbers[0])+"
        }
        return intoleranceNumbers.map(String.init).joined(separator: ",")
    }

    /// Längere Inline-Form neben dem Namen: zeigt alle Nummern komma-getrennt.
    /// "⚠" als Fallback wenn keine Legenden-Auflösung verfügbar.
    private var intoleranceInlineText: String {
        guard !intoleranceNumbers.isEmpty else { return "⚠" }
        return intoleranceNumbers.map(String.init).joined(separator: ",")
    }

    /// Alters-Badge unten-links — blaues Symbol, klar abgesetzt von Diät (Gold/
    /// Grün), Allergie (Rot) und Braut (Rosa). Gegenrotation hält das Icon
    /// aufrecht bei gedrehten Tischen.
    /// Was tatsächlich im Kreis steht — nur drei konkrete Möglichkeiten,
    /// damit kombinierte Modi (.ageAndIntolerance) hier aufgelöst sind und der
    /// Render-Switch nicht über unerreichbare Fälle stolpert.
    enum ResolvedCenter { case initials, intolerance, age }

    /// Effektiver Kreis-Inhalt: gewählter Modus, aber Fallback auf Initialen
    /// wenn das Merkmal beim Gast fehlt (keine Allergie / Erwachsener).
    private var effectiveCenter: ResolvedCenter {
        guard occupant != nil else { return .initials }
        let isYoung = occupant?.ageCategory.isMarkedAge ?? false
        switch chipContent {
        case .intolerance: return intoleranceNumbers.isEmpty ? .initials : .intolerance
        case .age: return isYoung ? .age : .initials
        case .initials: return .initials
        case .ageAndIntolerance:
            if !intoleranceNumbers.isEmpty { return .intolerance }
            return isYoung ? .age : .initials
        }
    }

    @ViewBuilder
    private var centerContentView: some View {
        if showCoupleMarker, isCouple {
            // Emoji nach Geschlecht: 👰 Braut, 🤵 Bräutigam, sonst 👑 (Fallback).
            Text(coupleGlyph)
                .font(.system(size: 12))
                .rotationEffect(.degrees(counterRotation))
        } else {
            switch effectiveCenter {
            case .initials:
                if !initials.isEmpty {
                    Text(initials)
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .monospacedDigit()
                        .rotationEffect(.degrees(counterRotation))
                }
            case .intolerance:
                Text(intoleranceInlineText)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Tokens.Colors.error)
                    .rotationEffect(.degrees(counterRotation))
            case .age:
                if let age = occupant?.ageCategory {
                    Image(systemName: age.iconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Tokens.Colors.tagActivity)
                        .rotationEffect(.degrees(counterRotation))
                }
            }
        }
    }

    @ViewBuilder
    private func ageChipBadge(_ age: AgeCategory) -> some View {
        ZStack {
            Circle().fill(Tokens.Colors.tagActivity)
            Image(systemName: age.iconName)
                .font(.system(size: 5.5, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(Circle().strokeBorder(.white, lineWidth: 0.75))
        .frame(width: 10, height: 10)
        .rotationEffect(.degrees(counterRotation))
    }

    @ViewBuilder
    private var intoleranceChipBadge: some View {
        // Pille statt Kreis, damit "1,2" reinpasst ohne den Chip optisch zu
        // erschlagen. Schriftgröße bleibt klein aber lesbar bei 100% Zoom.
        let text = intoleranceChipText
        let isWide = text.count > 1
        Text(text)
            .font(.system(size: 7, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, isWide ? 3 : 0)
            .frame(minWidth: 10, minHeight: 10)
            .background(Capsule().fill(Tokens.Colors.error))
            .overlay(Capsule().strokeBorder(.white, lineWidth: 0.75))
            .fixedSize()
            .rotationEffect(.degrees(counterRotation))
    }

    var body: some View {
        ZStack {
            Circle().fill(fillColor)
            Circle().strokeBorder(strokeColor, lineWidth: occupant == nil ? 1 : 1.5)
            if isDisabled {
                Path { p in
                    p.move(to: CGPoint(x: 4, y: 18))
                    p.addLine(to: CGPoint(x: 18, y: 4))
                }
                .stroke(Tokens.Colors.ink3, lineWidth: 1.5)
            }
            centerContentView
            if infoDisplay.showsIntolerance, hasIntolerance, effectiveCenter != .intolerance {
                intoleranceChipBadge
                    .offset(x: 7, y: -7)
                    .accessibilityHidden(true)
            }
            if showAgeMarker, let age = occupant?.ageCategory, age.isMarkedAge,
               effectiveCenter != .age {
                ageChipBadge(age)
                    .offset(x: -7, y: 7)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: Self.chipSize, height: Self.chipSize)
        .help(tooltip)
        .overlay { nameLabelOverlay }
        .overlay(alignment: .top) {
            if isHovering, let g = occupant {
                Text(g.fullName)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Tokens.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                    .fixedSize()
                    .offset(y: -28)
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .contentShape(Circle())
        .conditionalDraggable(occupant: occupant)
        .dropDestination(for: String.self) { items, _ in
            guard !isDisabled else { return false }
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            return onDrop(id)
        } isTargeted: { targeted in
            isDropTargeted = !isDisabled && targeted
        }
        .contextMenu {
            if occupant != nil {
                Button(role: .destructive) {
                    onClear()
                } label: {
                    Label("Sitzplatz freigeben", systemImage: "person.fill.xmark")
                }
            }
            Button {
                onToggleDisabled()
            } label: {
                Label(isDisabled ? "Sitz aktivieren" : "Sitz sperren",
                      systemImage: isDisabled ? "checkmark.circle" : "xmark.circle")
            }
        }
    }

    /// Lokaler Ausrichtungs-Vektor der Anzeige-Seite (Tisch-Koordinaten, noch
    /// nicht rotiert). `.auto` zeigt nach oben wie `.top`.
    private var sideUnitVector: CGVector {
        resolvedNameSide.localUnitVector
    }

    private var nameOffset: CGSize {
        Self.nameOffset(
            side: resolvedNameSide,
            tableRotationDegrees: -counterRotation,
            nameSize: nameSize,
            chipSize: Self.chipSize,
            gap: Self.nameGap
        )
    }

    /// Offset des Namens-Zentrums vom Chip-Zentrum, in Tisch-LOKALEN Koordinaten
    /// (denn `.offset` wird vor der Tisch-Rotation angewandt). Der Betrag enthält
    /// die halbe Label-Ausdehnung *entlang der Bildschirm-Richtung* — so bleibt
    /// die zum Chip zeigende Label-Kante immer chipRadius + Gap entfernt, egal
    /// ob der Tisch gedreht ist (Namen lesen dank Gegenrotation stets horizontal).
    /// Als `static` ausgelagert, damit die Geometrie ohne View-Rendering testbar ist.
    static func nameOffset(
        side: SeatNameSide,
        tableRotationDegrees: Double,
        nameSize: CGSize,
        chipSize: CGFloat,
        gap: CGFloat
    ) -> CGSize {
        let dir = side.localUnitVector
        // Bildschirm-Richtung = lokale Richtung um die Tisch-Rotation gedreht.
        // Math explizit in Double, dann CGFloat — sonst ist cos/sin bei
        // CGFloat×Double-Mischung mehrdeutig (CI-Toolchain).
        let r = tableRotationDegrees * .pi / 180
        let c = cos(r), s = sin(r)
        let screenDX = CGFloat(Double(dir.dx) * c - Double(dir.dy) * s)
        let screenDY = CGFloat(Double(dir.dx) * s + Double(dir.dy) * c)
        // Label liest horizontal → Ausdehnung entlang Bildschirm-X = Breite,
        // entlang Bildschirm-Y = Höhe. Projektion auf die Bildschirm-Richtung.
        let halfExtent = abs(screenDX) * nameSize.width / 2
                       + abs(screenDY) * nameSize.height / 2
        let distance = chipSize / 2 + gap + halfExtent
        return CGSize(width: dir.dx * distance, height: dir.dy * distance)
    }

    @ViewBuilder
    private var nameLabelOverlay: some View {
        if showName, let g = occupant {
            let raw = displayName ?? g.fullName
            HStack(spacing: 3) {
                if indicatorsLeadName {
                    indicatorCluster
                }
                Text(raw)
                    .font(.system(size: nameFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                    .lineLimit(1)
                if !indicatorsLeadName {
                    indicatorCluster
                }
            }
            .fixedSize()
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: NameSizeKey.self, value: geo.size)
                }
            )
            .onPreferenceChange(NameSizeKey.self) { nameSize = $0 }
            .rotationEffect(.degrees(counterRotation))
            .offset(nameOffset)
            .allowsHitTesting(false)
        }
    }

    /// Bildschirm-Richtung des Namens relativ zum Chip (lokale Seite um die
    /// Tisch-Rotation gedreht). Bestimmt die Indikator-Reihenfolge.
    private var screenDirection: CGVector {
        let dir = sideUnitVector
        let r = -counterRotation * .pi / 180
        let c = cos(r), s = sin(r)
        return CGVector(
            dx: CGFloat(Double(dir.dx) * c - Double(dir.dy) * s),
            dy: CGFloat(Double(dir.dx) * s + Double(dir.dy) * c)
        )
    }

    /// Diät-/Allergen-Indikatoren sollen sich vom Chip *weg* anordnen, damit
    /// sie nicht in den Spalt zwischen Chip und Name geraten. Liegt der Name
    /// links vom Chip (Bildschirm-X negativ) → Indikatoren VOR dem Namen.
    private var indicatorsLeadName: Bool { screenDirection.dx < -0.5 }

    @ViewBuilder
    private var indicatorCluster: some View {
        // Nicht doppelt: wenn die Nummer schon im Kreis steht, kein Inline-Tag.
        if infoDisplay.showsIntolerance, hasIntolerance, effectiveCenter != .intolerance {
            Text(intoleranceInlineText)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Tokens.Colors.error)
        }
    }
}

/// Misst die natürliche (un-rotierte) Größe des Namens-Labels, damit der Offset
/// die Label-Kante exakt am Chip-Rand + Gap platzieren kann.
private struct NameSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private extension View {
    /// Macht den Sitz nur draggable wenn besetzt — leerer Sitz verschluckt sonst
    /// den Drag-Start und wirkt wie ein nicht-funktionaler Button.
    @ViewBuilder
    func conditionalDraggable(occupant: Guest?) -> some View {
        if let g = occupant {
            self.draggable(g.id.uuidString)
        } else {
            self
        }
    }
}
#endif
