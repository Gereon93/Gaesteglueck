#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData

struct FloorPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var roomPlan: RoomPlan

    @State private var phase: SetupPhase = .chooseImage

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
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.image]
                        panel.begin { response in
                            if response == .OK, let url = panel.url,
                               let data = try? Data(contentsOf: url) {
                                roomPlan.imageData = data
                                phase = .calibrate
                            }
                        }
                    }
                    .buttonStyle(.bordered)

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
