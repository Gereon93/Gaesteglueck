import SwiftUI

#if canImport(AppKit)
import AppKit
/// Plattformneutrales Bild — NSImage am Mac, UIImage auf iOS/iPadOS.
typealias PlatformImage = NSImage
#elseif canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(AppKit)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}
