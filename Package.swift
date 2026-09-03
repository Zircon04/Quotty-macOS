// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Quotty",
    platforms: [
        .macOS(.v13)
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
