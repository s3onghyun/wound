// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wound",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Wound", targets: ["Wound"])],
    targets: [
        .executableTarget(
            name: "Wound",
            resources: [.copy("tick-8bps-1s.wav"), .copy("crown-click.wav"), .copy("rotor-whirr-2s.wav")]
        )
    ]
)
