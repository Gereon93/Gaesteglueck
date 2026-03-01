#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @AppStorage("openRouterAPIKey") private var apiKey = ""

    var body: some View {
        Form {
            Section("KI-Assistent (Optional)") {
                SecureField("OpenRouter API-Key", text: $apiKey)
                Text("Kostenlose Modelle verfügbar unter openrouter.ai")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Einstellungen")
    }
}
#endif
