#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension GuestListView {
    // MARK: - Toolbar

    var toolbar: some View {
        ScreenToolbar(title: "Gästeliste", subtitle: toolbarSubtitle) {
            if selectedGuestIDs.count >= 2 {
                Button {
                    linkSelectedAsMustSitTogether()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "link.badge.plus")
                        Text("Müssen zusammen")
                    }
                }
                .warmButton(.secondary)
                Button {
                    showingDeleteAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("\(selectedGuestIDs.count) löschen")
                    }
                }
                .warmButton(.secondary)
                .foregroundStyle(Tokens.Colors.error)
                Button("Auswahl aufheben") {
                    selectedGuestIDs.removeAll()
                    anchorGuestID = nil
                }
                .warmButton(.ghost)
            } else if filtering.hasActiveFilter, !filtering.filteredGuests.isEmpty {
                // Wenn nichts ausgewählt aber ein Filter aktiv ist → Quick-
                // Action zum Massen-Selektieren des sichtbaren Bereichs.
                // Workflow: Filter side=Bob + tag=Freundesgruppe → klick
                // "Alle X auswählen" → im Inspector "Tag hinzufügen" mit
                // "Geburtstag Bob".
                Button {
                    selectAllVisible()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                        Text("Alle \(filtering.filteredGuests.count) auswählen")
                    }
                }
                .warmButton(.secondary)
            }
            Button {
                runFunFactCheck()
            } label: {
                HStack(spacing: 4) {
                    if isCheckingFunFacts { ProgressView().controlSize(.small) }
                    Image(systemName: "checkmark.seal")
                    Text("FunFacts prüfen")
                }
            }
            .warmButton(.secondary)
            .disabled(isCheckingFunFacts || guests.isEmpty)
            Button {
                runFunFactNormalize()
            } label: {
                HStack(spacing: 4) {
                    if isNormalizingFunFacts { ProgressView().controlSize(.small) }
                    Image(systemName: "text.append")
                    Text("Vereinheitlichen")
                }
            }
            .warmButton(.secondary)
            .disabled(isNormalizingFunFacts || guests.isEmpty)
            .help("FunFacts per KI in einheitliche Ich-Form bringen — du bestätigst vor dem Übernehmen")
            #if os(macOS)
            Menu {
                Button("Als PDF exportieren") {
                    exportFunFactWorklist(format: .pdf)
                }
                Button("Als CSV / Excel exportieren") {
                    exportFunFactWorklist(format: .csv)
                }
                Divider()
                Button("Erinnerungstexte (CSV) — versandfertig") {
                    exportFunFactWorklist(format: .reminderCSV)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("FunFact-Liste")
                }
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .disabled(funFactWorklistCount == 0)
            #endif
            #if canImport(UniformTypeIdentifiers)
            ImportButton()
            #endif
            GoogleSheetsImportButton()
            Button {
                showingAddSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Gast hinzufügen")
                }
            }
            .warmButton(.primary)
        }
    }

    var toolbarSubtitle: String {
        let total = guests.count
        let registrationCount = Set(guests.map { $0.registrationGroup }).count
        let allergic = guests.filter { $0.hasIntolerances }.count
        if total == 0 { return "Noch keine Gäste — leg los mit dem Import." }
        return "\(total) Gäste · \(registrationCount) Anmeldungen · \(allergic) mit Allergie"
    }
}
#endif
