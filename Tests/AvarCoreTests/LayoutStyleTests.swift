//
//  LayoutStyleTests.swift
//  AvarCoreTests
//
//  Characterization of the two Avar layouts against their specification.
//  The 3-row and 4-row grids are defined independently — these tests pin
//  every row, every callout map, the shift layers, the symbol pages, and
//  the key names EXACTLY, so the layouts cannot drift without a failing
//  test. The engine stays style-blind: its digraph-tail source is the
//  union callout map, asserted unchanged here.
//

import XCTest
@testable import AvarCore

final class LayoutStyleTests: XCTestCase {

    private func chars(_ row: [KeyCap]) -> [String] {
        row.compactMap { if case .character(let s) = $0 { return s } else { return nil } }
    }

    // MARK: - Default layers (exact)

    func testThreeRowLayoutMatchesTheSpecificationExactly() {
        let rows = KeyboardLayout.letterRows(style: .threeRow)
        XCTAssertEqual(rows.count, 3)
        XCTAssertEqual(chars(rows[0]), ["й","ц","у","к","е","н","г","ш","щ","з","х","ъ"])
        XCTAssertEqual(chars(rows[1]), ["ф","ӏ","в","а","п","р","о","л","д","ж","э"])
        XCTAssertEqual(chars(rows[2]), ["я","ч","с","м","и","т","ь","б","ю"])
        XCTAssertEqual(rows[2].first, .shift)
        XCTAssertEqual(rows[2].last, .backspace)
        // The standalone palochka key is the lowercase form ӏ (U+04CF).
        XCTAssertEqual(chars(rows[1])[1].unicodeScalars.first?.value, 0x4CF)
    }

    func testFourRowLayoutMatchesTheSpecificationExactly() {
        let rows = KeyboardLayout.letterRows(style: .fourRow)
        XCTAssertEqual(rows.count, 4)
        XCTAssertEqual(chars(rows[0]), ["гъ","хъ","къ","кӏ","тӏ","цӏ","чӏ","хӏ","гӏ","кь","хь"])
        XCTAssertEqual(chars(rows[1]), ["й","ц","у","к","е","н","г","ш","щ","з","х"])
        XCTAssertEqual(chars(rows[2]), ["ф","лъ","в","а","п","р","о","л","д","ж","э"])
        XCTAssertEqual(chars(rows[3]), ["я","ч","с","м","и","т","гь","б","ю"])
        XCTAssertEqual(rows[3].first, .shift)
        XCTAssertEqual(rows[3].last, .backspace)
        // Digraph palochkas are the lowercase form ӏ (U+04CF), per spec.
        for key in chars(rows[0]) where key.contains("ӏ") == false && key.contains("Ӏ") {
            XCTFail("digraph \(key) must use lowercase ӏ per the layout spec")
        }
    }

    // MARK: - Shift layers (exact, via applyCase)

    func testShiftLayersMatchTheSpecification() {
        // The spec's SHIFT grids capitalize only the first letter of each
        // key: гь → Гь, кӏ → Кӏ, лъ → Лъ — applyCase(capsLock: false) is
        // the single function that produces both the label and the
        // inserted text, so asserting it covers both.
        func shifted(_ row: [KeyCap]) -> [String] {
            chars(row).map { KeyboardLayout.applyCase($0, capsLock: false) }
        }
        let three = KeyboardLayout.letterRows(style: .threeRow)
        XCTAssertEqual(shifted(three[0]), ["Й","Ц","У","К","Е","Н","Г","Ш","Щ","З","Х","Ъ"])
        XCTAssertEqual(shifted(three[1]), ["Ф","Ӏ","В","А","П","Р","О","Л","Д","Ж","Э"])
        XCTAssertEqual(shifted(three[2]), ["Я","Ч","С","М","И","Т","Ь","Б","Ю"])

        let four = KeyboardLayout.letterRows(style: .fourRow)
        XCTAssertEqual(shifted(four[0]), ["Гъ","Хъ","Къ","Кӏ","Тӏ","Цӏ","Чӏ","Хӏ","Гӏ","Кь","Хь"])
        XCTAssertEqual(shifted(four[2]), ["Ф","Лъ","В","А","П","Р","О","Л","Д","Ж","Э"])
        XCTAssertEqual(shifted(four[3]), ["Я","Ч","С","М","И","Т","Гь","Б","Ю"])
    }

    func testEveryVisibleKeyInsertsExactlyWhatItShows() {
        // Unshifted label == inserted text == the key's own string; the
        // shifted label and shifted insertion both come from applyCase.
        for style in LayoutStyle.allCases {
            for row in KeyboardLayout.letterRows(style: style) {
                for key in chars(row) {
                    XCTAssertEqual(
                        KeyboardLayout.label(for: .character(key), shifted: false), key)
                    XCTAssertEqual(
                        KeyboardLayout.label(for: .character(key), shifted: true, capsLock: false),
                        KeyboardLayout.applyCase(key, capsLock: false))
                }
            }
        }
    }

    // MARK: - Symbol layers (exact)

