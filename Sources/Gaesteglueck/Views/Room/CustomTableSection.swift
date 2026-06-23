#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Eigener Tisch — eigene Maße statt Template. Teil der Bibliothek links.
struct CustomTableSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GuestTable.name) private var tables: [GuestTable]

    @State private var customShape: TableShape = .round
    @State private var customDiameter: String = "150"
    @State private var customWidth: String = "180"
    @State private var customDepth: String = "90"
    @State private var customName: String = ""
    @State private var customIsBridal: Bool = false
    @State private var customIsChild: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EIGENER TISCH")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
                .tracking(0.5)
                .padding(.horizontal, 6)
                .padding(.top, 4)

            VStack(spacing: 8) {
                Picker("Form", selection: $customShape) {
                    ForEach(TableShape.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)

                if customShape == .round {
                    customField(label: "Durchmesser (cm)", value: $customDiameter)
                } else {
                    HStack(spacing: 6) {
                        customField(label: "Breite (cm)", value: $customWidth)
                        customField(label: "Tiefe (cm)", value: $customDepth)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.system(size: 10))
                    Text("Plätze: \(customComputedCapacity) (60 cm pro Platz)")
                        .font(.system(size: 11, design: .rounded))
                }
                .foregroundStyle(Tokens.Colors.ink3)
                .frame(maxWidth: .infinity, alignment: .leading)

                customField(label: "Name (optional)", value: $customName, isNumeric: false, placeholder: nameForCustomTable())

                Toggle("Brautpaartisch", isOn: $customIsBridal)
                    .font(.system(size: 11.5, design: .rounded))
                Toggle("Kindertisch", isOn: $customIsChild)
                    .font(.system(size: 11.5, design: .rounded))

                Button {
                    addCustomTable()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Tisch hinzufügen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .warmButton(.primary, size: .sm)
                .disabled(!customTableValid)
            }
            .padding(10)
            .background(Tokens.Colors.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Tokens.Colors.line, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
    }

    @ViewBuilder
    private func customField(label: String, value: Binding<String>, isNumeric: Bool = true, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(Tokens.Colors.ink3)
            TextField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var customTableValid: Bool {
        switch customShape {
        case .round:
            return Double(customDiameter).map { $0 > 0 } ?? false
        case .rectangular, .square:
            let w = Double(customWidth) ?? 0
            let d = Double(customDepth) ?? 0
            return w > 0 && d > 0
        }
    }

    /// Live-Preview der Kapazität wie sie GuestTable.capacity berechnen würde.
    /// 60 cm pro Sitzplatz, Rechtecke bekommen 2 Plätze Abzug für die Schmalseiten.
    private var customComputedCapacity: Int {
        let seatWidth: Double = 60
        switch customShape {
        case .round:
            let dia = Double(customDiameter) ?? 0
            guard dia > 0 else { return 0 }
            return Int(Double.pi * dia / seatWidth)
        case .rectangular:
            let w = Double(customWidth) ?? 0
            let d = Double(customDepth) ?? 0
            let perimeter = 2 * (w + d)
            return max(Int(perimeter / seatWidth) - 2, 4)
        case .square:
            let w = Double(customWidth) ?? 0
            return Int(4 * w / seatWidth)
        }
    }

    private func nameForCustomTable() -> String {
        let nextNumber = tables.count + 1
        if customIsBridal { return "Brauttafel" }
        if customIsChild { return "Kindertisch" }
        switch customShape {
        case .rectangular: return "Tafel \(nextNumber)"
        case .square: return "Tisch \(nextNumber)"
        case .round: return "T\(nextNumber)"
        }
    }

    private func addCustomTable() {
        let name = customName.trimmingCharacters(in: .whitespaces).isEmpty
            ? nameForCustomTable()
            : customName.trimmingCharacters(in: .whitespaces)
        let dia = Double(customDiameter) ?? 0
        let w = Double(customWidth) ?? 0
        let d = Double(customDepth) ?? 0
        let position = RoomTableActions.nextPosition(tableCount: tables.count)
        // Kapazität ergibt sich aus den Maßen (siehe GuestTable.capacity).
        // Wer mehr Plätze braucht muss die Maße anpassen.
        let table = GuestTable(
            name: name,
            shape: customShape,
            diameter: customShape == .round ? dia : 0,
            width: customShape == .round ? 0 : w,
            depth: customShape == .round ? 0 : d,
            positionX: position.x,
            positionY: position.y,
            isChildTable: customIsChild,
            isBridalTable: customIsBridal
        )
        modelContext.insert(table)
        customName = ""
        customIsBridal = false
        customIsChild = false
    }
}
#endif
