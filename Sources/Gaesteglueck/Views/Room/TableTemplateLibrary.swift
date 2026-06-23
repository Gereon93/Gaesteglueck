#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Linke Spalte — Tisch-Vorlagen-Bibliothek + eigener Tisch.
struct TableTemplateLibrary: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BIBLIOTHEK")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                    Text("Tisch-Vorlagen")
                        .font(Tokens.Typography.displayXS)
                        .foregroundStyle(Tokens.Colors.ink)
                    Text("Klick zum Hinzufügen oder zieh in den Saal rechts.")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineSpacing(2)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)

                VStack(spacing: 8) {
                    ForEach(TableTemplate.all) { template in
                        templateRow(template)
                    }
                }
                .padding(.horizontal, 12)

                Rectangle()
                    .fill(Tokens.Colors.line)
                    .frame(height: 1)
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                CustomTableSection()
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    private func templateRow(_ template: TableTemplate) -> some View {
        Button {
            RoomTableActions.addTable(from: template, tables: tables, in: modelContext)
        } label: {
            HStack(spacing: 12) {
                MiniTableShape(shape: template.shape)
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                        .lineLimit(1)
                    Text("\(template.size) · \(template.hint)")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("+")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Tokens.Colors.accentTint)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .cardShadow()
        }
        .buttonStyle(.plain)
    }
}
#endif
