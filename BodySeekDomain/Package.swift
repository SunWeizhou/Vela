// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BodySeekDomain",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "BodySeekDomain", targets: ["BodySeekDomain"])
    ],
    targets: [
        .target(name: "BodySeekDomain"),
        .testTarget(
            name: "BodySeekDomainTests",
            dependencies: ["BodySeekDomain"]
        )
    ]
)
