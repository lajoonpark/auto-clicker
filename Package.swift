// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "AutoClicker",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "AutoClicker", targets: ["AutoClicker"]),
        .executable(name: "AutoClickerApp", targets: ["AutoClickerApp"]),
    ],
    targets: [
        .target(name: "AutoClicker"),
        .executableTarget(name: "AutoClickerApp", dependencies: ["AutoClicker"]),
        .testTarget(name: "AutoClickerTests", dependencies: ["AutoClicker"]),
    ],
    swiftLanguageModes: [.v6]
)
