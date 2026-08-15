#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

// MARK: - KI Wizard View

struct KIWizardView: View {
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Guest.firstName) var guests: [Guest]
    @Query var tags: [Tag]
    @Query var constraints: [Constraint]
    @Query var tables: [GuestTable]
    @Query var events: [Event]

    @State private var currentPhase: WizardPhase = .clusters
    @State private var messages: [ChatMessage] = []
    @State private var isLoading = false
    @State private var wizardTask: Task<Void, Never>? = nil
    @State var errorMessage: String?
    @State private var showingChat = false
    /// Persistierter Chat-Verlauf — überlebt App-Restarts. Gespeichert als
    /// JSON-Array im UserDefaults damit kein Schema-Change nötig ist.
    @AppStorage("kiAssistantChatHistory") private var chatHistoryJSON: String = ""
    @AppStorage("kiAssistantPhaseRaw") private var phaseRaw: Int = WizardPhase.clusters.rawValue
    @AppStorage("bridalIncludeTrauzeugen") var bridalIncludeTrauzeugen: Bool = true
    @AppStorage("bridalIncludeEltern") var bridalIncludeEltern: Bool = false
    @AppStorage("bridalIncludeGeschwister") var bridalIncludeGeschwister: Bool = false
    @AppStorage("bridalManualMode") var bridalManualMode: Bool = false
    @State private var didLoadHistory = false

    // Structured plan from LLMSeatingPlanner.
    @State var proposedPlan: LLMSeatingPlanner.ProposedAssignment?
    @State var isRequestingPlan = false
    @State var planApplied = false

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Colors.bg)
        .task {
            // Async statt onAppear: Mutation von messages waehrend des
            // Layout-Pass triggert sonst -[NSView layoutSubtreeIfNeeded]
            // recursion-warnungen und kann zu leerem Render fuehren.
            loadHistoryIfNeeded()
        }
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
            WizardPhaseIndicator(currentPhase: currentPhase)
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
                                Button("Abbrechen") { wizardTask?.cancel() }
                                    .buttonStyle(.plain)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Tokens.Colors.accent)
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
                ProposedPlanPanel(
                    plan: plan,
                    proposedPlan: $proposedPlan,
                    planApplied: $planApplied,
                    onApply: applyProposedPlan
                )
                Divider()
            }

            // Eigene Nachricht — User kann Kontext ergänzen ("Trauzeugen sind
            // X, Y, Z; sollen mit Partnern + Sohn Emil am Brautpaartisch
            // sitzen") bevor er den nächsten Wizard-Step startet. Die Nachricht
            // wird Teil der Conversation und reichert den nächsten LLM-Call an.
            CustomMessageInput(isLoading: isLoading, onSend: sendCustomMessage)
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
                kiAssistantWarning
            } else if proposedPlan == nil && messages.isEmpty {
                kiAssistantIntro
            }
        }
    }

    /// Erklärt was die Buttons machen — verhindert dass der User durch alle
    /// Phasen klickt in der Hoffnung dass dann irgendwann ein Plan rauskommt.
    @ViewBuilder
    private var kiAssistantIntro: some View {
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
    private var kiAssistantWarning: some View {
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

    private func sendCustomMessage(_ trimmed: String) {
        guard !trimmed.isEmpty, !isLoading else { return }
        isLoading = true
        errorMessage = nil

        messages.append(ChatMessage(role: "user", content: trimmed))

        let allMessages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemContext)
        ] + messages.map { LLMMessage(role: $0.role, content: $0.content) }

        wizardTask = Task {
            let client = LLMClientFactory.makeClient(for: .seating)
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

        let allMessages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemContext)
        ] + messages.map { LLMMessage(role: $0.role, content: $0.content) }

        wizardTask = Task {
            let client = LLMClientFactory.makeClient(for: .seating)
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
}
#endif
