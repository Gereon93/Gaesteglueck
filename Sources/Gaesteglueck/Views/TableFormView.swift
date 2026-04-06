#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct TableFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let table: GuestTable?

    @State private var name: String
    @State private var shape: TableShape
    @State private var diameter: Double
    @State private var width: Double
    @State private var depth: Double

    init(table: GuestTable? = nil) {
        self.table = table
        _name = State(initialValue: table?.name ?? "")
        _shape = State(initialValue: table?.shape ?? .round)
        _diameter = State(initialValue: table?.diameter ?? 180)
        _width = State(initialValue: table?.width ?? 200)
        _depth = State(initialValue: table?.depth ?? 100)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var previewCapacity: Int {
        let preview = GuestTable(name: "", shape: shape, diameter: diameter, width: width, depth: depth)
        return preview.capacity
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tisch") {
                    TextField("Name (z.B. Tisch 1)", text: $name)
                    Picker("Form", selection: $shape) {
                        ForEach(TableShape.allCases) { shape in
                            Label(shape.rawValue, systemImage: shape.icon).tag(shape)
                        }
                    }
                }
                Section("Maße (cm)") {
                    switch shape {
                    case .round:
                        HStack {
                            Text("Durchmesser")
                            Slider(value: $diameter, in: 100...300, step: 10)
                            Text("\(Int(diameter)) cm")
                                .monospacedDigit()
                                .frame(width: 60)
                        }
                    case .rectangular, .square:
                        HStack {
                            Text("Breite")
                            Slider(value: $width, in: 100...600, step: 10)
                            Text("\(Int(width)) cm")
                                .monospacedDigit()
                                .frame(width: 60)
                        }
                        HStack {
                            Text("Tiefe")
                            Slider(value: $depth, in: 60...200, step: 10)
                            Text("\(Int(depth)) cm")
                                .monospacedDigit()
                                .frame(width: 60)
                        }
                    }
                }
                Section {
                    HStack {
                        Text("Berechnete Kapazität")
                        Spacer()
                        Text("\(previewCapacity) Plätze")
                            .bold()
                    }
                }
            }
            .navigationTitle(table == nil ? "Tisch erstellen" : "Tisch bearbeiten")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        if let table {
            table.name = name.trimmingCharacters(in: .whitespaces)
            table.shape = shape
            table.diameter = diameter
            table.width = width
            table.depth = depth
        } else {
            let newTable = GuestTable(
                name: name.trimmingCharacters(in: .whitespaces),
                shape: shape,
                diameter: diameter,
                width: width,
                depth: depth,
                positionX: 500,
                positionY: 400
            )
            modelContext.insert(newTable)
        }
        dismiss()
    }
}
#endif
