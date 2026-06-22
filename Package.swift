// swift-tools-version: 5.9
// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2026 Denis Yermakou <connect@axonos.org>
// Part of the AxonOS project — https://github.com/AxonOS-org

import PackageDescription

let package = Package(
    name: "AxonOS",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(name: "AxonOS", targets: ["AxonOS"]),
    ],
    targets: [
        .target(
            name: "AxonOS",
            path: "Sources/AxonOS"
        ),
        .testTarget(
            name: "AxonOSTests",
            dependencies: ["AxonOS"],
            path: "Tests/AxonOSTests"
        ),
    ]
)
