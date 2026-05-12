#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct SaalKonfiguratorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Guest.firstName) private var guests: [Guest]
    @Query private var tags: [Tag]
    @Query private var constraints: [Constraint]
    @Query private var existingTables: [GuestTable]
    @Query private var events: [Event]

    @State private var inventory = SaalInventar()
    @State private var proposal: SaalProposal?
    @State private var isGenerating = false
    @State private var isAssigning = false
    @State private var errorMessage: String?
    @State private var alsoAssignGuests = true
    @State private var assignmentSummary: String?

    private var seatingNeed: Int {
        guests.filter { $0.ageCategory.needsSeat }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().background(Tokens.Colors.line)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if proposal == nil {
                        inputStage
                    } else {
                        reviewStage
                    }
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            if proposal != nil {
                Divider().background(Tokens.Colors.line)
                applyBar
            }
        }
        .frame(minWidth: 760, minHeight: 640)
        .background(Tokens.Colors.bg)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Saal-Konfigurator")
                    .font(Tokens.Typography.display(size: 22))
                    .foregroundStyle(Tokens.Colors.ink)
                Text("Sag was ihr buchen könnt — die KI schlägt eine Tisch-Konfiguration für eure \(seatingNeed) Sitzplätze vor.")
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

    @ViewBuilder
    private var inputStage: some View {
        capacityHeader
        roundTablesSection
        rectangularTablesSection
        specialTablesSection
        if let errorMessage {
            errorBanner(errorMessage)
        }
        actionRow
        tipBlock
    }

    private var capacityHeader: some View {
        HStack(spacing: 16) {
            statBlock(label: "Gäste mit Sitzplatz", value: "\(seatingNeed)")
            statBlock(label: "Max. Kapazität laut Inventar", value: "\(inventory.maxTotalCapacity)")
            statBlock(
                label: capacitySurplusLabel,
                value: capacitySurplusValue,
                accent: capacitySurplusAccent
            )
            Spacer(minLength: 0)
        }
    }

    private var capacitySurplusLabel: String {
        inventory.maxTotalCapacity >= seatingNeed ? "Reserve" : "Es fehlen Plätze"
    }

    private var capacitySurplusValue: String {
        let diff = inventory.maxTotalCapacity - seatingNeed
        return diff >= 0 ? "+\(diff)" : "\(diff)"
    }

    private var capacitySurplusAccent: Color {
        inventory.maxTotalCapacity >= seatingNeed ? Tokens.Colors.sage : Tokens.Colors.warn
    }

    private func statBlock(label: String, value: String, accent: Color = Tokens.Colors.accent) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
            Text(value)
                .font(Tokens.Typography.display(size: 22))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Tokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var roundTablesSection: some View {
        configRow(
            title: "Runde Tische",
            subtitle: "\(inventory.roundCapacityEach) Plätze pro Tisch · gesamt bis \(inventory.roundMaxCount * inventory.roundCapacityEach)"
        ) {
            HStack(spacing: 10) {
                stepperField(label: "Anzahl", value: $inventory.roundMaxCount, range: 0...30)
                doubleField(label: "Durchmesser (cm)", value: $inventory.roundDiameterCM)
                Spacer()
            }
        }
    }

    private var rectangularTablesSection: some View {
        configRow(
            title: "Rechteckige Tafeln",
            subtitle: "\(inventory.rectCapacityEach) Plätze pro Tafel · gesamt bis \(inventory.rectangularMaxCount * inventory.rectCapacityEach)"
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    stepperField(label: "Anzahl", value: $inventory.rectangularMaxCount, range: 0...20)
                    doubleField(label: "Breite (cm)", value: $inventory.rectangularWidthCM)
                    doubleField(label: "Tiefe (cm)", value: $inventory.rectangularDepthCM)
                    Spacer()
                }
                stepperField(label: "Max. Tische pro Tafel", value: $inventory.rectangularMaxTafelLength, range: 1...8)
            }
        }
    }

    private var specialTablesSection: some View {
        configRow(
            title: "Spezialtische",
            subtitle: "Brauttafel und Kindertisch werden falls aktiviert garantiert vorgeschlagen."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Toggle("Brauttafel separat", isOn: $inventory.withSeparateBridalTable)
                        .toggleStyle(.switch)
                    if inventory.withSeparateBridalTable {
                        doubleField(label: "Breite (cm)", value: $inventory.bridalTableWidthCM)
                        doubleField(label: "Tiefe (cm)", value: $inventory.bridalTableDepthCM)
                        Text("\(inventory.bridalCapacity) Plätze")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    Spacer()
                }
                HStack {
                    Toggle("Kindertisch separat", isOn: $inventory.withChildTable)
                        .toggleStyle(.switch)
                    if inventory.withChildTable {
                        doubleField(label: "Kantenlänge (cm)", value: $inventory.childTableWidthCM)
                        Text("\(inventory.childCapacity) Plätze")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink3)
                    }
                    Spacer()
                }
            }
        }
    }

    private var actionRow: some View {
        HStack {
            Spacer()
            Button {
                Task { await generate() }
            } label: {
                HStack(spacing: 6) {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isGenerating ? "KI plant…" : "Vorschlag generieren")
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Tokens.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isGenerating || inventory.maxTotalCapacity < 1)
        }
    }

    private var tipBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("So denkt die KI")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.6)
            Text("Sie nutzt eure Familienrollen, registrierten Anmeldungs-Gruppen und Tags. Großfamilien und Tafeln werden bevorzugt zusammengehalten, Freundeskreise auf passende Rundtische verteilt. Die Empfehlung kommt mit Begründung pro Tisch — du kannst sie übernehmen oder verwerfen und neu rechnen lassen.")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tokens.Colors.warn)
            Text(message)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.warn.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var reviewStage: some View {
        if let proposal {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(proposal.tables.count) Tische empfohlen · \(proposal.totalCapacity) Plätze")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    if !proposal.reasoning.isEmpty {
                        Text(proposal.reasoning)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Tokens.Colors.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Button("Neu rechnen") {
                    self.proposal = nil
                }
                .buttonStyle(.plain)
                .font(.system(size: 12.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.accent)
            }

            ForEach(proposal.tables) { table in
                proposedTableCard(table)
            }
        }
    }

    private func proposedTableCard(_ table: ProposedTable) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                tableShapeBadge(table)
                VStack(alignment: .leading, spacing: 2) {
                    Text(table.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink)
                    Text(tableSizeLine(table))
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
                Spacer()
                Text("\(table.capacity) Pl.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Tokens.Colors.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Tokens.Colors.accentSoft)
                    .clipShape(Capsule())
                if table.isBridal {
                    Image(systemName: "heart.fill").foregroundStyle(Tokens.Colors.accent)
                }
                if table.isChild {
                    Image(systemName: "figure.child").foregroundStyle(Tokens.Colors.ink2)
                }
            }
            if !table.reason.isEmpty {
                Text(table.reason)
                    .font(.system(size: 11.5, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !table.clusters.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Tokens.Colors.ink3)
                    Text(table.clusters.joined(separator: " · "))
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Tokens.Colors.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tableShapeBadge(_ table: ProposedTable) -> some View {
        Group {
            switch table.shape {
            case .round:
                Circle().fill(Tokens.Colors.accentTint)
                    .overlay(Circle().strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.2))
            case .rectangular:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Tokens.Colors.accentTint)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.2))
                    .frame(width: 36, height: 18)
            case .square:
                RoundedRectangle(cornerRadius: 4)
                    .fill(Tokens.Colors.accentTint)
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Tokens.Colors.accentSoft, lineWidth: 1.2))
            }
        }
        .frame(width: 26, height: 26)
    }

    private func tableSizeLine(_ table: ProposedTable) -> String {
        switch table.shape {
        case .round: return "\(Int(table.diameterCM)) cm Ø"
        case .rectangular: return "\(Int(table.widthCM))×\(Int(table.depthCM)) cm"
        case .square: return "\(Int(table.widthCM))×\(Int(table.widthCM)) cm"
        }
    }

    private var applyBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summary = assignmentSummary {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Tokens.Colors.sage)
                    Text(summary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink2)
                }
            }
            HStack {
                if let proposal {
                    Text("\(proposal.tables.count) Tische anlegen — bestehende bleiben erhalten.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("Gäste auch direkt verteilen", isOn: $alsoAssignGuests)
                    .toggleStyle(.switch)
                    .font(.system(size: 11.5, design: .rounded))
                    .disabled(isAssigning)
                Button {
                    Task { await applyAndMaybeAssign() }
                } label: {
                    HStack(spacing: 6) {
                        if isAssigning { ProgressView().controlSize(.small) }
                        Text(applyButtonTitle)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Tokens.Colors.accent)
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .disabled(isAssigning)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Tokens.Colors.surface)
    }

    private var applyButtonTitle: String {
        if isAssigning { return "Verteile Gäste…" }
        return alsoAssignGuests ? "Tische anlegen + Gäste verteilen" : "Nur Tische anlegen"
    }

    @ViewBuilder
    private func configRow<Content: View>(title: String, subtitle: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(Tokens.Colors.ink3)
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Colors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 10).strokeBorder(Tokens.Colors.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func stepperField(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, design: .rounded)).foregroundStyle(Tokens.Colors.ink3)
            HStack(spacing: 6) {
                TextField("0", value: value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                Stepper("", value: value, in: range)
                    .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private func doubleField(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, design: .rounded)).foregroundStyle(Tokens.Colors.ink3)
            TextField("0", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
                .font(.system(size: 12.5, design: .rounded))
        }
    }

    @MainActor
    private func generate() async {
        errorMessage = nil
        isGenerating = true
        defer { isGenerating = false }

        let client = LLMClientFactory.makeFromSettings()
        if let lm = client as? LMStudioClient {
            do {
                _ = try await lm.checkConnection()
            } catch {
                errorMessage = "LM Studio nicht erreichbar — bitte starten und Modell laden."
                return
            }
        }

        let clusterContext = GroupAnalyzer.buildLLMContext(
            guests: guests,
            tags: tags,
            constraints: constraints,
            tables: existingTables,
            event: events.first
        )

        let service = SaalKonfigurator(client: client)
        do {
            let result = try await service.propose(
                inventory: inventory,
                guestCount: guests.count,
                seatingNeed: seatingNeed,
                clusterContext: clusterContext
            )
            if result.tables.isEmpty {
                errorMessage = "Die KI hat keinen verwertbaren Vorschlag geliefert. Empfehlung: gemma-3-12b in LM Studio aktivieren."
            } else {
                proposal = result
            }
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func applyAndMaybeAssign() async {
        guard let proposal else { return }
        let createdTables = insertProposedTables(proposal.tables)
        try? modelContext.save()

        guard alsoAssignGuests else {
            dismiss()
            return
        }

        isAssigning = true
        defer { isAssigning = false }

        let plannerTables = mergedTables(existing: existingTables, created: createdTables)
        let client = LLMClientFactory.makeFromSettings()
        let context = LLMSeatingPlanner.PlannerContext(
            guests: guests,
            tables: plannerTables,
            tags: tags,
            constraints: constraints
        )

        do {
            let plan = try await LLMSeatingPlanner.requestPlan(client: client, context: context)
            applyAssignments(plan.assignments, in: plannerTables)
            try? modelContext.save()
            assignmentSummary = "Tische angelegt. \(plan.assignments.count) Gäste verteilt. Du kannst im Sitzplan nachjustieren."
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            dismiss()
        } catch {
            errorMessage = "Tische sind angelegt, aber die Gäste-Verteilung ist fehlgeschlagen: \(error.localizedDescription). Du kannst die Verteilung im KI-Assistenten neu starten."
        }
    }

    private func mergedTables(existing: [GuestTable], created: [GuestTable]) -> [GuestTable] {
        var seen = Set<UUID>()
        var result: [GuestTable] = []
        for t in existing + created where !seen.contains(t.id) {
            seen.insert(t.id)
            result.append(t)
        }
        return result
    }

    private func insertProposedTables(_ specs: [ProposedTable]) -> [GuestTable] {
        let baseIndex = existingTables.count
        var created: [GuestTable] = []
        var groupIDs: [String: UUID] = [:]
        var groupAnchors: [String: (x: Double, y: Double)] = [:]
        var groupCursorOffset: [String: Double] = [:]
        var soloIndex = baseIndex

        for spec in specs {
            let table = GuestTable(
                name: spec.name,
                shape: spec.shape,
                diameter: spec.shape == .round ? spec.diameterCM : 0,
                width: spec.shape == .round ? 0 : spec.widthCM,
                depth: spec.shape == .round ? 0 : spec.depthCM,
                positionX: 0,
                positionY: 0,
                isChildTable: spec.isChild,
                isBridalTable: spec.isBridal
            )

            if let group = spec.tafelGroup, let order = spec.tafelOrder {
                let groupID = groupIDs[group] ?? UUID()
                groupIDs[group] = groupID
                table.combinationGroup = groupID
                table.combinationOrder = order

                if order == 0 {
                    let anchor = nextGridPosition(for: soloIndex)
                    groupAnchors[group] = anchor
                    table.positionX = anchor.x
                    table.positionY = anchor.y
                    groupCursorOffset[group] = spec.widthCM / 2
                    soloIndex += 1
                } else {
                    let anchor = groupAnchors[group] ?? nextGridPosition(for: soloIndex)
                    let prevRightEdge = groupCursorOffset[group] ?? 0
                    table.positionX = anchor.x + prevRightEdge + spec.widthCM / 2
                    table.positionY = anchor.y
                    groupCursorOffset[group] = prevRightEdge + spec.widthCM
                }
            } else {
                let pos = nextGridPosition(for: soloIndex)
                table.positionX = pos.x
                table.positionY = pos.y
                soloIndex += 1
            }

            modelContext.insert(table)
            created.append(table)
        }

        // Tafel-Members nachträglich um Owner-Mittelpunkt zentrieren
        let tafelMembers = created.filter { $0.combinationGroup != nil }
        let groupedByID = Dictionary(grouping: tafelMembers, by: { $0.combinationGroup! })
        for (_, members) in groupedByID {
            let totalWidth = members.reduce(0.0) { $0 + $1.width }
            guard let owner = members.first(where: { ($0.combinationOrder ?? 0) == 0 }) else { continue }
            let shift = -totalWidth / 2 + owner.width / 2
            for m in members {
                m.positionX += shift
            }
        }

        return created
    }

    private func applyAssignments(_ assignments: [UUID: UUID], in tablePool: [GuestTable]) {
        let tablesByID = Dictionary(uniqueKeysWithValues: tablePool.map { ($0.id, $0) })
        for (guestID, tableID) in assignments {
            guard let guest = guests.first(where: { $0.id == guestID }),
                  let table = tablesByID[tableID],
                  !guest.isPinned else { continue }
            guest.table = table
        }
    }

    private func nextGridPosition(for index: Int) -> (x: Double, y: Double) {
        let cols = 4
        let spacing: Double = 160
        let col = index % cols
        let row = index / cols
        return (Double(col) * spacing + 80, Double(row) * spacing + 80)
    }
}
#endif
