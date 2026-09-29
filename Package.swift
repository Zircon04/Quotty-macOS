// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Quotty",
    platforms: [
        .macOS("26.0")
    ],
    products: [
        .executable(
            name: "Quotty",
            targets: ["Quotty"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Quotty",
            dependencies: [],
            path: "Sources/Quotty"
        )
    ]
)
