#if canImport(SwiftUI)
import SwiftUI

/// S3 — linke Filter-Rail (200pt): Seite, Tag-Kategorien, Alter, Status.
/// Liest die Zähler aus `GuestListFiltering` und schaltet die im Parent
/// gehaltenen Filter-Bindings. Reine Darstellung, keine eigene Logik.
struct GuestFilterRailView: View {
    let guests: [Guest]
    let tags: [Tag]
    let event: Event?
    let filtering: GuestListFiltering
    @Binding var sideFilter: PartnerAssignment?
    @Binding var tagFilter: TagCategory?
    @Binding var statusFilter: GuestListFiltering.StatusFilter?
    @Binding var ageFilter: AgeCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                filterGroup("Seite") {
                    filterChip(
                        label: "Alle",
                        count: guests.count,
                        active: sideFilter == nil,
                        action: { sideFilter = nil }
                    )
                    ForEach(PartnerAssignment.allCases) { side in
                        filterChip(
                            label: side.displayName(for: event),
                            count: filtering.countForSide(side),
                            active: sideFilter == side,
                            dotColor: side.color,
                            action: { sideFilter = sideFilter == side ? nil : side }
                        )
                    }
                }

                if !tags.isEmpty || guests.contains(where: { $0.familyRole != nil }) {
                    filterGroup("Tag-Kategorien") {
                        ForEach(TagCategory.allCases) { cat in
                            let count = filtering.tagCategoryCount(cat)
                            if count > 0 {
                                filterChip(
                                    label: cat.rawValue,
                                    count: count,
                                    active: tagFilter == cat,
                                    dotColor: tagDotColor(for: cat),
                                    action: { tagFilter = tagFilter == cat ? nil : cat }
                                )
                            }
                        }
                    }
                }

                let ageCounts: [(AgeCategory, Int)] = AgeCategory.allCases.map { age in
                    (age, guests.filter { $0.ageCategory == age }.count)
                }
                if ageCounts.contains(where: { $0.1 > 0 }) {
                    filterGroup("Alter") {
                        ForEach(AgeCategory.allCases) { age in
                            let c = ageCounts.first(where: { $0.0 == age })?.1 ?? 0
                            if c > 0 {
                                filterChip(
                                    label: age.rawValue,
                                    count: c,
                                    active: ageFilter == age,
                                    action: { ageFilter = ageFilter == age ? nil : age }
                                )
                            }
                        }
                    }
                }

                filterGroup("Status") {
                    ForEach(GuestListFiltering.StatusFilter.allCases, id: \.self) { status in
                        let count = filtering.countForStatus(status)
                        filterChip(
                            label: status.rawValue,
                            count: count,
                            active: statusFilter == status,
                            action: { statusFilter = statusFilter == status ? nil : status }
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .background(Tokens.Colors.bg2)
    }

    private func filterGroup<Content: View>(_ label: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 2) {
                content()
            }
        }
    }

    private func filterChip(
        label: String,
        count: Int,
        active: Bool,
        dotColor: Color? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 7, height: 7)
                }
                Text(label)
                    .font(.system(size: 12.5, weight: active ? .medium : .regular, design: .rounded))
                    .foregroundStyle(active ? Tokens.Colors.ink : Tokens.Colors.ink2)
                Spacer(minLength: 0)
                Text("\(count)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(active ? Tokens.Colors.accentSoft : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tagDotColor(for category: TagCategory) -> Color {
        switch category {
        case .family: Tokens.Colors.tagFamily
        case .friendGroup: Tokens.Colors.tagFriends
        case .role: Tokens.Colors.tagRole
        case .activity: Tokens.Colors.tagActivity
        case .work: Tokens.Colors.tagWork
        case .custom: Tokens.Colors.tagCustom
        }
    }
}
#endif
