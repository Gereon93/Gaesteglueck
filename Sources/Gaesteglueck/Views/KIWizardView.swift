#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    var id: UUID = UUID()
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
                .textSelection(.enabled)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isUser ? Color.blue : Color.secondary.opacity(0.15))
                .foregroundStyle(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contextMenu {
                    Button {
                        copyToClipboard(message.content)
                    } label: {
                        Label("Nachricht kopieren", systemImage: "doc.on.doc")
                    }
                }
            if !isUser { Spacer(minLength: 48) }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
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
    @Query private var events: [Event]

    @State private var currentPhase: WizardPhase = .clusters
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingChat = false
    @State private var customInput: String = ""
    /// Persistierter Chat-Verlauf — überlebt App-Restarts. Gespeichert als
    /// JSON-Array im UserDefaults damit kein Schema-Change nötig ist.
    @AppStorage("kiAssistantChatHistory") private var chatHistoryJSON: String = ""
    @AppStorage("kiAssistantPhaseRaw") private var phaseRaw: Int = WizardPhase.clusters.rawValue
    @State private var didLoadHistory = false

    // Structured plan from LLMSeatingPlanner.
    @State private var proposedPlan: LLMSeatingPlanner.ProposedAssignment?
    @State private var isRequestingPlan = false
    @State private var planApplied = false

    private var systemContext: String {
        let context = GroupAnalyzer.buildLLMContext(guests: guests, tags: tags, constraints: constraints, tables: tables, event: events.first)
        return "Du bist ein freundlicher Hochzeitsplaner-Assistent. Du hilfst dabei, den perfekten Sitzplan für eine Hochzeit zu erstellen. Hier sind alle relevanten Informationen:\n\n\(context)"
    }

    var body: some View {
        Group {
            if showingChat {
                KIChatView()
            } else {
                wizardView
            }
        }
        .onAppear { loadHistoryIfNeeded() }
        .onChange(of: messages.count) { _, _ in saveHistory() }
        .onChange(of: currentPhase) { _, new in phaseRaw = new.rawValue }
    }

    private func loadHistoryIfNeeded() {
        guard !didLoadHistory else { return }
        didLoadHistory = true
        if let phase = WizardPhase(rawValue: phaseRaw) { currentPhase = phase }
        guard !chatHistoryJSON.isEmpty,
              let data = chatHistoryJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([ChatMessage].self, from: data) else { return }
        messages = decoded
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(messages),
           let str = String(data: data, encoding: .utf8) {
            chatHistoryJSON = str
        }
    }

    private func clearHistory() {
        messages = []
        chatHistoryJSON = ""
        currentPhase = .clusters
        phaseRaw = WizardPhase.clusters.rawValue
        errorMessage = nil
    }

    private func copyEntireChat() {
        let text = messages.map { msg in
            let prefix = msg.role == "user" ? "🧑 Du:" : "🤖 KI:"
            return "\(prefix)\n\(msg.content)"
        }.joined(separator: "\n\n---\n\n")
        #if canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
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

            // Eigene Nachricht — User kann Kontext ergänzen ("Trauzeugen sind
            // X, Y, Z; sollen mit Partnern + Sohn Emil am Brautpaartisch
            // sitzen") bevor er den nächsten Wizard-Step startet. Die Nachricht
            // wird Teil der Conversation und reichert den nächsten LLM-Call an.
            customMessageInput
            Divider()

            // Bottom bar — der KONKRETE Plan-Button ist immer verfügbar.
            // Das Wizard ist nur optionaler Context-Aufbau, kein Pflicht-Pfad.
            HStack(spacing: 8) {
                Button {
                    requestStructuredPlan()
                } label: {
                    HStack(spacing: 4) {
                        if isRequestingPlan { ProgressView().controlSize(.small) }
                        Image(systemName: "wand.and.stars")
                        Text(proposedPlan == nil ? "Sitzplan jetzt erstellen" : "Sitzplan neu erstellen")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRequestingPlan || guests.isEmpty || tables.isEmpty)

                if currentPhase != .done {
                    Button {
                        callLLM()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Mehr Kontext: \(currentPhase.title)")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || guests.isEmpty)
                }

                Button {
                    copyEntireChat()
                } label: {
                    Image(systemName: "doc.on.clipboard")
                }
                .help("Gesamten Chat-Verlauf kopieren")
                .buttonStyle(.bordered)
                .disabled(messages.isEmpty)

                Spacer()

                if !messages.isEmpty {
                    Button("Chat zurücksetzen") {
                        clearHistory()
                        proposedPlan = nil
                        planApplied = false
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("KI-Assistent")
        .safeAreaInset(edge: .top) {
            if guests.isEmpty || tables.isEmpty {
                ki_assistant_warning
            } else if proposedPlan == nil && messages.isEmpty {
                ki_assistant_intro
            }
        }
    }

    /// Erklärt was die Buttons machen — verhindert dass der User durch alle
    /// Phasen klickt in der Hoffnung dass dann irgendwann ein Plan rauskommt.
    @ViewBuilder
    private var ki_assistant_intro: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("So funktioniert's")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Text("'Sitzplan jetzt erstellen' macht direkt einen konkreten Tisch-Vorschlag den du übernehmen kannst. Die 'Mehr Kontext'-Phasen sind optional — sie bauen Hintergrundwissen für die KI auf (Cluster, Konflikte, Kindertisch). Brauchst du sie nicht: einfach direkt den Plan erstellen.")
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08))
    }

    @ViewBuilder
    private var ki_assistant_warning: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(guests.isEmpty
                ? "Importiere erst deine Gästeliste — sonst kann die KI keinen Plan bauen."
                : "Lege erst Tische im Sitzplan-Setup an — sonst gibt's nichts zum Verteilen.")
                .font(.system(size: 12, design: .rounded))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
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

    /// Input-Zeile unter den Nachrichten — der User kann eigenen Kontext
    /// hinzufügen (z.B. Trauzeugen-Definition, Tabu-Hinweise), bevor er den
    /// nächsten Wizard-Step startet. "Senden" appended User-Message + holt
    /// eine KI-Antwort. Der Wizard-Phase ändert sich dabei NICHT — der User
    /// kann mehrfach Kontext ergänzen und dann den nächsten Schritt klicken.
    @ViewBuilder
    private var customMessageInput: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Eigene Info ergänzen — z.B. 'Trauzeugen sind Theo, Patrick, Sina, Lena → mit Partnern + Sinas Sohn Emil am Brautpaartisch'", text: $customInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .font(.system(size: 12.5, design: .rounded))
                .onSubmit { sendCustomMessage() }
            Button {
                sendCustomMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderedProminent)
            .disabled(customInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sendCustomMessage() {
        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        customInput = ""
        isLoading = true
        errorMessage = nil

        messages.append(ChatMessage(role: "user", content: trimmed))

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
                }
            } catch {
                await MainActor.run {
                    messages.removeLast()
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
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