    func testSymbolPagesMatchTheSpecification() {
        XCTAssertEqual(chars(KeyboardLayout.numberRows[0]),
                       ["1","2","3","4","5","6","7","8","9","0"])
        XCTAssertEqual(chars(KeyboardLayout.numberRows[1]),
                       ["-","/",":",";","(",")","₽","&","@","\""])
        XCTAssertEqual(KeyboardLayout.numberRows[2],
                       [.symbols, .spacer(0.25),
                        .character("."), .character(","), .character("?"),
                        .character("!"), .character("'"),
                        .spacer(0.25), .backspace])

        XCTAssertEqual(chars(KeyboardLayout.symbolRows[0]),
                       ["[","]","{","}","#","%","^","*","+","="])
        XCTAssertEqual(chars(KeyboardLayout.symbolRows[1]),
                       ["_","\\","|","~","<",">","$","€","¥","•"])
        XCTAssertEqual(KeyboardLayout.symbolRows[2],
                       [.numbers, .spacer(0.25),
                        .character("."), .character(","), .character("?"),
                        .character("!"), .character("'"),
                        .spacer(0.25), .backspace])
    }

    // MARK: - Long-press maps (exact, per style)

    func testThreeRowCalloutsMatchTheSpecification() {
        XCTAssertEqual(KeyboardLayout.callouts(style: .threeRow), [
            "ц": ["цӏ"],
            "к": ["кӏ", "къ", "кь"],
            "е": ["ё"],
            "г": ["гӏ", "гъ", "гь"],
            "х": ["хӏ", "хъ", "хь"],
            "л": ["лъ", "лӏ"],
            "ч": ["чӏ"],
            "и": ["ы"],
            "т": ["тӏ"],
        ])
    }

    func testFourRowCalloutsAddComponentAccessOnDigraphKeys() {
        let four = KeyboardLayout.callouts(style: .fourRow)
        // Same digraph callouts on the base letters as the 3-row style…
        for (key, alternates) in KeyboardLayout.callouts(style: .threeRow) {
            XCTAssertEqual(four[key], alternates)
        }
        // …plus the component letters that lost their dedicated keys.
        XCTAssertEqual(four["гь"], ["ь"])
        XCTAssertEqual(four["гъ"], ["ъ"])
        XCTAssertEqual(four["кӏ"], ["ӏ"])
        XCTAssertEqual(four["лъ"], ["лӏ"])
        XCTAssertEqual(four.count, KeyboardLayout.callouts(style: .threeRow).count + 4)
    }

    // MARK: - Reachability

    private func typeable(style: LayoutStyle) -> Set<String> {
        var result = Set<String>()
        for row in KeyboardLayout.letterRows(style: style) {
            result.formUnion(chars(row))
        }
        result.formUnion(KeyboardLayout.callouts(style: style).values.flatMap { $0 })
        return result
    }

    func testEveryAvarCharacterIsTypeableInBothStyles() {
        let required: Set<String> = [
            "ъ", "ь", "ӏ", "ы", "ё", "ф", "щ",
            "гъ", "хъ", "къ", "кӏ", "тӏ", "цӏ", "чӏ", "хӏ", "гӏ", "кь", "хь",
            "гь", "лъ", "лӏ",
        ]
        for style in LayoutStyle.allCases {
            let set = typeable(style: style)
            for token in required {
                XCTAssertTrue(set.contains(token),
                              "\(token) must stay typeable in \(style)")
            }
        }
    }

    // MARK: - Engine neutrality

    func testEngineTailSourceIsTheStyleBlindUnion() {
        // Normalization and the learned store derive digraph tails from
        // the union map — asserting the derived set proves the layout
        // rework cannot have moved the engine.
        XCTAssertEqual(Normalization.digraphTails, Set("ӏъь"))
        for (key, alternates) in KeyboardLayout.callouts(style: .fourRow) {
            XCTAssertEqual(KeyboardLayout.callouts[key], alternates,
                           "union map must contain every style's entries")
        }
    }

    // MARK: - Key names (exact, per the spec's table)

    func testKeyNamesMatchTheSpecification() {
        XCTAssertEqual(KeyboardLayout.label(for: .space, shifted: false), "Гьоркьобакӏ")
        XCTAssertEqual(KeyboardLayout.label(for: .return, shifted: false), "Лъей")
        XCTAssertEqual(KeyboardLayout.label(for: .letters, shifted: false), "аиу")
        XCTAssertEqual(KeyboardLayout.label(for: .letters, shifted: true), "АИУ")

        XCTAssertEqual(KeyboardLayout.returnLabel(for: .default), "Лъей")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .go), "Рагьизе")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .send), "Битӏизе")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .done), "Лъугӏана")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .next), "Хадусеб")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .continue), "Цебехун")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .join), "Цолъизе")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .route), "Нух")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .search), "Хъирщи")
        XCTAssertEqual(KeyboardLayout.returnLabel(for: .emergencyCall), "SOS")
    }

    // MARK: - Geometry and persistence contracts

    func testGeometryStaysFrozen() {
        XCTAssertEqual(KeyboardLayout.metrics(for: .threeRow),
                       KeyboardLayout.Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11))
        XCTAssertEqual(KeyboardLayout.metrics(for: .fourRow),
                       KeyboardLayout.Metrics(totalHeight: 304, keyHeight: 43, rowSpacing: 11))
    }

    func testLayoutStyleRawValuesAreStable() {
        XCTAssertEqual(LayoutStyle.threeRow.rawValue, "threeRow")
        XCTAssertEqual(LayoutStyle.fourRow.rawValue, "fourRow")
    }
}
