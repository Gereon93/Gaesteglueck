#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Auto-Tag-Generator mit Chat-artiger Eingabe pro Partner.
/// LLM erzeugt Tag-Vorschläge UND ordnet bestehende Gäste zu — der User
/// kann pro Vorschlag entscheiden ob er übernehmen will, dann fügt ein Klick
/// alle Tags inkl. Mitgliederliste an.
struct TagGeneratorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query(sort: \Guest.firstName) var guests: [Guest]
    @Query var existingTags: [Tag]
    @Query var events: [Event]

    @State var partner1Hint = ""
    @State var partner2Hint = ""
    @State var isGenerating = false
    @State var generateTask: Task<Void, Never>? = nil
    @State var proposals: [ProposedTag] = []
    @State var errorMessage: String?
    @State var hasGenerated = false
    @State var rawDebugResponse: String? = nil
    @State var showingRawDebug = false
    @State var useAIForAssignment: Bool = false
    @State var skippedFamilyTerms: [String] = []

    var event: Event? { events.first }
    var partner1Name: String { event?.partnerDisplayName1 ?? "Partner 1" }
    var partner2Name: String { event?.partnerDisplayName2 ?? "Partner 2" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Tokens.Colors.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if proposals.isEmpty {
                        inputStage
                    } else {
                        reviewStage
                    }
                }
                .padding(24)
                .frame(maxWidth: 720, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if !proposals.isEmpty {
                Divider().background(Tokens.Colors.line)
                applyBar
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(Tokens.Colors.bg)
        .sheet(isPresented: $isGenerating) {
            AIRunIndicator(
                title: useAIForAssignment ? "KI ordnet die Tags zu…" : "Tags werden berechnet…",
                detail: "Das kann je nach Modell etwas dauern.",
                onCancel: { generateTask?.cancel() }
            )
            .interactiveDismissDisabled(true)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tags automatisch generieren")
                    .font(Tokens.Typography.display(size: 22))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Beschreibe wen ihr eingeladen habt — die KI legt die Tags an und ordnet die Gäste zu.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
            Spacer()
            Button("Schließen") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
}
#endif
