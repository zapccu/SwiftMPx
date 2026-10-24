// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftMPx",
    // macOS 15 / iOS 18 required for Atomic (Synchronization module)
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SwiftMPx",
            targets: ["SwiftMPx"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .systemLibrary(
            name: "CMPFR",
            pkgConfig: "mpfr gmp",
            providers: [
                .brew(["mpfr", "gmp"]),
                .apt(["libmpfr-dev", "libgmp-dev"])
            ]
        ),
        .target(
            name: "SwiftMPx",
            dependencies: ["CMPFR"]
        ),
        // Benchmark: swift run -c release SwiftMPxBenchmark [iterations]
        .executableTarget(
            name: "SwiftMPxBenchmark",
            dependencies: ["SwiftMPx"]
        ),
        .testTarget(
            name: "SwiftMPxTests",
            dependencies: ["SwiftMPx"]
        )
    ]
)
