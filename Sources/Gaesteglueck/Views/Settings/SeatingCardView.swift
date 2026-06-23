#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Sitzplan-Regeln — wer sitzt am Brautpaartisch.
struct SeatingCardView: View {
    @AppStorage("bridalIncludeTrauzeugen") private var bridalIncludeTrauzeugen: Bool = true
    @AppStorage("bridalIncludeEltern") private var bridalIncludeEltern: Bool = false
    @AppStorage("bridalIncludeGeschwister") private var bridalIncludeGeschwister: Bool = false
    @AppStorage("bridalManualMode") private var bridalManualMode: Bool = false

    var body: some View {
        SettingsCard(
            title: "Sitzplan-Regeln",
            subtitle: "Wer sitzt am Brautpaartisch? Wird vom Auto-Sitzplaner als harte Regel respektiert."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Trauzeugen / Brautjungfern", isOn: Binding(
                    get: { bridalIncludeTrauzeugen },
                    set: { bridalIncludeTrauzeugen = $0 }
                ))
                .disabled(bridalManualMode)

                Toggle("Eltern beider Seiten", isOn: Binding(
                    get: { bridalIncludeEltern },
                    set: { bridalIncludeEltern = $0 }
                ))
                .disabled(bridalManualMode)

                Toggle("Geschwister beider Seiten", isOn: Binding(
                    get: { bridalIncludeGeschwister },
                    set: { bridalIncludeGeschwister = $0 }
                ))
                .disabled(bridalManualMode)

                Divider()

                Toggle("Manuell — keine Auto-Regel", isOn: Binding(
                    get: { bridalManualMode },
                    set: { bridalManualMode = $0 }
                ))

                Text(bridalPolicyExplanation)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var bridalPolicyExplanation: String {
        if bridalManualMode {
            return "Keine Auto-Regel — du pinnst selbst wer am Brauttisch sitzt."
        }
        var groups: [String] = []
        if bridalIncludeTrauzeugen { groups.append("Trauzeugen / Brautjungfern") }
        if bridalIncludeEltern { groups.append("Eltern") }
        if bridalIncludeGeschwister { groups.append("Geschwister") }
        if groups.isEmpty {
            return "Nur das Brautpaar selbst sitzt am Brauttisch. Alle anderen verteilen sich frei."
        }
        let suffix = groups.count >= 2 ? " (Brauttafel sollte genug Plätze haben.)" : ""
        return "\(groups.joined(separator: ", ")) sitzen mit am Brauttisch.\(suffix)"
    }
}
#endif
