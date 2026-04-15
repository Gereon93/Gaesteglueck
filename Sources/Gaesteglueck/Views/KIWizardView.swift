#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String // "user" | "assistant"
    let content: String
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.content)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.blue : Color.secondary.opacity(0.15))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Wizard Phase

enum WizardPhase: Int, CaseIterable {
    case clusters
    case harmony
    case childTable
    case tableConfig
    case seatingPlan
    case done

    var title: String {
        switch self {
        case .clusters: "Gruppen"
        case .harmony: "Harmonie"
        case .childTable: "Kindertisch"
        case .tableConfig: "Tischkonfiguration"
        case .seatingPlan: "Sitzplan"
        case .done: "Fertig"
        }
    }

    var icon: String {
        switch self {
        case .clusters: "person.3"
        case .harmony: "heart"
        case .childTable: "figure.child"
        case .tableConfig: "tablecells"
        case .seatingPlan: "list.bullet"
        case .done: "checkmark.circle"
        }
    }

    var prompt: String {
        switch self {
        case .clusters:
            return "Analysiere die Gruppen und Cluster in der Gästeliste. Welche Gruppen gibt es und wer verbindet sie? Gib konkrete Empfehlungen auf Deutsch."
        case .harmony:
            return "Analysiere potenzielle Spannungen oder Konflikte zwischen den Gästen basierend auf den Constraints und Tags. Was sollte bei der Tischzuweisung besonders beachtet werden?"
        case .childTable:
            return "Empfehle eine optimale Strategie für Kinder und Kleinkinder bei der Tischzuteilung. Welche Erwachsenen sollten in der Nähe sitzen?"
        case .tableConfig:
            return "Basierend auf der Gästeanzahl und den Gruppen: Wie viele Tische welcher Art werden empfohlen? Gib konkrete Tischgrößen und Konfigurationen an."
        case .seatingPlan:
            return "Erstelle einen konkreten Sitzplan: Welche Gäste sollen an welchen Tischen sitzen? Begründe die Zuteilungen kurz."
        case .done:
            return ""
        }
    }
}

// MARK: - KI Wizard View

struct KIWizardView: View {
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var tables: [GuestTable]

    @State private var currentPhase: WizardPhase = .clusters
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingChat = false

    // Structured plan from LLMSeatingPlanner.
    @State private var proposedPlan: LLMSeatingPlanner.ProposedAssignment?
    @State private var isRequestingPlan = false
    @State private var planApplied = false

    private var systemContext: String {
        let context = GroupAnalyzer.buildLLMContext(guests: guests, tags: tags, constraints: constraints, tables: tables)
        return "Du bist ein freundlicher Hochzeitsplaner-Assistent. Du hilfst dabei, den perfekten Sitzplan für eine Hochzeit zu erstellen. Hier sind alle relevanten Informationen:\n\n\(context)"
    }

    var body: some View {
        if showingChat {
            KIChatView()
        } else {
            wizardView
        }
    }

