#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct SaalKonfiguratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var existingTables: [GuestTable]
    @Query private var events: [Event]

    @State private var inventory = SaalInventar()
    @State private var proposal: SaalProposal?
    @State private var isGenerating = false
    @State private var generateTask: Task<Void, Never>? = nil
    @State private var isAssigning = false
    @State private var errorMessage: String?
    @State private var alsoAssignGuests = true
    @State private var assignmentSummary: String?

    private var seatingNeed: Int {
        guests.filter { $0.ageCategory.needsSeat }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Tokens.Colors.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let proposal {
                        SaalReviewStageView(proposal: proposal) {
                            self.proposal = nil
                        }
                    } else {
                        SaalInputStageView(
                            inventory: $inventory,
                            errorMessage: $errorMessage,
                            seatingNeed: seatingNeed,
                            isGenerating: isGenerating,
                            onGenerate: { generateTask = Task { await generate() } }
                        )
                    }
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if proposal != nil {
                Divider().background(Tokens.Colors.line)
                applyBar
            }
        }
        .frame(minWidth: 760, minHeight: 640)
        .background(Tokens.Colors.bg)
        .sheet(isPresented: $isGenerating) {
            AIRunIndicator(
                title: "KI plant den Saal…",
                detail: "Das kann je nach Modell etwas dauern.",
                onCancel: { generateTask?.cancel() }
            )
            .interactiveDismissDisabled(true)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Saal-Konfigurator")
                    .font(Tokens.Typography.display(size: 22))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Sag was ihr buchen könnt — die KI schlägt eine Tisch-Konfiguration für eure \(seatingNeed) Sitzplätze vor.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer()
            Button("Schließen") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var applyBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = assignmentSummary {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Tokens.Colors.sage)
                    Text(summary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                }
            }
            HStack {
                if let proposal {
                    Text("\(proposal.tables.count) Tische anlegen — bestehende bleiben erhalten.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("Gäste auch direkt verteilen", isOn: $alsoAssignGuests)
                    .toggleStyle(.switch)
                    .font(.system(size: 11.5, design: .rounded))
                    .disabled(isAssigning)
                Button {
                    Task { await applyAndMaybeAssign() }
                } label: {
                    HStack(spacing: 6) {
                        if isAssigning { ProgressView().controlSize(.small) }
                        Text(applyButtonTitle)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Tokens.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .disabled(isAssigning)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Tokens.Colors.surface)
    }

    private var applyButtonTitle: String {
        if isAssigning { return "Verteile Gäste…" }
        return alsoAssignGuests ? "Tische anlegen + Gäste verteilen" : "Nur Tische anlegen"
    }

    @MainActor
    private func generate() async {
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        let client = LLMClientFactory.makeClient(for: .seating)
        if let lm = client.lmStudioClient {
            do {
                _ = try await lm.checkConnection()
            } catch {
                errorMessage = "LM Studio nicht erreichbar — bitte starten und Modell laden."
                return
            }
        }

        let clusterContext = GroupAnalyzer.buildLLMContext(
            guests: guests,
            tags: tags,
            constraints: constraints,
            tables: existingTables,
            event: events.first
        )

        let service = SaalKonfigurator(client: client)
        do {
            let result = try await service.propose(
                inventory: inventory,
                guestCount: guests.count,
                seatingNeed: seatingNeed,
                clusterContext: clusterContext
            )
            if result.tables.isEmpty {
                errorMessage = "Die KI hat keinen verwertbaren Vorschlag geliefert. Empfehlung: gemma-3-12b in LM Studio aktivieren."
            } else {
                proposal = result
            }
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func applyAndMaybeAssign() async {
        guard let proposal else { return }
        let createdTables = SaalTablePlacement.insertProposedTables(
            proposal.tables,
            existingCount: existingTables.count,
            into: modelContext
        )
        modelContext.saveOrLog()

        guard alsoAssignGuests else {
            dismiss()
            return
        }

        isAssigning = true
        defer { isAssigning = false }

        let plannerTables = SaalTablePlacement.mergedTables(existing: existingTables, created: createdTables)
        let client = LLMClientFactory.makeClient(for: .seating)
        let context = LLMSeatingPlanner.PlannerContext(
            guests: guests,
            tables: plannerTables,
            tags: tags,
            constraints: constraints
        )

        do {
            let plan = try await LLMSeatingPlanner.requestPlan(client: client, context: context)
            SaalTablePlacement.applyAssignments(plan.assignments, in: plannerTables, guests: guests)
            modelContext.saveOrLog()
            assignmentSummary = "Tische angelegt. \(plan.assignments.count) Gäste verteilt. Du kannst im Sitzplan nachjustieren."
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = "Tische sind angelegt, aber die Gäste-Verteilung ist fehlgeschlagen: \(error.localizedDescription). Du kannst die Verteilung im KI-Assistenten neu starten."
        }
    }
}
#endif
