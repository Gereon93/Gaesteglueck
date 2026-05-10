#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct CanvasLabelView: View {
    @Bindable var label: CanvasLabel
    @Environment(\.modelContext) private var modelContext
    @State private var dragOffset: CGSize = .zero
    @State private var isEditing: Bool = false
    @State private var editText: String = ""

    var body: some View {
        Group {
            if isEditing {
                TextField("Text", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 140)
                    .onSubmit { commitEdit() }
            } else {
                Text(label.text)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Tokens.Colors.ink3)
                    .tracking(0.5)
            }
        }
        .rotationEffect(.degrees(label.rotation))
        .position(
            x: label.positionX + dragOffset.width,
            y: label.positionY + dragOffset.height
        )
        .gesture(
            DragGesture()
                .onChanged { dragOffset = $0.translation }
                .onEnded { v in
                    label.positionX += v.translation.width
                    label.positionY += v.translation.height
                    dragOffset = .zero
                }
        )
        .onTapGesture(count: 2) {
            beginEdit()
        }
        .contextMenu {
            Button("Bearbeiten…") { beginEdit() }
            Button {
                label.rotation = (label.rotation + 90).truncatingRemainder(dividingBy: 360)
            } label: {
                Label("Drehen 90°", systemImage: "rotate.right")
            }
            Button(role: .destructive) {
                modelContext.delete(label)
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    private func beginEdit() {
        editText = label.text
        isEditing = true
    }

    private func commitEdit() {
        label.text = editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Label" : editText
        isEditing = false
    }
}
#endif