    private var wizardView: some View {
        VStack(spacing: 0) {
            // Phase indicator
            phaseIndicator
                .padding()

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }
                        if isLoading {
                            HStack {
                                ProgressView()
                                Text("KI denkt nach…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // Structured plan panel (appears once plan is proposed).
            if let plan = proposedPlan {
                proposedPlanPanel(plan)
                Divider()
            }

            // Bottom bar
            HStack {
                if currentPhase != .done {
                    Button {
                        callLLM()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Nächster Schritt: \(currentPhase.title)")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || guests.isEmpty)
                } else {
                    Button {
                        requestStructuredPlan()
                    } label: {
                        HStack {
                            if isRequestingPlan { ProgressView().controlSize(.small) }
                            Image(systemName: "wand.and.stars")
                            Text(proposedPlan == nil ? "Konkreten Plan anfordern" : "Plan neu anfordern")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRequestingPlan || guests.isEmpty || tables.isEmpty)

                    Button {
                        showingChat = true
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("Freier Chat")
                        }
                    }
                }

                Spacer()

                if currentPhase != .clusters && currentPhase != .done {
                    Button("Zurücksetzen") {
                        currentPhase = .clusters
                        messages = []
                        errorMessage = nil
                        proposedPlan = nil
                        planApplied = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("KI-Assistent")
    }

    // MARK: - Proposed plan panel

    @ViewBuilder
    private func proposedPlanPanel(_ plan: LLMSeatingPlanner.ProposedAssignment) -> some View {
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
                    applyProposedPlan(plan)
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

    // MARK: - Phase Indicator

    private var phaseIndicator: some View {
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

    // MARK: - LLM Call

    private func callLLM() {
        guard currentPhase != .done else { return }
        isLoading = true
        errorMessage = nil

        let userPrompt = currentPhase.prompt
        messages.append(ChatMessage(role: "user", content: userPrompt))

        let allMessages: [LMStudioClient.Message] = [
            LMStudioClient.Message(role: "system", content: systemContext)
        ] + messages.map { LMStudioClient.Message(role: $0.role, content: $0.content) }

        let endpoint = lmStudioEndpoint
        Task {
            let client = LMStudioClient(endpoint: endpoint)
            do {
                let reply = try await client.chat(messages: allMessages)
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: reply))
                    isLoading = false
                    advancePhase()
                }
            } catch {
                await MainActor.run {
                    messages.removeLast() // remove user message since it failed
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }

    private func advancePhase() {
        let next = WizardPhase.allCases.first { $0.rawValue == currentPhase.rawValue + 1 }
        if let next {
            currentPhase = next
        }
    }

    // MARK: - Structured plan request

    private func requestStructuredPlan() {
        guard !guests.isEmpty, !tables.isEmpty else { return }
        isRequestingPlan = true
        errorMessage = nil

        // Build the prompt here on the main actor so we only ship primitives (String + maps)
        // across the actor boundary — avoids sending @Model instances.
        let context = LLMSeatingPlanner.PlannerContext(
            guests: Array(guests),
            tables: Array(tables),
            tags: Array(tags),
            constraints: Array(constraints)
        )
        let (userPrompt, guestMap, tableMap) = LLMSeatingPlanner.buildPrompt(from: context)
        let systemPrompt = LLMSeatingPlanner.systemPrompt
        let endpoint = lmStudioEndpoint

        // Snapshot guest/table IDs for post-response validation on the main actor.
        let allGuestIDs = Set(guests.map(\.id))
        let tableCapacities: [UUID: Int] = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.capacity) })
        let tableNames: [UUID: String] = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0.name) })
        let hardConstraints: [(type: ConstraintType, guestIDs: [UUID], reason: String)] = constraints.map {
            ($0.type, $0.guestIDs, $0.reason)
        }

        Task { @Sendable in
            let client = LMStudioClient(endpoint: endpoint)
            do {
                let raw = try await client.prompt(system: systemPrompt, user: userPrompt, temperature: 0.2)
                let plan = try LLMSeatingPlanner.parseRawResponse(
                    raw,
                    guestIDMap: guestMap,
                    tableIDMap: tableMap,
                    allGuestIDs: allGuestIDs,
                    tableCapacities: tableCapacities,
                    tableNames: tableNames,
                    hardConstraints: hardConstraints
                )
                await MainActor.run {
                    proposedPlan = plan
                    planApplied = false
                    isRequestingPlan = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Konnte Plan nicht erstellen: \(error.localizedDescription)"
                    isRequestingPlan = false
                }
            }
        }
    }

    private func applyProposedPlan(_ plan: LLMSeatingPlanner.ProposedAssignment) {
        // Map UUID → real table and assign each guest.
        let tablesByID = Dictionary(uniqueKeysWithValues: tables.map { ($0.id, $0) })
        let guestsByID = Dictionary(uniqueKeysWithValues: guests.map { ($0.id, $0) })

        for (guestID, tableID) in plan.assignments {
            guard let guest = guestsByID[guestID], let table = tablesByID[tableID] else { continue }
            guest.table = table
        }
        do {
            try modelContext.save()
            planApplied = true
        } catch {
            errorMessage = "Konnte Plan nicht speichern: \(error.localizedDescription)"
        }
    }
}
#endif
