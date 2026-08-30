//
//  LayoutStyleTests.swift
//  AvarCoreTests
//
//  The two-layout contract: `.fourRow` is the `.threeRow` layout with one
//  digraph row prepended and NOTHING else changed — muscle memory must
//  transfer, every character stays reachable, and the engine cannot tell
//  the styles apart because digraph keys insert exactly the strings the
//  callouts already insert.
//

import XCTest
@testable import AvarCore

final class LayoutStyleTests: XCTestCase {

    private func chars(_ row: [KeyCap]) -> [String] {
        row.compactMap { if case .character(let s) = $0 { return s } else { return nil } }
    }

    // MARK: - Muscle memory

    func testFourRowPreservesTheThreeRowLayoutExactly() {
        let three = KeyboardLayout.letterRows(style: .threeRow)
        let four = KeyboardLayout.letterRows(style: .fourRow)
        XCTAssertEqual(three, KeyboardLayout.letterRows,
                       ".threeRow must be the original letterRows, untouched")
        XCTAssertEqual(four.count, three.count + 1)
        XCTAssertEqual(Array(four.dropFirst()), three,
                       "every existing key must keep its exact position")
    }

    func testDigraphRowContentAndOrder() {
        XCTAssertEqual(chars(KeyboardLayout.digraphRow),
                       ["гъ", "хъ", "къ", "кӀ", "тӀ", "цӀ", "чӀ", "хӀ", "гӀ", "кь", "хь"])
        XCTAssertEqual(KeyboardLayout.digraphRow.count, 11,
                       "same key count as the other letter rows")
        for key in chars(KeyboardLayout.digraphRow) {
            XCTAssertEqual(key.count, 2)
            for scalar in key.unicodeScalars where scalar.value == 0x4CF {
                XCTFail("digraph keys must use the visible Ӏ (U+04C0), found ӏ in \(key)")
            }
        }
    }

    // MARK: - Engine neutrality

    func testEveryDigraphKeyIsAlsoACalloutAlternate() {
        // A digraph key must insert exactly what its callout twin inserts,
        // so the engine (normalization, digraph tails, learning) cannot
        // tell the layout styles apart.
        let alternates = Set(KeyboardLayout.callouts.values.flatMap { $0 })
        for key in chars(KeyboardLayout.digraphRow) {
            XCTAssertTrue(alternates.contains(key),
                          "\(key) has no callout twin — it would be new text")
        }
        XCTAssertEqual(Normalization.digraphTails, Set("ӏъь"),
                       "tail set must stay exactly {ӏ, ъ, ь} for both styles")
    }

    // MARK: - Reachability

    private func typeable(style: LayoutStyle) -> Set<String> {
        var result = Set<String>()
        for row in KeyboardLayout.letterRows(style: style) {
            result.formUnion(chars(row))
        }
        result.formUnion(KeyboardLayout.callouts.keys)
        result.formUnion(KeyboardLayout.callouts.values.flatMap { $0 })
        return result
    }

    func testFourRowReachabilityIsPurelyAdditive() {
        let three = typeable(style: .threeRow)
        let four = typeable(style: .fourRow)
        XCTAssertTrue(four.isSuperset(of: three),
                      "the 4-row style must not lose a single typeable string")
        // The characters that only exist as standalone keys or callouts.
        for style in LayoutStyle.allCases {
            let set = typeable(style: style)
            for standalone in ["ъ", "Ӏ", "ь"] {
                XCTAssertTrue(set.contains(standalone),
                              "standalone \(standalone) must stay typeable in \(style)")
            }
            for calloutOnly in ["ы", "ё", "ф", "щ"] {
                XCTAssertTrue(set.contains(calloutOnly),
                              "\(calloutOnly) must stay typeable in \(style)")
            }
        }
        // Standalone ъ, Ӏ, ь are direct KEYS (not merely callouts) in both
        // styles, because rows 2–4 of the 4-row grid are the original rows.
        for style in LayoutStyle.allCases {
            let keys = Set(KeyboardLayout.letterRows(style: style).flatMap(chars))
            XCTAssertTrue(keys.isSuperset(of: ["ъ", "Ӏ", "ь"]))
        }
    }

    // MARK: - Geometry contract

    func testThreeRowGeometryStaysFrozen() {
        let three = KeyboardLayout.metrics(for: .threeRow)
        XCTAssertEqual(three, KeyboardLayout.Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11),
                       "the original hand-tuned geometry must never drift")
    }

    func testFourRowKeepsTheFamiliarKeyGeometry() {
        let three = KeyboardLayout.metrics(for: .threeRow)
        let four = KeyboardLayout.metrics(for: .fourRow)
        XCTAssertEqual(four.keyHeight, three.keyHeight,
                       "the existing rows must not be compressed")
        XCTAssertEqual(four.rowSpacing, three.rowSpacing)
        // 36 bar + 8 gap + 5 key rows + 4 gaps + 1 slack, mirroring the
        // three-row budget (36 + 8 + 4×43 + 3×11 + 1 = 250).
        XCTAssertEqual(four.totalHeight,
                       36 + 8 + 5 * four.keyHeight + 4 * four.rowSpacing + 1)
    }

    // MARK: - Labels and persistence contract

    func testShiftedDigraphLabelMatchesWhatATapInserts() {
        let key = KeyCap.character("гъ")
        XCTAssertEqual(KeyboardLayout.label(for: key, shifted: false, capsLock: false), "гъ")
        XCTAssertEqual(KeyboardLayout.label(for: key, shifted: true, capsLock: false), "Гъ",
                       "shift-once previews the capitalized digraph, not ГЪ")
        XCTAssertEqual(KeyboardLayout.label(for: key, shifted: true, capsLock: true), "ГЪ")
        // Single letters are unchanged by the capsLock-aware path.
        XCTAssertEqual(KeyboardLayout.label(for: .character("а"), shifted: true, capsLock: false), "А")
    }

    func testLayoutStyleRawValuesAreStable() {
        // Persisted in UserDefaults — renaming a case would silently reset
        // every user to the default style.
        XCTAssertEqual(LayoutStyle.threeRow.rawValue, "threeRow")
        XCTAssertEqual(LayoutStyle.fourRow.rawValue, "fourRow")
    }
}
