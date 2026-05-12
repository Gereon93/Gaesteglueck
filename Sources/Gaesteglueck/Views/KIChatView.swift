#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct KIChatView: View {
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var tables: [GuestTable]
    @Query private var events: [Event]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var connectionState: ConnectionState = .unknown
    @State private var currentTask: Task<Void, Never>?

    enum ConnectionState: Equatable {
        case unknown, checking, connected(String), unreachable(String)
    }

    private struct QuickAction {
        let label: String
        let icon: String
        let prompt: String
    }

    private var quickActions: [QuickAction] {
        [
            QuickAction(label: "Probleme prüfen", icon: "exclamationmark.triangle",
                        prompt: "Welche Konflikte oder Verstöße gibt es im aktuellen Sitzplan? Bitte konkret nennen, an welchem Tisch und mit welchen Personen."),
            QuickAction(label: "Zusammenfassung", icon: "list.bullet.rectangle",
                        prompt: "Fasse den aktuellen Sitzplan kurz zusammen — pro Tisch wer dort sitzt und warum."),
            QuickAction(label: "Vorschlag verbessern", icon: "wand.and.sparkles",
                        prompt: "Wie könnten wir den aktuellen Plan noch besser machen? Drei konkrete Vorschläge bitte.")
        ]
    }

    private var examplePrompts: [String] {
        [
            "Tausche die Gäste an Tisch 3 und Tisch 5.",
            "Onkel Karl sollte weg von Tante Helga sitzen.",
            "Wer würde noch zu Tisch 7 passen?",
            "Welche Brückenpersonen verbinden die Studienfreunde mit der Familie?"
        ]
    }

    private var systemContext: String {
        let context = GroupAnalyzer.buildLLMContext(guests: guests, tags: tags, constraints: constraints, tables: tables, event: events.first)
        return "Du bist ein freundlicher Hochzeitsplaner-Assistent. Du hilfst dabei, den perfekten Sitzplan für eine Hochzeit zu erstellen. Antworte auf Deutsch, sei konkret und nenne Namen.\n\nHier sind alle relevanten Informationen:\n\n\(context)"
    }

    var body: some View {
        VStack(spacing: 0) {
            connectionBadge
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            chatEmptyState
                        }

                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }

                        if isLoading {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text("KI denkt nach…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button("Abbrechen") {
                                    currentTask?.cancel()
                                    isLoading = false
                                }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }

                        if let error = errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .font(.caption)
                                .padding(.horizontal)
                                .fixedSize(horizontal: false, vertical: true)
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

            if !messages.isEmpty {
                Divider()
                quickActionsRow
            }

            Divider()
            inputRow
        }
        .navigationTitle("KI-Chat")
        .task {
            await checkConnection()
        }
    }

    // MARK: - Subviews

    private var connectionBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(connectionDotColor)
                .frame(width: 8, height: 8)
            Text(connectionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await checkConnection() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Verbindung erneut prüfen")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var chatEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 36))
                .foregroundStyle(Color(red: 0.78, green: 0.47, blue: 0.55))
            VStack(spacing: 4) {
                Text("KI-Assistent für den Sitzplan")
                    .font(.headline)
                Text("Frag direkt los, oder probier eines dieser Beispiele:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(examplePrompts, id: \.self) { prompt in
                    Button {
                        inputText = prompt
                    } label: {
                        HStack {
                            Image(systemName: "quote.bubble")
                                .foregroundStyle(.tertiary)
                            Text(prompt)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(.secondary.opacity(0.2))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 460)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    private var quickActionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickActions, id: \.label) { action in
                    Button {
                        inputText = action.prompt
                        sendMessage()
                    } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            TextField("Frage stellen…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onSubmit {
                    if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        sendMessage()
                    }
                }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSubmit ? Color(red: 0.78, green: 0.47, blue: 0.55) : Color.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
    }

    // MARK: - Connection state helpers

    private var connectionDotColor: Color {
        switch connectionState {
        case .unknown: .secondary
        case .checking: .yellow
        case .connected: .green
        case .unreachable: .orange
        }
    }

    private var connectionLabel: String {
        switch connectionState {
        case .unknown: "Status unbekannt"
        case .checking: "Prüfe LM Studio…"
        case .connected(let model): "Verbunden mit LM Studio · \(model)"
        case .unreachable(let reason): "LM Studio nicht erreichbar — \(reason)"
        }
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Actions

    @MainActor
    private func checkConnection() async {
        connectionState = .checking
        let client = LMStudioClient(endpoint: lmStudioEndpoint)
        do {
            let model = try await client.checkConnection()
            connectionState = .connected(model.isEmpty ? "kein Modell" : model)
        } catch {
            connectionState = .unreachable(error.localizedDescription)
        }
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        errorMessage = nil
        isLoading = true

        messages.append(ChatMessage(role: "user", content: trimmed))

        let allMessages: [LLMMessage] = [
            LLMMessage(role: "system", content: systemContext)
        ] + messages.map { LLMMessage(role: $0.role, content: $0.content) }

        currentTask = Task {
            let client = LLMClientFactory.makeFromSettings()
            do {
                let reply = try await client.chat(messages: allMessages)
                if Task.isCancelled { return }
                await MainActor.run {
                    messages.append(ChatMessage(role: "assistant", content: reply))
                    isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run { isLoading = false }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
#endif
