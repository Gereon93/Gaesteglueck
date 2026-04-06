#if canImport(SwiftUI) && canImport(SwiftData) && canImport(AppKit)
import SwiftUI
import SwiftData

struct ScaleCalibrationOverlay: View {
    @Bindable var roomPlan: RoomPlan
    let onComplete: () -> Void

    @State private var pointA: CGPoint?
    @State private var pointB: CGPoint?
    @State private var realWorldCM: String = ""
    @State private var imageSize: CGSize = .zero

    private var hasCalibration: Bool {
        pointA != nil && pointB != nil && (Double(realWorldCM) ?? 0) > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Klicke zwei Punkte auf einer bekannten Wand und gib die Länge in cm ein.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()

            GeometryReader { geo in
                if let imageData = roomPlan.imageData, let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .overlay {
                            Canvas { context, size in
                                imageSize = size
                                if let a = pointA, let b = pointB {
                                    var path = Path()
                                    path.move(to: a)
                                    path.addLine(to: b)
                                    context.stroke(path, with: .color(.red), lineWidth: 3)
                                }
                                for point in [pointA, pointB].compactMap({ $0 }) {
                                    let rect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
                                    context.fill(Circle().path(in: rect), with: .color(.red))
                                }
                            }
                        }
                        .onTapGesture { location in
                            if pointA == nil {
                                pointA = location
                            } else if pointB == nil {
                                pointB = location
                            } else {
                                pointA = location
                                pointB = nil
                            }
                        }
                }
            }

            HStack {
                TextField("Länge in cm (z.B. 1000 für 10m)", text: $realWorldCM)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Button("Kalibrieren") {
                    saveCalibration()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasCalibration)
            }
            .padding()
        }
    }

    private func saveCalibration() {
        guard let a = pointA, let b = pointB,
              let cm = Double(realWorldCM), cm > 0,
              imageSize.width > 0 else { return }

        roomPlan.scalePointAX = a.x / imageSize.width
        roomPlan.scalePointAY = a.y / imageSize.height
        roomPlan.scalePointBX = b.x / imageSize.width
        roomPlan.scalePointBY = b.y / imageSize.height
        roomPlan.scaleRealWorldCM = cm
        onComplete()
    }
}
#endif
