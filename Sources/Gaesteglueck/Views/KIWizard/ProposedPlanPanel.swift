#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Proposed plan panel

struct ProposedPlanPanel: View {
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]

    let plan: LLMSeatingPlanner.ProposedAssignment
    @Binding var proposedPlan: LLMSeatingPlanner.ProposedAssignment?
    @Binding var planApplied: Bool
    let onApply: (LLMSeatingPlanner.ProposedAssignment) -> Void

    var body: some View {
        let byTable = Dictionary(grouping: plan.assignments, by: \.value)
            .mapValues { $0.map(\.key) }

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.clipboard")
                Text("KI-Vorschlag")
                    .font(.headline)
                Spacer()
                if planApplied {
                    Label("Übernommen", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }

            if !plan.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(plan.warnings, id: \.self) { w in
                        Label(w, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tables.sorted(by: { $0.name < $1.name })) { table in
                        if let guestIDs = byTable[table.id], !guestIDs.isEmpty {
                            let tableGuests = guestIDs.compactMap { gid in guests.first { $0.id == gid } }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(table.name).font(.caption.bold())
                                    Text("(\(tableGuests.count)/\(table.capacity))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if table.isChildTable {
                                        Image(systemName: "figure.child").font(.caption2)
                                    }
                                }
                                Text(tableGuests.map(\.fullName).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let reason = plan.rationale[table.id] {
                                    Text(reason)
                                        .font(.caption2)
                                        .italic()
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 180)

            HStack {
                Button {
                    onApply(plan)
                } label: {
                    Label(planApplied ? "Erneut anwenden" : "Plan übernehmen", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)

                Button("Verwerfen") {
                    proposedPlan = nil
                    planApplied = false
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.blue.opacity(0.06))
    }
}
#endif
