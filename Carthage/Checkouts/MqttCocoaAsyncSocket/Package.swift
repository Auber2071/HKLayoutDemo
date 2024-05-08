// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MqttCocoaAsyncSocket",
    platforms: [
        .iOS(.v9),
        .macOS(.v10_10),
        .tvOS(.v9)
    ],
    products: [
        .library(
            name: "MqttCocoaAsyncSocket",
            targets: ["MqttCocoaAsyncSocket"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MqttCocoaAsyncSocket",
            dependencies: [],
            path: "Source/GCD",
            publicHeadersPath: ""),

        .testTarget(name: "SharedObjCTests",
                    dependencies: ["MqttCocoaAsyncSocket"],
                    path: "Tests/Shared/ObjC"),

        .testTarget(name: "SharedSwiftTests",
                    dependencies: ["MqttCocoaAsyncSocket"],
                    path: "Tests/Shared/Swift")
    ]
)
