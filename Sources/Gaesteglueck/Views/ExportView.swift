#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData
import AppKit

/// S8 — Export (siehe design_handoff_gaesteglueck → S8). Vollscreen mit
/// linker A4-Vorschau auf Parchment-Hintergrund und rechter 320pt-Spalte
/// mit Optionen — was exportieren, mit welchen Optionen, welches Format.
struct ExportView: View {
    @Query private var events: [Event]
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.firstName) private var guests: [Guest]

    @State private var includeTableLists = true
    @State private var includeCatererSummary = true
    @State private var includeTableCards = false
    @State private var includePoster = false

    @State private var highlightAllergies = true
    @State private var withWavePattern = true
    @State private var withFooter = true
    @State private var blackAndWhite = false

    @State private var format: ExportFormat = .pdf

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case a3 = "Druckbogen A3"

        var subtitle: String {
            switch self {
            case .pdf: "Beste Qualität, druckfertig"
            case .a3: "Mehrere Tische pro Seite"
            }
        }
    }

    private var event: Event? { events.first }
    private var firstTable: GuestTable? { tables.sorted { $0.name < $1.name }.first }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            HStack(spacing: 0) {
                previewPane
                    .frame(maxWidth: .infinity)
                Divider().background(Tokens.Colors.line)
                optionsPane
                    .frame(width: 320)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScreenToolbar(
            title: "Export",
            subtitle: "PDFs für Caterer, Druckerei und Tischkarten."
        ) {
            Button {
                runExport()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Drucken / Speichern")
                }
            }
            .warmButton(.primary)
            .disabled(event == nil)
        }
    }

    // MARK: - Preview pane

    private var previewPane: some View {
        ScrollView {
            VStack {
                Spacer().frame(height: 32)
                a4Preview
                Spacer().frame(height: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Tokens.Colors.bg2)
    }

    @ViewBuilder
    private var a4Preview: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header
                if let event {
                    VStack(spacing: 4) {
                        HStack(spacing: 0) {
                            Text(event.partnerDisplayName1)
                                .font(Tokens.Typography.display(size: 28))
                            Text(" & ")
                                .font(Tokens.Typography.display(size: 28, italic: true))
                            Text(event.partnerDisplayName2)
                                .font(Tokens.Typography.display(size: 28))
                        }
                        .foregroundStyle(Tokens.Colors.ink)
                        Text(headerSubline(event))
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                            .tracking(1)
                        Rectangle()
                            .fill(Tokens.Colors.line2)
                            .frame(width: 80, height: 1)
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                        if let table = firstTable {
                            Text("\(table.name) · \(tableSubtitle(table))")
                                .font(Tokens.Typography.displayXS)
                                .foregroundStyle(Tokens.Colors.ink)
                        }
                    }
                    .padding(.bottom, 24)
                }

                if let table = firstTable {
                    tableContents(table: table)
                } else {
                    Text("Noch keine Tische — füge welche hinzu, um die Export-Vorschau zu sehen.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .multilineTextAlignment(.center)
                        .padding(40)
                }

                Spacer(minLength: 0)

                if withFooter, let event, let table = firstTable {
                    footerLine(event: event, table: table)
                }
            }
            .padding(.horizontal, 56)
            .padding(.vertical, 48)

            if withWavePattern {
                WavePattern(opacity: 0.25)
                    .frame(height: 30)
                    .padding(.horizontal, 56)
                    .padding(.bottom, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 480, height: 660)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Color.black.opacity(0.16), radius: 32, x: 0, y: 8)
    }

    private func headerSubline(_ event: Event) -> String {
        var parts: [String] = []
        if let date = event.date {
            let fmt = DateFormatter()
            fmt.dateStyle = .long
            fmt.locale = Locale(identifier: "de_DE")
            parts.append(fmt.string(from: date))
        }
        if !event.venue.isEmpty {
            parts.append(event.venue)
        }
        return parts.joined(separator: " · ").uppercased()
    }

    private func tableSubtitle(_ table: GuestTable) -> String {
        // Subtitle ist die reine Gäste-Anzahl. Frühere Versionen hatten eine
        // Tag-basierte Sub-Beschriftung, die ist aber nicht mehr aktiv —
        // toter Branch entfernt.
        return "\(table.guests.count) \(table.guests.count == 1 ? "Gast" : "Gäste")"
    }

    private func tableContents(table: GuestTable) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text("GAST")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.gray)
                    .tracking(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("MENÜ")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.gray)
                    .tracking(0.6)
                    .frame(width: 100, alignment: .leading)
                Text("ALLERGIE")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.gray)
                    .tracking(0.6)
                    .frame(width: 100, alignment: .trailing)
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(white: 0.85)).frame(height: 1)
            }

            ForEach(table.guests.prefix(8)) { guest in
                HStack {
                    Text(guest.fullName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(guest.dietaryChoice)
                        .font(.system(size: 12, design: .rounded))
                        .frame(width: 100, alignment: .leading)
                    Text(guest.intolerances.first ?? "—")
                        .font(.system(size: 12, weight: highlightAllergies && guest.hasIntolerances ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(highlightAllergies && guest.hasIntolerances ? Color(hex: "#c44a4a") : Color.gray)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color(white: 0.94)).frame(height: 1)
                }
            }
        }
        .foregroundStyle(blackAndWhite ? Color.black : Tokens.Colors.ink)
    }

    private func footerLine(event: Event, table: GuestTable) -> some View {
        HStack {
            Text("\(table.name) — \(table.capacity) Plätze, \(table.guests.count) belegt")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(footerStandLine(event: event))
        }
        .font(.system(size: 11, design: .rounded))
        .foregroundStyle(Tokens.Colors.ink3)
        .padding(.top, 16)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    private func footerStandLine(event: Event) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.locale = Locale(identifier: "de_DE")
        return "Stand: \(fmt.string(from: .now))"
    }

    // MARK: - Options pane

    private var optionsPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                InspectorSection("Was exportieren") {
                    VStack(alignment: .leading, spacing: 10) {
                        CheckRow(label: "Tischlisten (pro Tisch)", hint: "\(tables.count) Seiten", isOn: $includeTableLists)
                        CheckRow(label: "Caterer-Übersicht", hint: "Mengen pro Menü", isOn: $includeCatererSummary)
                        CheckRow(label: "Tischkarten", hint: "A4, mit Fun Fact", isOn: $includeTableCards)
                        CheckRow(label: "Gesamt-Plakat", hint: "A3, Sitzplan-Übersicht", isOn: $includePoster)
                    }
                }
                InspectorSection("Optionen") {
                    VStack(alignment: .leading, spacing: 10) {
                        CheckRow(label: "Allergien hervorheben", hint: nil, isOn: $highlightAllergies)
                        CheckRow(label: "Mit Wellen-Pattern", hint: "nur Vorschau", isOn: $withWavePattern)
                        CheckRow(label: "Mit Fußzeile", hint: "Stand, Seitenzahl", isOn: $withFooter)
                        CheckRow(label: "Schwarz-weiß", hint: nil, isOn: $blackAndWhite)
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

    // MARK: - Run export

    private func runExport() {
        guard let event else { return }

        if includeTableLists || includeCatererSummary {
            let opts = PDFExporter.Options(
                includeTableLists: includeTableLists,
                includeCatererSummary: includeCatererSummary,
                highlightAllergies: highlightAllergies,
                withFooter: withFooter,
                blackAndWhite: blackAndWhite
            )
            let data = PDFExporter.generatePDF(
                tables: tables,
                eventName: event.name,
                date: event.date,
                options: opts
            )
            saveData(data, name: "Sitzplan-\(event.name).pdf")
        }
        if includeTableCards {
            let data = TableCardExporter.generatePDF(
                guests: guests,
                eventName: event.name
            )
            saveData(data, name: "Tischkarten-\(event.name).pdf")
        }
        if includePoster {
            let data = PosterExporter.generatePDF(
                tables: tables,
                unassignedGuests: guests.filter { $0.table == nil },
                eventName: event.name,
                date: event.date
            )
            saveData(data, name: "Plakat-\(event.name).pdf")
        }
    }

    private func saveData(_ data: Data, name: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = name
        panel.begin { response in
            if response == .OK, let url = panel.url {
                try? data.write(to: url)
            }
        }
    }
}

// MARK: - Checkrow / Radio

private struct CheckRow: View {
    let label: String
    let hint: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isOn ? Tokens.Colors.accent : Tokens.Colors.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(isOn ? Tokens.Colors.accent : Tokens.Colors.line2, lineWidth: 1.5)
                        }
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 16, height: 16)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    if let hint {
                        Text(hint)
                            .font(.system(size: 11.5, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct RadioRow: View {
    let label: String
    let subtitle: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Tokens.Colors.surface)
                        .overlay {
                            Circle().strokeBorder(isActive ? Tokens.Colors.accent : Tokens.Colors.line2, lineWidth: 1.5)
                        }
                    if isActive {
                        Circle()
                            .fill(Tokens.Colors.accent)
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(width: 16, height: 16)
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isActive ? Tokens.Colors.accentTint : Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isActive ? Tokens.Colors.accent : Tokens.Colors.line, lineWidth: 1.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
#endif
