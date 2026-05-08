#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S5 — Beziehungs-Wizard (siehe design_handoff_gaesteglueck → S5).
/// Top-Bar mit Step-Indikator (Segment-Pills) + Zurück/Überspringen,
/// zentrierte Display-Headline ("Familie X — gehört das zu A oder B?"),
/// drei große SideOption-Karten + Liste der erkannten Personen, dann
/// Bottom-Bar mit Weiter. Pro Step ein registrationGroup.
struct EnrichmentWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query private var events: [Event]
    private var currentEvent: Event? { events.first }

    @State private var currentGroupIndex = 0

    private var registrationGroups: [[Guest]] {
        let withGroup = guests.filter { $0.registrationGroup != nil }
        let groupedDict = Dictionary(grouping: withGroup, by: { $0.registrationGroup! })
        let solo = guests.filter { $0.registrationGroup == nil }
        var groups = Array(groupedDict.values).sorted { ($0.first?.fullName ?? "") < ($1.first?.fullName ?? "") }
        groups += solo.map { [$0] }
        return groups
    }

    private var currentGroup: [Guest]? {
        registrationGroups[safe: currentGroupIndex]
    }

    private var totalSteps: Int { max(registrationGroups.count, 1) }

    var body: some View {
        ZStack {
            // Hintergrund: Akzent-Wash oben, Parchment unten
            LinearGradient(
                colors: [Tokens.Colors.accentTint, Tokens.Colors.bg, Tokens.Colors.bg],
                startPoint: .top,
                endPoint: .bottom
            )
            WavePattern(opacity: 0.4)
                .frame(height: 320)
                .frame(maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    contentArea
                        .padding(.horizontal, 60)
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                }
                bottomBar
            }
        }
        .frame(minWidth: 760, minHeight: 600)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                if currentGroupIndex > 0 { currentGroupIndex -= 1 }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left")
                    Text("Zurück")
                }
            }
            .warmButton(.ghost)
            .disabled(currentGroupIndex == 0)
            .opacity(currentGroupIndex == 0 ? 0.4 : 1)

            Spacer()

            VStack(spacing: 6) {
                // Im Done-State ist currentGroupIndex == totalSteps — wir
                // clampen für die Anzeige damit nicht "Schritt N+1 von N" steht.
                let displayStep = min(currentGroupIndex + 1, max(totalSteps, 1))
                Text("Schritt \(displayStep) von \(totalSteps)".uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.6)
                stepIndicator
            }

            Spacer()

            Button("Überspringen") {
                advance()
            }
            .warmButton(.ghost)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { i in
                Capsule()
                    .fill(i <= currentGroupIndex ? Tokens.Colors.accent : Tokens.Colors.bg3)
                    .frame(width: i == currentGroupIndex ? 28 : 20, height: 4)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        VStack(spacing: 24) {
            if let group = currentGroup {
                groupHeadline(group: group)
                sideOptionRow(group: group)
                detectedGuestsCard(group: group)
            } else {
                doneState
            }
        }
        .frame(maxWidth: 720)
    }

    private func groupHeadline(group: [Guest]) -> some View {
        let familyName = mostCommonLastName(group: group)
        return VStack(spacing: 14) {
            VStack(spacing: 0) {
                Text("Familie \(familyName) — gehört das zu")
                    .font(Tokens.Typography.display(size: 32))
                    .foregroundStyle(Tokens.Colors.ink)
                    .multilineTextAlignment(.center)
                HStack(spacing: 0) {
                    Text(PartnerAssignment.partner1.displayName(for: currentEvent))
                        .font(Tokens.Typography.display(size: 32, italic: true))
                        .foregroundStyle(Tokens.Colors.accent)
                    Text(" oder ")
                        .font(Tokens.Typography.display(size: 32))
                        .foregroundStyle(Tokens.Colors.ink)
                    Text(PartnerAssignment.partner2.displayName(for: currentEvent))
                        .font(Tokens.Typography.display(size: 32, italic: true))
                        .foregroundStyle(Tokens.Colors.accent)
                    Text("?")
                        .font(Tokens.Typography.display(size: 32))
                        .foregroundStyle(Tokens.Colors.ink)
                }
            }
            Text("Wir haben \(group.count) \(group.count == 1 ? "Person" : "Personen") erkannt. Welche Seite passt?")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .lineSpacing(2)
        }
    }

    private func sideOptionRow(group: [Guest]) -> some View {
        let activeAssignment = group.first?.partnerAssignment
        return HStack(spacing: 14) {
            sideOption(
                label: PartnerAssignment.partner1.displayName(for: currentEvent),
                count: counts(for: .partner1, in: group),
                active: activeAssignment == .partner1,
                tone: .accent
            ) { setAssignment(.partner1, group: group) }

            sideOption(
                label: PartnerAssignment.partner2.displayName(for: currentEvent),
                count: counts(for: .partner2, in: group),
                active: activeAssignment == .partner2,
                tone: .accent
            ) { setAssignment(.partner2, group: group) }

            sideOption(
                label: "Gemeinsam",
                count: counts(for: .both, in: group),
                active: activeAssignment == .both,
                tone: .sage
            ) { setAssignment(.both, group: group) }
        }
    }

    enum SideTone { case accent, sage }

    private func sideOption(label: String, count: Int, active: Bool, tone: SideTone, action: @escaping () -> Void) -> some View {
        let bg: Color = active ? (tone == .accent ? Tokens.Colors.accentTint : Tokens.Colors.sageTint) : Tokens.Colors.surface
        let border: Color = active ? (tone == .accent ? Tokens.Colors.accent : Tokens.Colors.sage) : Tokens.Colors.line2

        return Button(action: action) {
            VStack(spacing: 6) {
                Text(label)
                    .font(Tokens.Typography.display(size: 20))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("\(count) \(count == 1 ? "Person" : "Personen")")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 18)
            .background(bg)
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(
                color: active ? Tokens.Colors.accent.opacity(0.12) : .clear,
                radius: 16,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
    }

    private func detectedGuestsCard(group: [Guest]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(group.count) \(group.count == 1 ? "Person" : "Personen") in dieser Anmeldung")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            Divider().background(Tokens.Colors.line)

            VStack(spacing: 0) {
                ForEach(group) { guest in
                    HStack(spacing: 12) {
                        Avatar(name: guest.fullName, size: 32, tag: .family)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(guest.fullName)
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink)
                            Text(guest.dietaryChoice + (guest.hasIntolerances ? " · Allergie" : ""))
                                .font(.system(size: 11.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                        Spacer()
                        Text(guest.partnerAssignment.displayName(for: currentEvent))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Tokens.Colors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Tokens.Colors.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    if guest.id != group.last?.id {
                        Divider().background(Tokens.Colors.line)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .background(Tokens.Colors.surface)
        .overlay {
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
    }

    private var doneState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Tokens.Colors.accent)
            Text("Alle Anmeldungen geprüft")
                .font(Tokens.Typography.display(size: 26))
                .foregroundStyle(Tokens.Colors.ink)
            Text("Du kannst die Beziehungen jederzeit in der Gästeliste nachjustieren.")
                .font(.system(size: 14, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(.vertical, 60)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            Button("Schließen") { dismiss() }
                .warmButton(.ghost)
            Spacer()
            if currentGroupIndex < registrationGroups.count {
                Button {
                    advance()
                } label: {
                    HStack(spacing: 6) {
                        Text("Weiter")
                        Image(systemName: "arrow.right")
                    }
                }
                .warmButton(.primary, size: .lg)
            } else {
                Button("Fertig") { dismiss() }
                    .warmButton(.primary, size: .lg)
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Tokens.Colors.bg)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    // MARK: - Helpers

    private func advance() {
        if currentGroupIndex < registrationGroups.count {
            currentGroupIndex += 1
        } else {
            dismiss()
        }
    }

    private func setAssignment(_ assignment: PartnerAssignment, group: [Guest]) {
        for g in group {
            g.partnerAssignment = assignment
        }
    }

    private func counts(for assignment: PartnerAssignment, in group: [Guest]) -> Int {
        group.filter { $0.partnerAssignment == assignment }.count
    }

    private func mostCommonLastName(group: [Guest]) -> String {
        let names = group.map { $0.lastName }.filter { !$0.isEmpty }
        if let mostCommon = Dictionary(grouping: names, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key {
            return mostCommon
        }
        return group.first?.firstName ?? "?"
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
#endif
