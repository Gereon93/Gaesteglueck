// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Gaesteglueck",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "Gaesteglueck",
            targets: ["Gaesteglueck"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX", from: "0.14.0"),
    ],
    targets: [
        .target(
            name: "Gaesteglueck",
            dependencies: ["CoreXLSX"]
        ),
        .testTarget(
            name: "GaesteglueckTests",
            dependencies: ["Gaesteglueck"]
        ),
    ]
)
