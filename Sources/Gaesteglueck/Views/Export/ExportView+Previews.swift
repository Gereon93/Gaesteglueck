#if os(macOS)
#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData
import AppKit

// MARK: - Per-Format-Vorschauen
//
// Computed Properties / Helfer für die einzelnen Vorschau-Tabs. Liegen als
// Extension auf ExportView, damit sie ohne Binding-Durchreichung direkt auf
// die @Query- und @State-Properties des Parents zugreifen.
extension ExportView {

    @ViewBuilder
    var catererPreview: some View {
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
    var tischkartenPreview: some View {
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
    var plakatPreview: some View {
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
    var bildlichPreview: some View {
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
    var a4Preview: some View {
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

    func headerSubline(_ event: Event) -> String {
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

    func tableSubtitle(_ table: GuestTable) -> String {
        // Subtitle ist die reine Gäste-Anzahl. Frühere Versionen hatten eine
        // Tag-basierte Sub-Beschriftung, die ist aber nicht mehr aktiv —
        // toter Branch entfernt.
        return "\(table.attendingGuests.count) \(table.attendingGuests.count == 1 ? "Gast" : "Gäste")"
    }

    func tableContents(table: GuestTable) -> some View {
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

    func footerLine(event: Event, table: GuestTable) -> some View {
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

    func footerStandLine(event: Event) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.locale = Locale(identifier: "de_DE")
        return "Stand: \(fmt.string(from: .now))"
    }
}
#endif
#endif
