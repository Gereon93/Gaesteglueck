#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
#if canImport(AppKit)
import AppKit
#endif

/// Input-Zeile unter den Nachrichten — der User kann eigenen Kontext
/// hinzufügen (z.B. Trauzeugen-Definition, Tabu-Hinweise), bevor er den
/// nächsten Wizard-Step startet. "Senden" appended User-Message + holt
/// eine KI-Antwort. Der Wizard-Phase ändert sich dabei NICHT — der User
/// kann mehrfach Kontext ergänzen und dann den nächsten Schritt klicken.
struct CustomMessageInput: View {
    @State private var customInput: String = ""
    let isLoading: Bool
    let onSend: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Eigene Info ergänzen — z.B. 'Trauzeugen sind Theo, Patrick, Sina, Lena → mit Partnern + Sinas Sohn Emil am Brautpaartisch'", text: $customInput, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .font(.system(size: 12.5, design: .rounded))
                .onSubmit { send() }
            Button {
                send()
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

    private func send() {
        let trimmed = customInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isLoading else { return }
        customInput = ""
        onSend(trimmed)
    }
}
#endif
