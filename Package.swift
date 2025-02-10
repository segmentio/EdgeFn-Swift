// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AnalyticsLive",
    platforms: [
        .macOS("11.0"),
        .iOS("14.0"),
        .tvOS("14.0"),
        //.watchOS("7.1")
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AnalyticsLive",
            targets: ["AnalyticsLive"])
    ],
    dependencies: [
        .package(url: "https://github.com/segmentio/analytics-swift.git", from: "1.7.2"),
        .package(url: "https://github.com/segmentio/substrata-swift.git", from: "2.0.9"),
    ],
    targets: [
        .target(
            name: "AnalyticsLive",
            dependencies: [
                .product(name: "Segment", package: "analytics-swift"),
                .product(name: "Substrata", package: "substrata-swift"),
                .product(name: "SubstrataQuickJS", package: "substrata-swift"),
            ]),
        .testTarget(
            name: "AnalyticsLiveTests",
            dependencies: [
                "AnalyticsLive"
            ],
            resources: [
                .copy("TestHelpers/filterSettings.json"),
                .copy("TestHelpers/testbundle.js"),
                .copy("TestHelpers/addliveplugin.js"),
                .copy("TestHelpers/MyEdgeFunctions.js"),
            ]),
    ]
)
