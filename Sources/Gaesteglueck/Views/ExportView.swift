#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import UniformTypeIdentifiers
import SwiftData
import AppKit

/// S8 — Export (siehe design_handoff_gaesteglueck → S8). Vollscreen mit
/// linker A4-Vorschau auf Parchment-Hintergrund und rechter 320pt-Spalte
/// mit Optionen — was exportieren, mit welchen Optionen, welches Format.
struct ExportView: View {
    @Query private var events: [Event]
    @Query private var tables: [GuestTable]
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]

    @State private var includeTableLists = true
    @State private var includeCatererSummary = true
    @State private var includeTableCards = false
    @State private var includePoster = false
    @State private var includeGameCards = false
    @State private var includePhoneVCards = false
    @State private var includeCanvasPNG = false
    @State private var includeSpeechGuests = false
    @AppStorage("tableCardsWithTitle") private var tableCardsWithTitle: Bool = false
    @Query private var canvasLabels: [CanvasLabel]
    @AppStorage("includeVisualPlan") private var includeVisualPlan: Bool = true
    @AppStorage("visualPlanNameStyle") private var visualPlanNameStyleRaw: String = VisualSeatingPlanExporter.NameStyle.smartDeduped.rawValue
    @AppStorage("canvasSeatNameStyle") private var canvasSeatNameStyleRaw: String = VisualSeatingPlanExporter.NameStyle.full.rawValue
    @AppStorage("lastCanvasScale") private var lastCanvasScale: Double = 1.0 / 3.0
    // Live-Canvas-Anzeige-Toggles — werden in die Canvas-PNG übernommen.
    @AppStorage("canvasShowSeatNames") private var canvasShowSeatNames = false
    @AppStorage("canvasSeatInfoMode") private var canvasSeatInfoModeRaw = SeatInfoDisplay.none.rawValue
    @AppStorage("canvasShowAgeMarkers") private var canvasShowAgeMarkers = false
    @AppStorage("canvasSeatChipContent") private var canvasSeatChipContentRaw = SeatChipContent.initials.rawValue
    @AppStorage("canvasShowTableWarnings") private var canvasShowTableWarnings = true
    @AppStorage("canvasShowRoomLabels") private var canvasShowRoomLabels = true
    @AppStorage("canvasShowLegend") private var canvasShowLegend = true
    @AppStorage("canvasSeatNameSize") private var canvasSeatNameSize: Double = 9
    @AppStorage("canvasShowCoupleMarker") private var canvasShowCoupleMarker = false

    @State private var highlightAllergies = true
    @State private var withWavePattern = true
    @State private var blackAndWhite = false

    @State private var format: ExportFormat = .pdf
    @State private var previewTab: PreviewTab = .sitzplan

    @State private var phoneVerify: [UUID: PhoneVerifyStatus] = [:]
    @State private var phoneVerifyRunning = false
    @State private var phoneVerifyError: String?
    @State private var mismatchQueue: [PendingMismatch] = []
    private var pendingMismatchBinding: Binding<PendingMismatch?> {
        Binding(
            get: { mismatchQueue.first },
            set: { _ in }
        )
    }

    enum PhoneVerifyStatus: Equatable {
        case verified(contactName: String)
        case nameMismatch(contactName: String)
        case notFound
        case failed(String)
    }

    struct PendingMismatch: Identifiable {
        let id: UUID
        let guest: Guest
        let suggestedName: String
    }

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

    enum PreviewTab: String, CaseIterable, Identifiable {
        case sitzplan = "Sitzplan"
        case caterer = "Caterer"
        case tischkarten = "Tischkarten"
        case plakat = "Plakat"
        case bildlich = "Bildlich"
        case telefon = "Telefon"
        var id: String { rawValue }
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
        VStack(spacing: 0) {
            previewTabBar
            ScrollView {
                VStack {
                    Spacer().frame(height: 32)
                    selectedPreview
                    Spacer().frame(height: 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Tokens.Colors.bg2)
    }

    private var previewTabBar: some View {
        HStack(spacing: 4) {
            ForEach(PreviewTab.allCases) { tab in
                Button {
                    previewTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(previewTab == tab ? Tokens.Colors.ink : Tokens.Colors.ink3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(previewTab == tab ? Tokens.Colors.accentTint : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Colors.line).frame(height: 1)
        }
    }

    @ViewBuilder
    private var selectedPreview: some View {
        switch previewTab {
        case .sitzplan: a4Preview
        case .caterer: catererPreview
        case .tischkarten: tischkartenPreview
        case .plakat: plakatPreview
        case .bildlich: bildlichPreview
        case .telefon: telefonPreview
        }
    }

    @ViewBuilder
    private var telefonPreview: some View {
        let stats = phoneCoverage(for: guests.filter(\.countsForSeating))

        VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Telefonnummern")
                        .font(.title2.bold())
                    Text("**\(stats.coveredRegistrations) von \(stats.totalRegistrations) Anmeldungen** haben mindestens eine Nummer (\(stats.guestsWithPhone) von \(stats.totalGuests) Gaesten).")
                        .foregroundStyle(.secondary)
                    Text("Rechts unter 'Was exportieren' das Haekchen bei 'Telefonnummern (vCard)' setzen und dann auf 'Exportieren'. Die .vcf laesst sich von der Trauzeugin in die Kontakte importieren — daraus dann in einem Rutsch eine WhatsApp-Gruppe.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if !stats.openRegistrations.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anmeldungen ohne Nummer (\(stats.openRegistrations.count))")
                            .font(.headline)
                        Text("Eine Nummer pro Anmeldung reicht — diese Gruppen brauchen noch jemanden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ForEach(stats.openRegistrations, id: \.self) { names in
                            Text(names)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !stats.withPhone.isEmpty {
                    phoneVerifySection(guests: stats.withPhone)
                }
        }
        .padding(24)
        .alert(item: pendingMismatchBinding) { mismatch in
            Alert(
                title: Text("Name aus Kontakten übernehmen?"),
                message: Text("Hier ist '\(mismatch.guest.fullName)' hinterlegt, in deinen Kontakten heisst die Nummer '\(mismatch.suggestedName)'."),
                primaryButton: .default(Text("Übernehmen")) {
                    applySuggestedName(mismatch.suggestedName, to: mismatch.guest)
                    phoneVerify[mismatch.guest.id] = .verified(contactName: mismatch.suggestedName)
                    dequeueMismatch()
                },
                secondaryButton: .cancel(Text("Behalten")) {
                    phoneVerify[mismatch.guest.id] = .nameMismatch(contactName: mismatch.suggestedName)
                    dequeueMismatch()
                }
            )
        }
    }

    @ViewBuilder
    private func phoneVerifySection(guests: [Guest]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Mit Nummer (\(guests.count))").font(.headline)
                Spacer()
                Button {
                    Task { await verifyAllPhones(guests) }
                } label: {
                    if phoneVerifyRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Mit Kontakten abgleichen", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
                .disabled(phoneVerifyRunning)
            }
            if let err = phoneVerifyError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            ForEach(guests) { guest in
                HStack(spacing: 8) {
                    phoneVerifyIcon(for: guest)
                    Text(guest.fullName)
                    Spacer()
                    Text(PhoneFormatter.display(guest.phoneNumber))
                        .monospaced()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func phoneVerifyIcon(for guest: Guest) -> some View {
        switch phoneVerify[guest.id] {
        case .verified:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .nameMismatch:
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .notFound:
            Image(systemName: "questionmark.circle").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "xmark.circle").foregroundStyle(.red)
        case .none:
            Image(systemName: "circle.dashed").foregroundStyle(.secondary.opacity(0.5))
        }
    }

    private func verifyAllPhones(_ guests: [Guest]) async {
        phoneVerifyError = nil
        phoneVerifyRunning = true
        defer { phoneVerifyRunning = false }
        do {
            guard try await ContactsService.requestAccess() else {
                phoneVerifyError = "Kein Zugriff auf Kontakte erteilt."
                return
            }
        } catch {
            phoneVerifyError = error.localizedDescription
            return
        }
        let index: [String: ContactMatch]
        do {
            index = try ContactsService.indexByPhone()
        } catch {
            phoneVerifyError = error.localizedDescription
            return
        }
        var queued: [PendingMismatch] = []
        for guest in guests {
            let result = lookupContact(for: guest, in: index)
            phoneVerify[guest.id] = result
            if case .nameMismatch(let suggested) = result {
                queued.append(PendingMismatch(id: guest.id, guest: guest, suggestedName: suggested))
            }
        }
        mismatchQueue = queued
    }

    private func lookupContact(for guest: Guest, in index: [String: ContactMatch]) -> PhoneVerifyStatus {
        let key = PhoneFormatter.normalize(guest.phoneNumber)
        guard !key.isEmpty, let match = index[key] else { return .notFound }
        return matchesGuestName(guest: guest, contact: match)
            ? .verified(contactName: match.displayName)
            : .nameMismatch(contactName: match.displayName)
    }

    private func dequeueMismatch() {
        if !mismatchQueue.isEmpty { mismatchQueue.removeFirst() }
    }

    private func matchesGuestName(guest: Guest, contact: ContactMatch) -> Bool {
        func fold(_ s: String) -> String {
            s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
                .trimmingCharacters(in: .whitespaces)
        }
        let guestFirst = fold(guest.firstName)
        let firstOK = [contact.givenName, contact.nickname]
            .filter { !$0.isEmpty }
            .contains { fold($0) == guestFirst }
        guard firstOK else { return false }
        if guest.lastName.isEmpty || contact.familyName.isEmpty { return true }
        return fold(contact.familyName) == fold(guest.lastName)
    }

    private func applySuggestedName(_ suggested: String, to guest: Guest) {
        let parts = suggested.split(separator: " ", maxSplits: 1).map(String.init)
        guard let first = parts.first else { return }
        guest.firstName = first
        guest.lastName = parts.count > 1 ? parts[1] : ""
    }

    private struct PhoneCoverage {
        let totalGuests: Int
        let guestsWithPhone: Int
        let totalRegistrations: Int
        let coveredRegistrations: Int
        let openRegistrations: [String]
        let withPhone: [Guest]
    }

    private func phoneCoverage(for guests: [Guest]) -> PhoneCoverage {
        func hasPhone(_ g: Guest) -> Bool {
            !g.phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty
        }

        // Gruppen-Bucket: registrationGroup oder fallback auf eigene Gast-ID
        // (Einzelpersonen ohne Anmeldungs-Gruppe zaehlen als eigene Anmeldung).
        var buckets: [String: [Guest]] = [:]
        for g in guests {
            let key = g.registrationGroup?.uuidString ?? "single-\(g.id.uuidString)"
            buckets[key, default: []].append(g)
        }

        let total = buckets.count
        var covered = 0
        var open: [String] = []
        for (_, members) in buckets {
            if members.contains(where: hasPhone) {
                covered += 1
            } else {
                let label = members
                    .sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
                    .map(\.fullName)
                    .joined(separator: " & ")
                open.append(label)
            }
        }

        return PhoneCoverage(
            totalGuests: guests.count,
            guestsWithPhone: guests.filter(hasPhone).count,
            totalRegistrations: total,
            coveredRegistrations: covered,
            openRegistrations: open.sorted(),
            withPhone: guests.filter(hasPhone).sorted { $0.fullName.localizedCompare($1.fullName) == .orderedAscending }
        )
    }

    @ViewBuilder
    private var catererPreview: some View {
        let summary = CatererSummary(tables: tables)

        VStack(alignment: .leading, spacing: 16) {
            Text("Übersicht für den Caterer")
                .font(Tokens.Typography.displayXS)
                .foregroundStyle(Tokens.Colors.ink)
                .padding(.bottom, 8)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(summary.dietCounts, id: \.choice) { diet in
                    HStack {
                        Text(diet.choice).font(.system(size: 12, design: .rounded))
                        Spacer()
                        Text("\(diet.count)").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                }
                HStack {
                    Text("Gesamt Essen").font(.system(size: 12, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(summary.totalMeals)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Divider().padding(.vertical, 2)
                ForEach(summary.ageCounts, id: \.category) { age in
                    HStack {
                        Text(age.category.rawValue).font(.system(size: 12, design: .rounded))
                        Spacer()
                        Text("\(age.count)").font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                    }
                }
                HStack {
                    Text("Gesamt Personen").font(.system(size: 12, weight: .semibold, design: .rounded))
                    Spacer()
                    Text("\(summary.totalPersons)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
            if !summary.intolerant.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Unverträglichkeiten")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                ForEach(summary.intolerant) { g in
                    HStack(alignment: .top) {
                        Text(g.fullName).font(.system(size: 12, weight: .medium, design: .rounded))
                        Spacer()
                        Text(g.intolerances.joined(separator: ", "))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Tokens.Colors.error)
                    }
                }
            }
            if !summary.changes.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Späte Absagen — Plätze bleiben leer")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                let removed = summary.removedDietCounts
                    .map { "−\($0.count) \($0.choice)" }
                    .joined(separator: ", ")
                if !removed.isEmpty {
                    Text("Wegfall: \(removed)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.error)
                }
                ForEach(Array(summary.changes.enumerated()), id: \.offset) { _, change in
                    HStack(alignment: .top) {
                        Text("\(change.name) · \(change.tableName)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                        Spacer()
                        let detail = CatererSummary.changeDetail(change)
                        if !detail.isEmpty {
                            Text(detail)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Tokens.Colors.ink3)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(36)
        .frame(width: 480, height: 660, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .shadow(color: Color.black.opacity(0.16), radius: 32, x: 0, y: 8)
    }

    @ViewBuilder
    private var tischkartenPreview: some View {
        let sample = tables.flatMap(\.attendingGuests).first
        VStack(spacing: 16) {
            Text("Tischkarten · Vorschau für eine Karte")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(1)
            if let g = sample {
                VStack(spacing: 14) {
                    Text(g.fullName)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                    Rectangle().fill(Color(hex: "#c47a8c")).frame(width: 40, height: 1.2)
                    if !g.funFactDisplay.isEmpty {
                        Text(g.funFactDisplay)
                            .font(.system(size: 11, weight: .regular, design: .rounded).italic())
                            .foregroundStyle(Tokens.Colors.ink3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .frame(width: 240, height: 160)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
                Text("Im Druck: 8 Karten pro A4-Seite mit Schnitt-Eckmarken.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            } else {
                Text("Noch keine Gäste platziert.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
            }
        }
        .frame(width: 480, height: 660)
        .background(Tokens.Colors.bg)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private var plakatPreview: some View {
        VStack(spacing: 12) {
            Text("Plakat · A3-Querformat")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(1)
            ZStack {
                ForEach(tables) { t in
                    Circle()
                        .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                        .background(Circle().fill(t.isBridalTable ? Tokens.Colors.accentTint : Color.white))
                        .frame(width: 28, height: 28)
                        .overlay(Text(String(t.name.prefix(2))).font(.system(size: 8, weight: .semibold, design: .rounded)))
                        .position(
                            x: t.positionX * 0.4 + 240,
                            y: t.positionY * 0.4 + 200
                        )
                }
            }
            .frame(width: 480, height: 400)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            Text("Tische in Mini-Ansicht. Im Druck: A3 mit voller Größe.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
        }
        .frame(width: 480, height: 660)
    }

    @ViewBuilder
    private var bildlichPreview: some View {
        VStack(spacing: 12) {
            Text("Bildlicher Sitzplan · A3-Querformat")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(1)
            ZStack {
                ForEach(tables) { t in
                    Group {
                        if t.shape == .round {
                            Circle()
                                .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                                .background(Circle().fill(t.isBridalTable ? Tokens.Colors.accentTint : Color.white))
                                .frame(width: max(t.diameter * 0.18, 22), height: max(t.diameter * 0.18, 22))
                        } else {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .strokeBorder(Tokens.Colors.line2, lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(t.isBridalTable ? Tokens.Colors.accentTint : Color.white))
                                .frame(width: max(t.width * 0.18, 22), height: max(t.depth * 0.18, 14))
                        }
                    }
                    .overlay(Text("\(t.attendingGuests.count)").font(.system(size: 8, weight: .semibold, design: .rounded)))
                    .rotationEffect(.degrees(t.rotation))
                    .position(
                        x: t.positionX * 0.4 + 240,
                        y: t.positionY * 0.4 + 200
                    )
                }
            }
            .frame(width: 480, height: 400)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
            Text("Belegung pro Tisch. Im PDF: Vornamen direkt an den Sitzpositionen.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
        }
        .frame(width: 480, height: 660)
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
        return "\(table.attendingGuests.count) \(table.attendingGuests.count == 1 ? "Gast" : "Gäste")"
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

            ForEach(table.attendingGuests) { guest in
                HStack {
                    Text(guest.fullName)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(guest.dietaryChoice)
                        .font(.system(size: 12, design: .rounded))
                        .frame(width: 100, alignment: .leading)
                    Text(guest.intolerances.first ?? "—")
                        .font(.system(size: 12, weight: highlightAllergies && guest.hasIntolerances ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(highlightAllergies && guest.hasIntolerances ? Tokens.Colors.error : Color.gray)
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
            Text("\(table.name) — \(table.capacity) Plätze, \(table.attendingGuests.count) belegt")
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

    // MARK: - Run export

    private struct ExportItem {
        let filename: String
        let data: Data
    }

    private func runExport() {
        guard let event else { return }

        let safeName = sanitizeFilenameSegment(event.name)

        var items: [ExportItem] = []
        if includeTableLists || includeCatererSummary {
            let opts = PDFExporter.Options(
                includeTableLists: includeTableLists,
                includeCatererSummary: includeCatererSummary,
                highlightAllergies: highlightAllergies,
                blackAndWhite: blackAndWhite
            )
            items.append(ExportItem(filename: "Sitzplan-\(safeName).pdf",
                                    data: PDFExporter.generatePDF(tables: tables, eventName: event.name,
                                                                  date: event.date, options: opts,
                                                                  partner1Name: event.partner1Name,
                                                                  partner2Name: event.partner2Name)))
        }
        if includeTableCards {
            items.append(ExportItem(filename: "Tischkarten-\(safeName).pdf",
                                    data: TableCardExporter.generatePDF(guests: guests.filter(\.countsForSeating),
                                                                        eventName: event.name,
                                                                        withTitle: tableCardsWithTitle)))
        }
        if includePoster {
            items.append(ExportItem(filename: "Plakat-\(safeName).pdf",
                                    data: PosterExporter.generatePDF(
                                        tables: tables,
                                        unassignedGuests: guests.filter { $0.countsForSeating && $0.table == nil },
                                        eventName: event.name,
                                        date: event.date)))
        }
        if includeVisualPlan {
            let style = VisualSeatingPlanExporter.NameStyle(rawValue: visualPlanNameStyleRaw) ?? .smartDeduped
            items.append(ExportItem(filename: "Bildlicher-Sitzplan-\(safeName).pdf",
                                    data: VisualSeatingPlanExporter.generatePDF(
                                        tables: tables, eventName: event.name,
                                        date: event.date, nameStyle: style)))
        }
        if includeGameCards {
            items.append(ExportItem(filename: "FunFact-Spielkarten-\(safeName).pdf",
                                    data: FunFactGameCardsExporter.generatePDF(guests: guests, eventName: event.name)))
        }
        if includePhoneVCards {
            items.append(ExportItem(filename: "Telefonnummern-\(safeName).vcf",
                                    data: PhoneVCardExporter.generate(guests: guests.filter(\.countsForSeating), eventName: event.name)))
        }
        if includeSpeechGuests {
            items.append(ExportItem(filename: "Gaeste-Rede-\(safeName).md",
                                    data: SpeechGuestExporter.generate(guests: guests, tags: tags, event: event)))
        }
        if includeCanvasPNG {
            let style = VisualSeatingPlanExporter.NameStyle(rawValue: canvasSeatNameStyleRaw) ?? .full
            let names = canvasShowSeatNames
                ? VisualSeatingPlanExporter.displayNames(for: tables.flatMap(\.attendingGuests), style: style)
                : [:]
            let bg = event.roomPlanImageData.flatMap { NSImage(data: $0) }
            let infoMode = SeatInfoDisplay(rawValue: canvasSeatInfoModeRaw) ?? .none
            let chipContent = SeatChipContent(rawValue: canvasSeatChipContentRaw) ?? .initials
            let legend = SeatingLegend(guests: tables.flatMap(\.attendingGuests))
            if let png = CanvasImageExporter.generatePNG(
                tables: tables,
                displayNames: names,
                rules: event.seatingRules,
                scale: CGFloat(lastCanvasScale),
                labels: event.labels,
                background: bg,
                showSeatNames: canvasShowSeatNames,
                infoDisplay: infoMode,
                showAgeMarkers: canvasShowAgeMarkers,
                chipContent: chipContent,
                showTableWarnings: canvasShowTableWarnings,
                showRoomLabels: canvasShowRoomLabels,
                showLegend: canvasShowLegend,
                legend: legend,
                nameFontSize: CGFloat(canvasSeatNameSize),
                showCoupleMarker: canvasShowCoupleMarker,
                coupleNames: [event.partner1Name, event.partner2Name]
            ) {
                items.append(ExportItem(filename: "Sitzplan-Canvas-\(safeName).png", data: png))
            }
        }

        guard !items.isEmpty else { return }
        saveBatch(items, eventName: safeName)
    }

    /// Entfernt Path-Separator und andere Zeichen die im Dateisystem
    /// problematisch sind (`/`, `:` auf macOS, plus Backslash für Cross-OS).
    private func sanitizeFilenameSegment(_ raw: String) -> String {
        let invalid: [Character] = ["/", ":", "\\"]
        let cleaned = String(raw.map { invalid.contains($0) ? "-" : $0 })
        let trimmed = cleaned.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Export" : trimmed
    }

    private func saveBatch(_ items: [ExportItem], eventName: String) {
        if items.count == 1, let only = items.first {
            saveSingle(data: only.data, name: only.filename)
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.title = "Zielordner waehlen"
        panel.message = "Alle Exporte werden in einen neuen Unterordner geschrieben."
        panel.prompt = "Exportieren"

        panel.begin { response in
            guard response == .OK, let parent = panel.url else { return }
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd-HHmm"
            // eventName kommt bereits sanitized rein
            let folderName = "Export-\(eventName)-\(fmt.string(from: .now))"
            let target = parent.appendingPathComponent(folderName, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
                for item in items {
                    let fileURL = target.appendingPathComponent(item.filename)
                    try item.data.write(to: fileURL)
                }
                NSWorkspace.shared.activateFileViewerSelecting([target])
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func saveSingle(data: Data, name: String) {
        let panel = NSSavePanel()
        let suffix = (name as NSString).pathExtension.lowercased()
        let type: UTType = suffix == "vcf" ? .vCard : (suffix == "png" ? .png : .pdf)
        panel.allowedContentTypes = [type]
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
