#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query private var events: [Event]
    @Query private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var tags: [Tag]

    private var event: Event? { events.first }

    private var adultCount: Int { guests.filter { $0.ageCategory == .adult }.count }
    private var childCount: Int { guests.filter { $0.ageCategory != .adult }.count }
    private var intoleranceCount: Int { guests.filter { $0.hasIntolerances }.count }

    private var dietaryBreakdown: [(String, Int)] {
        let grouped = Dictionary(grouping: guests, by: \.dietaryChoice)
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        if let event {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.largeTitle).bold()
                        HStack(spacing: 16) {
                            if let date = event.date {
                                Label(date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                                    .foregroundStyle(.secondary)
                            }
                            if !event.venue.isEmpty {
                                Label(event.venue, systemImage: "mappin")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)
                        Text("\(event.partnerDisplayName1) & \(event.partnerDisplayName2)")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Stats cards
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        StatCard(label: "Erwachsene", value: "\(adultCount)", icon: "person.fill", color: .blue)
                        StatCard(label: "Kinder", value: "\(childCount)", icon: "figure.child", color: .green)
                        StatCard(label: "Gesamt", value: "\(guests.count)", icon: "person.3.fill", color: .purple)
                        StatCard(label: "Tische", value: "\(tables.count)", icon: "tablecells", color: .orange)
                        StatCard(label: "Gruppen", value: "\(tags.count)", icon: "tag.fill", color: .teal)
                    }
                    .padding(.horizontal)

                    if intoleranceCount > 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("\(intoleranceCount) Gäste haben Lebensmittelunverträglichkeiten")
                                .font(.subheadline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.orange.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }

                    // Dietary breakdown
                    if !dietaryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Menüwahl")
                                .font(.headline)
                                .padding(.horizontal)
                            VStack(spacing: 0) {
                                ForEach(dietaryBreakdown, id: \.0) { choice, count in
                                    HStack {
                                        Text(choice)
                                        Spacer()
                                        Text("\(count)")
                                            .foregroundStyle(.secondary)
                                        Text("(\(guests.count > 0 ? Int(Double(count) / Double(guests.count) * 100) : 0)%)")
                                            .foregroundStyle(.tertiary)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    Divider().padding(.leading)
                                }
                            }
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        } else {
            ContentUnavailableView(
                "Kein Event konfiguriert",
                systemImage: "heart.circle",
                description: Text("Gehe zu Einstellungen → Event einrichten, um loszulegen.")
            )
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title).bold()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
#endif
