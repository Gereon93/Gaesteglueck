#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]

    private var confirmedGuests: Int {
        guests.filter { $0.rsvpStatus == .confirmed }.count
    }

    private var assignedGuests: Int {
        guests.filter { $0.table != nil }.count
    }

    private var totalCapacity: Int {
        tables.reduce(0) { $0 + $1.capacity }
    }

    private var happinessScore: Double {
        HappinessScorer.scoreAllTables(tables, tags: tags, constraints: constraints)
    }

    private var violations: [Violation] {
        HappinessScorer.findViolations(tables: tables, constraints: constraints)
    }

    var body: some View {
        List {
            Section("Gäste") {
                StatRow(label: "Gesamt", value: "\(guests.count)", icon: "person.3")
                StatRow(label: "Zugesagt", value: "\(confirmedGuests)", icon: "checkmark.circle")
                StatRow(label: "Partner 1", value: "\(guests.filter { $0.partnerAssignment == .partner1 }.count)", icon: "circle.fill", color: .pink)
                StatRow(label: "Partner 2", value: "\(guests.filter { $0.partnerAssignment == .partner2 }.count)", icon: "circle.fill", color: .blue)
            }
            Section("Tische") {
                StatRow(label: "Anzahl", value: "\(tables.count)", icon: "tablecells")
                StatRow(label: "Kapazität", value: "\(totalCapacity) Plätze", icon: "chair")
                StatRow(label: "Zugewiesen", value: "\(assignedGuests)/\(guests.count)", icon: "person.badge.checkmark")
                StatRow(label: "Freie Plätze", value: "\(totalCapacity - assignedGuests)", icon: "plus.square.dashed")
            }
            Section("Sitzplan-Qualität") {
                StatRow(label: "Happiness Score", value: "\(Int(happinessScore))", icon: "face.smiling", color: happinessScore >= 0 ? .green : .red)
                StatRow(label: "Tags", value: "\(tags.count)", icon: "tag")
                StatRow(label: "Constraints", value: "\(constraints.count)", icon: "link")
                StatRow(label: "Warnungen", value: "\(violations.count)", icon: "exclamationmark.triangle", color: violations.isEmpty ? .green : .red)
            }
        }
        .navigationTitle("Übersicht")
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundStyle(color)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}
#endif
