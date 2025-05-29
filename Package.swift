// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ResizablePopover",
    platforms: [
        .macOS(.v10_15) // Minimum macOS version that supports SwiftUI and modern NSPopover features
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ResizablePopover",
            targets: ["ResizablePopover"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // No external dependencies required
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ResizablePopover",
            dependencies: [],
            path: "Sources"),
    ]
) 