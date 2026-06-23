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
#endif
