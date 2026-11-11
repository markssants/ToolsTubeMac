// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ToolsTube",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ToolsTube",
            path: "Sources/ToolsTube"
        )
    ]
)
