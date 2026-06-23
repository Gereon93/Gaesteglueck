#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Phase Indicator

struct WizardPhaseIndicator: View {
    let currentPhase: WizardPhase

    var body: some View {
        HStack(spacing: 0) {
            ForEach(WizardPhase.allCases, id: \.rawValue) { phase in
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(phaseColor(phase))
                                .frame(width: 28, height: 28)
                            Image(systemName: phase.icon)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                        Text(phase.title)
                            .font(.caption2)
                            .foregroundStyle(phase == currentPhase ? .primary : .secondary)
                    }

                    if phase.rawValue < WizardPhase.allCases.count - 1 {
                        Rectangle()
                            .fill(phase.rawValue < currentPhase.rawValue ? Color.blue : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                            .padding(.bottom, 18)
                    }
                }
            }
        }
    }

    private func phaseColor(_ phase: WizardPhase) -> Color {
        if phase.rawValue < currentPhase.rawValue { return .green }
        if phase == currentPhase { return .blue }
        return .secondary.opacity(0.4)
    }
}
#endif
