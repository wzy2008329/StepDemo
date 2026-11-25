// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StepSourceKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(name: "StepSourceKit", targets: ["StepSourceKit"])
    ],
    targets: [
        .target(
            name: "StepSourceKit",
            path: "Sources/StepSourceKit"
        )
    ]
)
