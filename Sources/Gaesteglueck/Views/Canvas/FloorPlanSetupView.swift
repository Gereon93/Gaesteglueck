#if canImport(SwiftUI) && canImport(SwiftData) && canImport(UIKit)
import SwiftUI
import SwiftData
import PhotosUI

struct FloorPlanSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var roomPlan: RoomPlan

    @State private var selectedPhoto: PhotosPickerItem?
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
                    Text("Fotografiere den Grundriss der Location oder wähle ein Bild aus deinen Fotos.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Aus Fotos", systemImage: "photo")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 40)

                    if roomPlan.imageData != nil {
                        Button("Vorhandenen Plan verwenden") {
                            phase = .calibrate
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .onChange(of: selectedPhoto) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self) {
                            roomPlan.imageData = data
                            phase = .calibrate
                        }
                    }
                }

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
