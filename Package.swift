// swift-tools-version: 6.0
//
//  Test-only package for the Avar keyboard's product layer.
//
//  The keyboard engine lives in the General Keyboard package
//  (../GeneralKeyboard-iOS) and is tested there. This package tests what
//  Avar adds on top: `AvarCore` compiles the very same product files that
//  ship inside the AvarKeyboardExtension target (the definition, layouts,
//  strings and identity), via an explicit `sources:` list, and the tests
//  run them through the real engine: characterization of persisted state,
//  pixel snapshots of every screen, the definition, the shipped artifacts.
//
//  Run from the repo root (General Keyboard checked out next to this repo):
//    xcodebuild test -scheme AvarCoreTests-Package \
//      -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
//
//  iOS-only by design: the layout and the engine use UIKit types.
//
import PackageDescription

let package = Package(
    name: "AvarCoreTests",
    platforms: [.iOS(.v18)],
    dependencies: [
        .package(path: "../GeneralKeyboard-iOS"),
    ],
    targets: [
        .target(
            name: "AvarCore",
            dependencies: [.product(name: "GeneralKeyboard", package: "GeneralKeyboard-iOS")],
            path: "AvarKeyboard/AvarKeyboardExtension",
            sources: [
                "AvarDefinition.swift",
                "AvarLayout.swift",
                "AvarStrings.swift",
                "AvarIdentity.swift",
            ]
        ),
        .testTarget(
            name: "AvarCoreTests",
            dependencies: ["AvarCore", .product(name: "GeneralKeyboard", package: "GeneralKeyboard-iOS")],
            path: "Tests/AvarCoreTests",
            // Reference images are read through #filePath, not bundled.
            exclude: ["Snapshots"]
        ),
    ]
)
