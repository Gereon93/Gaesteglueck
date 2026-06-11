#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct FloorPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var roomPlan: RoomPlan

    @State private var phase: SetupPhase = .chooseImage
    @State private var showingImagePicker = false

    enum SetupPhase {
        case chooseImage
        case calibrate
    }

    var body: some View {
        NavigationStack {
            switch phase {
            case .chooseImage:
                VStack(spacing: 24) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("Raumplan importieren")
                        .font(.title2.bold())
                    Text("Wähle ein Bild des Grundrisses der Location.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Button("Bild auswählen") {
                        showingImagePicker = true
                    }
                    .buttonStyle(.bordered)
                    .fileImporter(
                        isPresented: $showingImagePicker,
                        allowedContentTypes: [.image]
                    ) { result in
                        guard let url = try? result.get() else { return }
                        let scoped = url.startAccessingSecurityScopedResource()
                        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                        if let data = try? Data(contentsOf: url) {
                            roomPlan.imageData = data
                            phase = .calibrate
                        }
                    }

                    if roomPlan.imageData != nil {
                        Button("Vorhandenen Plan verwenden") {
                            phase = .calibrate
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()

            case .calibrate:
                ScaleCalibrationOverlay(roomPlan: roomPlan) {
                    dismiss()
                }
            }

            Spacer()
        }
        .navigationTitle("Raumplan")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Abbrechen") { dismiss() }
            }
        }
    }
}
#endif
