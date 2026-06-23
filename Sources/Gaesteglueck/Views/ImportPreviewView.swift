#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// S4 — Anmeldungs-Import (siehe design_handoff_gaesteglueck → S4).
/// Parst pro Zeile via LM Studio in strukturierte Gäste, zeigt das
/// Ergebnis pro Karte mit Original oben + KI-Interpretation unten.
/// Wenn die KI nicht erreichbar ist, fällt der Parser auf den Regex-
/// Fallback zurück und markiert die Karte als "prüfen".
struct ImportPreviewView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @AppStorage("lmStudioEndpoint") var lmStudioEndpoint = "http://localhost:1234"

    let rows: [RegistrationRow]
    let onComplete: (Int) -> Void

    @State var rowStates: [Int: RowState] = [:]
    @State var skippedIndices: Set<Int> = []
    @State var importedIndices: Set<Int> = []
    @State var autoSkippedIndices: Set<Int> = []
    @State private var showingAutoSkipped = false
    @State private var hasStartedParsing = false
    @State var llmReachable: Bool? = nil
    @State var isRetrying = false
    @State private var parseTask: Task<Void, Never>? = nil
    @State var parseProgress: (done: Int, total: Int) = (0, 0)

    enum RowState {
        case parsing
        case parsed([ImportedGuest])
        case fallback([ImportedGuest], reason: String)

        var guests: [ImportedGuest] {
            switch self {
            case .parsing: return []
            case .parsed(let g), .fallback(let g, _): return g
            }
        }
    }

    private var totalGuests: Int {
        rows.reduce(0) { $0 + $1.guestCount }
    }

    private var canApplyAll: Bool {
        guard !pendingRows.isEmpty else { return false }
        return pendingRows.allSatisfy { _, _ in true }
            && pendingRows.contains { i, _ in
                if case .parsing = rowStates[i] { return false }
                return true
            }
    }

    var body: some View {
        ZStack {
            Tokens.Colors.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if parseTask != nil {
                            parseProgressBanner
                        }
                        if llmReachable == false {
                            llmOfflineBanner
                        }
                        infoBanner
                        if !autoSkippedIndices.isEmpty {
                            autoSkippedBanner
                        }
                        ForEach(rows.indices, id: \.self) { i in
                            let isAutoSkipped = autoSkippedIndices.contains(i)
                            let visible = !skippedIndices.contains(i)
                                && !importedIndices.contains(i)
                                && (!isAutoSkipped || showingAutoSkipped)
                            if visible {
                                ImportRowCard(
                                    row: rows[i],
                                    state: rowStates[i] ?? .parsing,
                                    isAutoSkipped: isAutoSkipped,
                                    onUpdate: { newGuests in
                                        updateGuests(at: i, with: newGuests)
                                    },
                                    onAccept: {
                                        applyRow(at: i)
                                    },
                                    onSkip: {
                                        skippedIndices.insert(i)
                                        persistSkip(rowIndex: i)
                                    }
                                )
                            }
                        }
                        if pendingRows.isEmpty && rows.count > 0 {
                            Text("Alle Anmeldungen abgearbeitet.")
                                .font(Tokens.Typography.bodyM)
                                .foregroundStyle(Tokens.Colors.ink3)
                                .padding(.vertical, 24)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .task {
            guard !hasStartedParsing else { return }
            hasStartedParsing = true
            let t = Task { await parseAllRows() }
            parseTask = t
            await t.value
            parseTask = nil
        }
    }

    private var parseProgressBanner: some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            VStack(alignment: .leading, spacing: 2) {
                Text("KI liest die Anmeldungen…")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                if parseProgress.total > 0 {
                    Text("\(parseProgress.done) / \(parseProgress.total) Anmeldungen · \(max(0, parseProgress.total - parseProgress.done)) offen")
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
            }
            Spacer()
            Button("Abbrechen", role: .cancel) { parseTask?.cancel() }
                .warmButton(.secondary, size: .sm)
        }
        .padding(12)
        .background(Tokens.Colors.bg2)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Tokens.Colors.line, lineWidth: 1)
        }
    }

    private var toolbar: some View {
        ScreenToolbar(
            title: "Anmeldungen prüfen",
            subtitle: "Wir haben \(rows.count) \(rows.count == 1 ? "Anmeldung" : "Anmeldungen") erkannt — schau einmal drüber."
        ) {
            Button("Abbrechen") { dismiss() }
                .warmButton(.ghost)
            Button("Alle überspringen") {
                skippedIndices = Set(rows.indices)
                for i in rows.indices {
                    persistSkip(rowIndex: i)
                }
                finalize()
            }
            .warmButton(.secondary)
            .disabled(pendingRows.isEmpty)
            Button {
                for (i, _) in pendingRows {
                    applyRow(at: i)
                }
                finalize()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                    Text("Alle übernehmen (\(pendingRows.count))")
                }
            }
            .warmButton(.primary)
            .disabled(pendingRows.isEmpty)
        }
    }

    private var infoBanner: some View {
        ConflictBanner(
            title: "\(rows.count) \(rows.count == 1 ? "Anmeldung erkannt" : "Anmeldungen erkannt") · \(totalGuests) Personen insgesamt",
            message: "Die Datei wurde lokal verarbeitet. Bestehende Anmeldungen erkennen wir am Familiennamen.",
            tone: .info
        )
    }

    private var autoSkippedBanner: some View {
        ConflictBanner(
            title: "\(autoSkippedIndices.count) \(autoSkippedIndices.count == 1 ? "Anmeldung" : "Anmeldungen") unverändert — automatisch übersprungen",
            message: "Diese Anmeldungen sind bereits in der Gästeliste und haben keine Änderungen. Du kannst sie trotzdem einblenden falls du nochmal drüberschauen willst.",
            tone: .info
        ) {
            Button {
                showingAutoSkipped.toggle()
            } label: {
                Text(showingAutoSkipped ? "Wieder ausblenden" : "Trotzdem anzeigen")
            }
            .warmButton(.secondary, size: .sm)
        }
    }

    private var llmOfflineBanner: some View {
        ConflictBanner(
            title: "LM Studio ist nicht erreichbar — wir nutzen den einfachen Parser",
            message: "Für bessere Erkennung (insbesondere bei Mehrfach-Familiennamen wie 'Stein, Becker') starte LM Studio mit einem Modell und klick 'Erneut versuchen'.",
            tone: .warn
        ) {
            Button {
                Task { await retryWithLLM() }
            } label: {
                HStack(spacing: 4) {
                    if isRetrying {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text("Erneut versuchen")
                }
            }
            .warmButton(.secondary, size: .sm)
            .disabled(isRetrying)
        }
    }

    @Query var existingConstraints: [Constraint]

    @Query var existingGuests: [Guest]
    @Query(sort: \Tag.name) var existingTags: [Tag]
    @Query var allEvents: [Event]
    var currentEvent: Event? { allEvents.first }
}
#endif
