#if canImport(SwiftUI)
import SwiftUI

private struct CanvasScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0 / 3.0
}

extension EnvironmentValues {
    var canvasScale: CGFloat {
        get { self[CanvasScaleKey.self] }
        set { self[CanvasScaleKey.self] = newValue }
    }
}
#endif
