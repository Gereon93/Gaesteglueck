#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S7 — KI-Vorschlag-Sheet (siehe design_handoff_gaesteglueck → S7).
/// Modal: Header mit Akzent-Gradient + WavePattern + Sparkles + Display-
/// Headline, Body als Liste pro Tisch (Tisch-Bubble + Titel + Begründung),
/// Footer mit Verwerfen / Anpassen / Übernehmen.
struct AISuggestionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tables: [GuestTable]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]

    @State private var state: PlanState = .loading
    @State private var hasStarted = false

    enum PlanState {
        case loading
        case ready(LLMSeatingPlanner.ProposedAssignment)
        case error(String)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                switch state {
                case .loading:
                    loadingState
                case .ready(let assignment):
                    planList(assignment: assignment)
                case .error(let message):
                    errorState(message: message)
                }
            }
            .frame(maxHeight: .infinity)

            footer
        }
        .frame(width: 560, height: 600)
        .background(Tokens.Colors.surface)
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await fetchSuggestion()
        }
    }

    // MARK: - Header

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Tokens.Colors.accentTint, Color(hex: "#f7eddb")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            WavePattern(opacity: 0.4)

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Tokens.Colors.accent, Color(hex: "#b88a5c")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(headlineText)
                        .font(Tokens.Typography.displayS)
                        .foregroundStyle(Tokens.Colors.ink)
                    Text(metaText)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(height: 100)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.accentSoft).frame(height: 1)
        }
    }

    private var headlineText: String {
        switch state {
        case .loading: "Ich überlege gerade…"
        case .ready: "Hier ist mein Vorschlag."
        case .error: "Das hat nicht funktioniert."
        }
    }

    private var metaText: String {
        switch state {
        case .loading:
            return "Gleich da — \(guests.count) Gäste auf \(tables.count) Tische werden geplant."
        case .ready(let a):
            let placed = a.assignments.count
            let warn = a.warnings.isEmpty ? "" : " · \(a.warnings.count) Hinweise"
            return "\(placed) Gäste verteilt\(warn)."
        case .error(let m):
            return m
        }
    }

    // MARK: - Loading / Error / Plan list

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
            Text("Ich plane einen ersten Sitzvorschlag — kann einen Moment dauern.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Tokens.Colors.warn)
            Text(message)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Erneut versuchen") {
                state = .loading
                Task { await fetchSuggestion() }
            }
            .warmButton(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func planList(assignment: LLMSeatingPlanner.ProposedAssignment) -> some View {
        let grouped = Dictionary(grouping: assignment.assignments, by: { $0.value })
        // Sort tables by their existing order
        let orderedTables = tables.sorted { $0.name < $1.name }
        return VStack(spacing: 0) {
            ForEach(Array(orderedTables.enumerated()), id: \.element.id) { index, table in
                if let tableAssignments = grouped[table.id], !tableAssignments.isEmpty {
                    let guestNames = tableAssignments.compactMap { entry in
                        guests.first(where: { $0.id == entry.key })?.fullName
                    }
                    ReasoningRow(
                        label: tableLabel(for: table),
                        title: tableTitle(for: table, count: tableAssignments.count),
                        message: assignment.rationale[table.id] ?? guestNames.prefix(4).joined(separator: ", "),
                        highlight: index == 0
                    )
                }
            }

            if !assignment.warnings.isEmpty {
                Divider().background(Tokens.Colors.line)
                VStack(alignment: .leading, spacing: 6) {
                    Text("HINWEISE")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .tracking(0.5)
                    ForEach(Array(assignment.warnings.enumerated()), id: \.offset) { _, warn in
                        Text("• \(warn)")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
        }
        .padding(.vertical, 8)
    }

    private func tableLabel(for table: GuestTable) -> String {
        let name = table.name
        if let prefix = name.split(separator: " ").first, prefix.count <= 3 {
            return String(prefix)
        }
        return String(name.prefix(3))
    }

    private func tableTitle(for table: GuestTable, count: Int) -> String {
        "\(table.name) — \(count) \(count == 1 ? "Person" : "Personen")"
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                    Text("Verwerfen")
                }
            }
            .warmButton(.ghost)
            Spacer()
            Button {
                state = .loading
                Task { await fetchSuggestion() }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("Anpassen")
                }
            }
            .warmButton(.secondary)
            .disabled(loadingOrError)
            Button {
                applyPlan()
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Übernehmen")
                }
            }
            .warmButton(.primary)
            .disabled(loadingOrError)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Tokens.Colors.bg2)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    private var loadingOrError: Bool {
        switch state {
        case .ready: return false
        default: return true
        }
    }

    // MARK: - Logic

    @MainActor
    private func fetchSuggestion() async {
        let context = LLMSeatingPlanner.PlannerContext(
            guests: guests,
            tables: tables,
            tags: tags,
            constraints: constraints
        )
        let client = LMStudioClient(endpoint: lmStudioEndpoint)
        do {
            let proposal = try await LLMSeatingPlanner.requestPlan(client: client, context: context)
            state = .ready(proposal)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func applyPlan() {
        guard case .ready(let assignment) = state else { return }
        for (guestID, tableID) in assignment.assignments {
            guard let guest = guests.first(where: { $0.id == guestID }),
                  let table = tables.first(where: { $0.id == tableID }) else { continue }
            if !guest.isPinned {
                guest.table = table
            }
        }
    }
}

private struct ReasoningRow: View {
    let label: String
    let title: String
    let message: String
    let highlight: Bool

    var body: some View {
        rowBody
    }

    private var rowBody: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Tokens.Colors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Tokens.Colors.line, lineWidth: 1)
                    }
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text(message)
                    .font(.system(size: 12.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink2)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(highlight ? Tokens.Colors.accentTint : .clear)
        .overlay(alignment: .leading) {
            if highlight {
                Rectangle()
                    .fill(Tokens.Colors.accent)
                    .frame(width: 3)
            }
        }
    }
}
#endif
