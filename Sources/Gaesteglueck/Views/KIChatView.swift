#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct KIChatView: View {
    @AppStorage("lmStudioEndpoint") private var lmStudioEndpoint = "http://localhost:1234"
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var tables: [GuestTable]

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var systemContext: String {
        let context = GroupAnalyzer.buildLLMContext(guests: guests, tags: tags, constraints: constraints, tables: tables)
        return "Du bist ein freundlicher Hochzeitsplaner-Assistent. Du hilfst dabei, den perfekten Sitzplan für eine Hochzeit zu erstellen. Hier sind alle relevanten Informationen:\n\n\(context)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                                Text("Freier Chat mit dem KI-Assistenten")
                                    .font(.headline)
                                Text("Stelle Fragen zum Sitzplan, zu Gästen oder zur Tischkonfiguration.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        }

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

            // Input field
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
                        .foregroundStyle(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
        .navigationTitle("KI-Chat")
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        errorMessage = nil
        isLoading = true

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
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}
#endif
