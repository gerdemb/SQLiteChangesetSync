// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SqliteChangesetSync",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SqliteChangesetSync",
            targets: ["SqliteChangesetSync"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.10.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "SqliteChangesetSync",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            cSettings: [
                .headerSearchPath(".")
            ]),
        .testTarget(
            name: "SqliteChangesetSyncTests",
            dependencies: ["SqliteChangesetSync"]),
    ]
)
