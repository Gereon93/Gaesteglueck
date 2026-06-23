#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct SeatingRulesEditor: View {
    @Bindable var event: Event

    var body: some View {
        VStack(spacing: 6) {
            ruleStepper(label: "Sitz-Abstand", valueCm: bindingFor(\.seatWidthCm), lowerBound: 40, upperBound: 120, step: 5, suffix: "cm/Pers.")
            ruleStepper(label: "Mindestabstand Tische", valueCm: bindingFor(\.tableMinDistanceCm), lowerBound: 40, upperBound: 200, step: 10, suffix: "cm")
            ruleStepper(label: "Gangbreite", valueCm: bindingFor(\.aisleWidthCm), lowerBound: 60, upperBound: 300, step: 10, suffix: "cm")
            if !event.seatingRules.isValid {
                Text("Gangbreite muss ≥ Mindestabstand sein.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Tokens.Colors.warn)
            }
        }
    }

    private func bindingFor(_ keyPath: WritableKeyPath<SeatingRules, Double>) -> Binding<Double> {
        Binding(
            get: { event.seatingRules[keyPath: keyPath] },
            set: { newValue in
                var rules = event.seatingRules
                rules[keyPath: keyPath] = newValue
                event.seatingRules = rules
                GuestTable.activeRules = rules
            }
        )
    }

    @ViewBuilder
    private func ruleStepper(
        label: String,
        valueCm: Binding<Double>,
        lowerBound: Double,
        upperBound: Double,
        step: Double,
        suffix: String
    ) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
            Spacer()
            Text("\(Int(valueCm.wrappedValue)) \(suffix)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink)
                .monospacedDigit()
            Stepper("", value: valueCm, in: lowerBound...upperBound, step: step)
                .labelsHidden()
        }
    }
}
#endif
