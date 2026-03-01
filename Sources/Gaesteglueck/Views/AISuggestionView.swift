#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct AISuggestionView: View {
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.name) private var guests: [Guest]
    @Query private var relationships: [Relationship]

    @State private var suggestion = ""
    @State private var isLoading = false
    @State private var error: String?
    @AppStorage("openRouterAPIKey") private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("KI-Assistent", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await fetchSuggestion() }
                } label: {
                    Label(isLoading ? "Denke nach..." : "Vorschläge holen", systemImage: "arrow.clockwise")
                }
                .disabled(isLoading || apiKey.isEmpty)
            }

            if apiKey.isEmpty {
                Text("API-Key in Einstellungen konfigurieren.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
            }

            if !suggestion.isEmpty {
                ScrollView {
                    Text(suggestion)
                        .font(.callout)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func fetchSuggestion() async {
        isLoading = true
        error = nil

        let violations = HappinessScorer.findViolations(tables: tables, relationships: relationships)
        let prompt = AIAssistant.generatePrompt(
            tables: tables,
            guests: guests,
            relationships: relationships,
            violations: violations
        )

        let client = OpenRouterClient(apiKey: apiKey)
        do {
            suggestion = try await client.suggest(prompt: prompt)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
#endif
