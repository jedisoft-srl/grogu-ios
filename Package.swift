// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AppleAttribution",
    platforms: [.iOS(.v13), .macOS(.v11)],
    products: [
        .library(name: "AppleAttribution", targets: ["AppleAttribution"])
    ],
    targets: [
        .target(
            name: "AppleAttribution",
            resources: [.copy("Resources/PrivacyInfo.xcprivacy")]
        ),
        .testTarget(name: "AppleAttributionTests", dependencies: ["AppleAttribution"])
    ]
)
