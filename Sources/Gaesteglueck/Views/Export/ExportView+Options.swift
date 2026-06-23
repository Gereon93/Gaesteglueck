#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData
import AppKit

// MARK: - Options pane
//
// Rechte 320pt-Spalte. Als Extension auf ExportView, damit die @State-,
// @AppStorage- und @Query-Properties des Parents direkt gebunden werden.
extension ExportView {

    var optionsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                InspectorSection("Was exportieren") {
                    VStack(alignment: .leading, spacing: 10) {
                        CheckRow(label: "Tischlisten (pro Tisch)", hint: "\(tables.count) Seiten", isOn: $includeTableLists)
                        CheckRow(label: "Caterer-Übersicht", hint: "Mengen pro Menü", isOn: $includeCatererSummary)
                        CheckRow(label: "Tischkarten", hint: "A4, mit Fun Fact", isOn: $includeTableCards)
                        CheckRow(label: "Gesamt-Plakat", hint: "A3, Sitzplan-Übersicht", isOn: $includePoster)
                        CheckRow(label: "Bildlicher Sitzplan", hint: "A3, Namen an Sitzpositionen", isOn: $includeVisualPlan)
                        CheckRow(label: "FunFact-Spielkarten", hint: "Anonyme Karten zum Verteilen + Lösungsblatt", isOn: $includeGameCards)
                        CheckRow(label: "Telefonnummern (vCard)", hint: ".vcf — fuer WhatsApp-Gruppe der Trauzeugin", isOn: $includePhoneVCards)
                        CheckRow(label: "Sitzplan als PNG", hint: "Volle Canvas inkl. Saalplan, frei skalierbar", isOn: $includeCanvasPNG)
                        CheckRow(label: "Gäste für die Rede (Markdown)", hint: ".md — nach Seite & Tags, für Claude Desktop", isOn: $includeSpeechGuests)
                    }
                }
                InspectorSection("Optionen") {
                    VStack(alignment: .leading, spacing: 10) {
                        CheckRow(label: "Allergien hervorheben", hint: nil, isOn: $highlightAllergies)
                        CheckRow(label: "Mit Wellen-Pattern", hint: "nur Vorschau", isOn: $withWavePattern)
                        CheckRow(label: "Schwarz-weiß", hint: nil, isOn: $blackAndWhite)
                        if includeVisualPlan {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Namen im Bildlichen Sitzplan")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Picker("", selection: $visualPlanNameStyleRaw) {
                                    ForEach(VisualSeatingPlanExporter.NameStyle.allCases) { style in
                                        Text(style.rawValue).tag(style.rawValue)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }
                        CheckRow(label: "Titel auf Tischkarten",
                                 hint: "z.B. 'Dr.', 'Pfarrer' vor dem Namen — wirkt nur wenn Tischkarten aktiv",
                                 isOn: $tableCardsWithTitle)
                    }
                }
                InspectorSection("Format") {
                    VStack(spacing: 6) {
                        ForEach(ExportFormat.allCases, id: \.self) { f in
                            RadioRow(
                                label: f.rawValue,
                                subtitle: f.subtitle,
                                isActive: format == f
                            ) {
                                format = f
                            }
                        }
                    }
                }
            }
        }
    }
}
#endif
#endif
