#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(AppKit)
import AppKit
#endif

extension GuestListView {
    // MARK: - FunFact Check

    /// Anzahl Gäste mit unklarem oder fehlendem FunFact — für den Export-
    /// Button-Disable-Status.
    var funFactWorklistCount: Int {
        guests.filter { g in
            let trimmed = g.funFact.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty || !g.funFactApproved
        }.count
    }

    enum FunFactExportFormat { case pdf, csv, reminderCSV }

    #if os(macOS)
    /// Exportiert die Liste aller Gäste mit fehlendem oder unbestätigtem
    /// FunFact — pro Gast Vor- und Nachname, derzeitiger FunFact, Status.
    /// Alphabetisch sortiert. PDF mit Erklärung + Beispielen oder CSV
    /// für Excel/Tabelle.
    @MainActor
    func exportFunFactWorklist(format: FunFactExportFormat) {
        let pending = guests.filter(\.needsFunFactFollowUp).sorted { lhs, rhs in
            if lhs.firstName == rhs.firstName { return lhs.lastName < rhs.lastName }
            return lhs.firstName < rhs.firstName
        }
        guard !pending.isEmpty else { return }

        let title = "FunFact-Liste — \(events.first?.name ?? "Hochzeit")"
        let data: Data
        let suggestedName: String
        let contentType: UTType
        switch format {
        case .pdf:
            data = FunFactWorklistExporter.generatePDF(guests: pending, title: title)
            suggestedName = "FunFact-Liste.pdf"
            contentType = .pdf
        case .csv:
            data = FunFactWorklistCSVExporter.generateCSV(guests: pending)
            suggestedName = "FunFact-Liste.csv"
            contentType = .commaSeparatedText
        case .reminderCSV:
            data = FunFactReminderCSVExporter.generateCSV(guests: pending, event: events.first)
            suggestedName = "FunFact-Erinnerungen.csv"
            contentType = .commaSeparatedText
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
    #endif

    func runFunFactCheck() {
        funFactCheckProgress = (0, 0)
        funFactCheckTask = Task { @MainActor in
            isCheckingFunFacts = true
            defer {
                isCheckingFunFacts = false
                funFactCheckTask = nil
            }
            let candidates = guests.filter {
                !$0.funFact.trimmingCharacters(in: .whitespaces).isEmpty && !$0.funFactApproved
            }
            guard !candidates.isEmpty else {
                funFactCheckResult = "Alle FunFacts sind bereits bestaetigt."
                return
            }
            let client = LLMClientFactory.makeClient(for: .funfact)
            do {
                let results = try await FunFactValidator.validateBatch(
                    guests: candidates,
                    client: client,
                    onProgress: { done, total in funFactCheckProgress = (done, total) }
                )
                var goodCount = 0
                var genericCount = 0
                for r in results {
                    guard let guest = guests.first(where: { $0.id == r.guestID }) else { continue }
                    switch r.verdict {
                    case .good:
                        guest.funFactApproved = true
                        goodCount += 1
                    case .generic:
                        guest.funFactApproved = false
                        genericCount += 1
                    case .empty:
                        break
                    }
                }
                try? modelContext.save()
                funFactCheckResult = "\(goodCount) FunFacts bestaetigt, \(genericCount) als generisch markiert."
            } catch is CancellationError {
                funFactCheckResult = "Abgebrochen — nichts geändert."
            } catch {
                if Task.isCancelled {
                    funFactCheckResult = "Abgebrochen — nichts geändert."
                } else {
                    funFactCheckResult = "Fehler: \(error.localizedDescription)"
                }
            }
        }
    }

    func runFunFactNormalize() {
        funFactProgress = (0, 0)
        funFactTask = Task { @MainActor in
            isNormalizingFunFacts = true
            defer {
                isNormalizingFunFacts = false
                funFactTask = nil
            }
            let client = LLMClientFactory.makeClient(for: .funfact)
            do {
                let proposals = try await FunFactNormalizer.proposeBatch(
                    guests: Array(guests),
                    client: client,
                    onProgress: { done, total in funFactProgress = (done, total) }
                )
                guard !proposals.isEmpty else {
                    funFactCheckResult = "Die KI hat keine Vorschläge geliefert (Antwort leer)."
                    return
                }
                let changed = proposals.filter {
                    $0.original.trimmingCharacters(in: .whitespacesAndNewlines)
                        != $0.normalized.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                guard !changed.isEmpty else {
                    funFactCheckResult = "KI lieferte \(proposals.count) Antworten, aber 0 Änderungen "
                        + "— das Modell hat die Texte unverändert zurückgegeben (zu schwach für die Aufgabe)."
                    return
                }
                funFactProposals = changed
                funFactProposalSelection = Set(changed.map(\.guestID))
                showingFunFactReview = true
            } catch is CancellationError {
                funFactCheckResult = "Abgebrochen — nichts geändert."
            } catch {
                if Task.isCancelled {
                    funFactCheckResult = "Abgebrochen — nichts geändert."
                } else {
                    funFactCheckResult = "Fehler: \(error.localizedDescription)"
                }
            }
        }
    }

    func applyFunFactProposals() {
        for proposal in funFactProposals where funFactProposalSelection.contains(proposal.guestID) {
            guard let guest = guests.first(where: { $0.id == proposal.guestID }) else { continue }
            // Rohdaten (funFact) bleiben unangetastet — nur die
            // vereinheitlichte Fassung wird gesetzt. Approval-Status bleibt:
            // Normalisierung ändert die Aussage nicht, nur die Formulierung.
            guest.funFactNormalized = proposal.normalized
        }
        try? modelContext.save()
        showingFunFactReview = false
        funFactProposals = []
    }
}
#endif
