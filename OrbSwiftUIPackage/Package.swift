// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrbSwiftUIFeature",
    platforms: [.iOS(.v18)],
    products: [
        .library(
            name: "OrbSwiftUIFeature",
            targets: ["OrbSwiftUIFeature"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "OrbSwiftUIFeature",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "OrbSwiftUIFeatureTests",
            dependencies: [
                "OrbSwiftUIFeature"
            ]
        ),
    ]
)
