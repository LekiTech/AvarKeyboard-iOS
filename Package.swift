// swift-tools-version: 6.0
//
//  Test-only package for the keyboard's storage and ranking logic.
//
//  It owns no source of its own: `AvarCore` compiles the very same files
//  that ship inside the AvarKeyboardExtension extension target, via an explicit
//  `sources:` list. Nothing is copied or moved, so the tests cannot drift
//  from production code, and the app's Xcode project is untouched — that
//  project builds a released app and must not be destabilized just to make
//  the logic testable.
//
//  Run from the repo root:
//    xcodebuild test -scheme AvarCoreTests \
//      -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
//
//  iOS-only by design: the shared layout file uses UIKit types.
//
import PackageDescription

let package = Package(
    name: "AvarCoreTests",
    platforms: [.iOS(.v18)],
    targets: [
        .target(
            name: "AvarCore",
            path: "AvarKeyboard/AvarKeyboardExtension",
            sources: [
                "LearnedWords.swift",
                "Migrations.swift",
                "ContributionOutbox.swift",
                "ContributionBridge.swift",
                "ContributionExporter.swift",
                "Normalization.swift",
                "WordSuggestions.swift",
                "StaticBigrams.swift",
                "KeyboardSettings.swift",
                "KeyboardLayout.swift",
            ]
        ),
        .testTarget(
            name: "AvarCoreTests",
            dependencies: ["AvarCore"],
            path: "Tests/AvarCoreTests",
            resources: [
                // Frozen production-shaped databases; see
                // scripts/make_golden_fixture_v1.py for provenance.
                .copy("Fixtures"),
            ]
        ),
    ]
)
