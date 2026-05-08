// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Gaesteglueck",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "Gaesteglueck", targets: ["Gaesteglueck"])
    ],
    dependencies: [
        .package(url: "https://github.com/CoreOffice/CoreXLSX", from: "0.14.0")
    ],
    targets: [
        .executableTarget(name: "Gaesteglueck", dependencies: ["CoreXLSX"]),
        .testTarget(name: "GaesteglueckTests", dependencies: ["Gaesteglueck"])
    ]
)
