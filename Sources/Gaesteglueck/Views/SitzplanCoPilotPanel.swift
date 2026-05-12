#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct SitzplanCoPilotPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var events: [Event]

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isThinking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Tokens.Colors.line)
            transcript
            Divider().background(Tokens.Colors.line)
            inputBar
        }
        .background(Tokens.Colors.surface)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Tokens.Colors.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Sitzplan-Co-Pilot")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Frag Fragen oder gib Befehle wie 'Patrick auf T2'.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer()
            if !messages.isEmpty {
                Button {
                    messages = []
                    errorMessage = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Tokens.Colors.ink3)
                .help("Chat zurücksetzen")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if messages.isEmpty {
                        emptyHint
                    }
                    ForEach(messages) { msg in
                        bubble(for: msg).id(msg.id)
                    }
                    if isThinking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("KI denkt nach…")
                                .font(.system(size: 11.5, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                        .padding(.horizontal, 12)
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.warn)
                            .padding(.horizontal, 12)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Beispiele:")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.5)
            ForEach([
                "Welche Tische haben noch Plätze?",
                "Setze Patrick auf T2",
                "Tausche Lisa und Anna",
                "Wer sitzt am Brautpaartisch?",
            ], id: \.self) { example in
                Button {
                    inputText = example
                } label: {
                    Text("• \(example)")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bubble(for message: ChatMessage) -> some View {
        HStack(alignment: .top, spacing: 6) {
            if message.role == "user" { Spacer(minLength: 30) }
            Text(message.content)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(message.role == "user" ? .white : Tokens.Colors.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(message.role == "user" ? Tokens.Colors.accent : Tokens.Colors.bg2)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .textSelection(.enabled)
            if message.role != "user" { Spacer(minLength: 30) }
        }
        .padding(.horizontal, 12)
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            TextField("Befehl oder Frage…", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .font(.system(size: 12, design: .rounded))
                .onSubmit { Task { await send() } }
            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @MainActor
    private func send() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }
        inputText = ""
        errorMessage = nil
        isThinking = true
        defer { isThinking = false }

        let userMsg = ChatMessage(role: "user", content: trimmed)
        messages.append(userMsg)

        let context = buildSaalContext()
        let history = Array(messages.dropLast())

        let client = LLMClientFactory.makeFromSettings()
        let pilot = SitzplanCoPilot(client: client)
        do {
            let response = try await pilot.ask(userMessage: trimmed, history: history, saalContext: context)
            let summaries = applyActionsAndCollectSummaries(response.actions)
            let displayText = combineText(response.text, summaries: summaries)
            messages.append(ChatMessage(role: "assistant", content: displayText))
            try? modelContext.save()
        } catch {
            messages.removeLast()
            errorMessage = error.localizedDescription
        }
    }

    private func applyActionsAndCollectSummaries(_ actions: [CoPilotAction]) -> [String] {
        actions.map { action in
            SitzplanCoPilotApplier.apply(action: action, guests: guests, tables: tables)
        }
    }

    private func combineText(_ text: String, summaries: [String]) -> String {
        var lines: [String] = []
        if !text.isEmpty { lines.append(text) }
        lines.append(contentsOf: summaries.filter { !$0.isEmpty })
        return lines.joined(separator: "\n")
    }

    private func buildSaalContext() -> String {
        var ctx = "## Aktueller Saal-Stand\n\n"
        ctx += GroupAnalyzer.buildLLMContext(
            guests: guests,
            tags: tags,
            constraints: constraints,
            tables: tables,
            event: events.first
        )
        ctx += "\n\n## Aktuelle Tisch-Belegung\n\n"
        for table in tables.sorted(by: { $0.name < $1.name }) {
            let names = table.guests.map(\.fullName).sorted().joined(separator: ", ")
            ctx += "- \(table.name) (\(table.guests.count)/\(table.capacity)): \(names.isEmpty ? "leer" : names)\n"
        }
        let unassigned = guests.filter { $0.table == nil }.map(\.fullName).sorted()
        if !unassigned.isEmpty {
            ctx += "\nNoch nicht zugewiesen: \(unassigned.joined(separator: ", "))\n"
        }
        return ctx
    }
}
#endif
