#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// Eingabe-Phase: Inventar konfigurieren und Vorschlag anstoßen.
struct SaalInputStageView: View {
    @Binding var inventory: SaalInventar
    @Binding var errorMessage: String?
    let seatingNeed: Int
    let isGenerating: Bool
    let onGenerate: () -> Void

    var body: some View {
        capacityHeader
        roundTablesSection
        rectangularTablesSection
        specialTablesSection
        if let errorMessage {
            SaalErrorBanner(message: errorMessage)
        }
        actionRow
        tipBlock
    }

    private var capacityHeader: some View {
        HStack(spacing: 16) {
            SaalStatBlock(label: "Gäste mit Sitzplatz", value: "\(seatingNeed)")
            SaalStatBlock(label: "Max. Kapazität laut Inventar", value: "\(inventory.maxTotalCapacity)")
            SaalStatBlock(
                label: capacitySurplusLabel,
                value: capacitySurplusValue,
                accent: capacitySurplusAccent
            )
            Spacer(minLength: 0)
        }
    }

    private var capacitySurplusLabel: String {
        inventory.maxTotalCapacity >= seatingNeed ? "Reserve" : "Es fehlen Plätze"
    }

    private var capacitySurplusValue: String {
        let diff = inventory.maxTotalCapacity - seatingNeed
        return diff >= 0 ? "+\(diff)" : "\(diff)"
    }

    private var capacitySurplusAccent: Color {
        inventory.maxTotalCapacity >= seatingNeed ? Tokens.Colors.sage : Tokens.Colors.warn
    }

    private var roundTablesSection: some View {
        SaalConfigRow(
            title: "Runde Tische",
            subtitle: "\(inventory.roundCapacityEach) Plätze pro Tisch · gesamt bis \(inventory.roundMaxCount * inventory.roundCapacityEach)"
        ) {
            HStack(spacing: 10) {
                SaalStepperField(label: "Anzahl", value: $inventory.roundMaxCount, range: 0...30)
                SaalDoubleField(label: "Durchmesser (cm)", value: $inventory.roundDiameterCM)
                Spacer()
            }
        }
    }

    private var rectangularTablesSection: some View {
        SaalConfigRow(
            title: "Rechteckige Tafeln",
            subtitle: "\(inventory.rectCapacityEach) Plätze pro Tafel · gesamt bis \(inventory.rectangularMaxCount * inventory.rectCapacityEach)"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    SaalStepperField(label: "Anzahl", value: $inventory.rectangularMaxCount, range: 0...20)
                    SaalDoubleField(label: "Breite (cm)", value: $inventory.rectangularWidthCM)
                    SaalDoubleField(label: "Tiefe (cm)", value: $inventory.rectangularDepthCM)
                    Spacer()
                }
                SaalStepperField(label: "Max. Tische pro Tafel", value: $inventory.rectangularMaxTafelLength, range: 1...8)
            }
        }
    }

    private var specialTablesSection: some View {
        SaalConfigRow(
            title: "Spezialtische",
            subtitle: "Brauttafel und Kindertisch werden falls aktiviert garantiert vorgeschlagen."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Brauttafel separat", isOn: $inventory.withSeparateBridalTable)
                        .toggleStyle(.switch)
                    if inventory.withSeparateBridalTable {
                        SaalDoubleField(label: "Breite (cm)", value: $inventory.bridalTableWidthCM)
                        SaalDoubleField(label: "Tiefe (cm)", value: $inventory.bridalTableDepthCM)
                        Text("\(inventory.bridalCapacity) Plätze")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    Spacer()
                }
                HStack {
                    Toggle("Kindertisch separat", isOn: $inventory.withChildTable)
                        .toggleStyle(.switch)
                    if inventory.withChildTable {
                        SaalDoubleField(label: "Kantenlänge (cm)", value: $inventory.childTableWidthCM)
                        Text("\(inventory.childCapacity) Plätze")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    Spacer()
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Spacer()
            Button {
                onGenerate()
            } label: {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "KI plant…" : "Vorschlag generieren")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Tokens.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isGenerating || inventory.maxTotalCapacity < 1)
        }
    }

    private var tipBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("So denkt die KI")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
            Text("Sie nutzt eure Familienrollen, registrierten Anmeldungs-Gruppen und Tags. Großfamilien und Tafeln werden bevorzugt zusammengehalten, Freundeskreise auf passende Rundtische verteilt. Die Empfehlung kommt mit Begründung pro Tisch — du kannst sie übernehmen oder verwerfen und neu rechnen lassen.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
#endif
