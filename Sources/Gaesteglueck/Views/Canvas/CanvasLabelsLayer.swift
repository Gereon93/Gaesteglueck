#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

struct CanvasLabelsLayer: View {
    let event: Event?

    var body: some View {
        Group {
            if let event = event {
                ForEach(event.labels) { label in
                    CanvasLabelView(label: label)
                }
            }
        }
    }
}
#endif
