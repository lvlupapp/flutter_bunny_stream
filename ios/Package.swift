// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Runner",
    platforms: [.iOS(.v15)],
    dependencies: [
        .package(
            url: "https://github.com/BunnyWay/bunny-stream-ios.git",
            branch: "main"  // Using main branch directly
        )
    ],
    targets: [
        .target(
            name: "Runner",
            dependencies: [
                .product(name: "BunnyStreamAPI", package: "bunny-stream-ios"),
                .product(name: "BunnyStreamPlayer", package: "bunny-stream-ios"),
                .product(name: "BunnyStreamUploader", package: "bunny-stream-ios")
            ],
            path: "."
        )
    ]
)