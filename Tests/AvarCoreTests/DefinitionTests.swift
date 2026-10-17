//
//  DefinitionTests.swift
//  AvarCoreTests
//
//  Phase 1 step 1b: the Avar KeyboardDefinition reproduces every constant
//  the released engine had inline, the engine files carry no language data,
//  and the profile-driven normalization is identical to the released one.
//

import XCTest
import SQLite3
import UIKit
@testable import AvarCore
@testable import GeneralKeyboard

final class AvarDefinitionTests: AvarTestCase {

    private var d: KeyboardDefinition { KeyboardDefinition.current }

    func testTheCurrentDefinitionIsAvarAndValid() {
        XCTAssertEqual(d.validationErrors(), [])
        // Stable identity (Phase 3): the extension's bundle identifier.
        XCTAssertEqual(d.id, "org.lekitech.avarkeyboard.AvarKeyboardExtension")
        XCTAssertEqual(d.data.appGroupID, "group.org.lekitech.avarkeyboard")
        XCTAssertEqual(AvarIdentity.appGroupID, d.data.appGroupID)
        XCTAssertEqual(d.data.wordsArtifact, "avar_words")
        XCTAssertEqual(d.data.bigramsArtifact, "avar_bigrams")
        XCTAssertEqual(WordSuggestions.artifactName, "avar_words")
        XCTAssertEqual(StaticBigrams.artifactName, "avar_bigrams")
        XCTAssertEqual(d.data.diagnosticsSubsystem, "AvarKeyboardExtension")
    }

    func testLayoutCapabilities() {
        XCTAssertEqual(d.layout.styles.map(\.id), [.threeRow, .fourRow])
        XCTAssertEqual(LayoutStyle.allCases, [.threeRow, .fourRow])
        XCTAssertEqual(d.layout.defaultStyle, .threeRow)
        XCTAssertTrue(d.layout.showsStyleSelector)
        XCTAssertTrue(d.layout.showsSelector)
        XCTAssertEqual(d.layout.persistenceKey, "layoutStyle")
        XCTAssertEqual(d.layout.styles.map(\.settingsTitle), ["3 мухъ", "4 мухъ"])
        XCTAssertEqual(d.layout.resolve("fourRow"), .fourRow)
        XCTAssertEqual(d.layout.resolve("threeRow"), .threeRow)
        XCTAssertEqual(d.layout.resolve(nil), .threeRow)
        XCTAssertEqual(d.layout.resolve("classic"), .threeRow, "a style Avar does not offer")
    }

    func testOneStyleNeedsNoSelector() {
        var single = d.layout
        single.styles = [AvarLayout.fourRow]
        single.defaultStyle = .fourRow
        XCTAssertFalse(single.showsSelector, "one style: no selector even when requested")
        XCTAssertEqual(single.resolve("threeRow"), .fourRow, "unsupported persisted value")
        // Callout keys are compared the way the definition lowercases text
        // (keeping the visible palochka Ӏ)
        let definition = d
        let lower = { (s: String) in
            definition.text.visibleLowercased(s, canonicalPalochka: definition.normalization.palochka)
        }
        XCTAssertEqual(single.validationErrors(lowercase: lower), [])
        single.defaultStyle = .threeRow
        XCTAssertFalse(single.validationErrors(lowercase: lower).isEmpty, "default must be offered")
    }

    func testPresentationConventions() {
        XCTAssertEqual(d.text.visiblePalochka, "\u{04C0}")
        XCTAssertEqual(d.text.caseNeutral, ["\u{04C0}", "\u{04CF}"])
        XCTAssertEqual(d.text.visibleForm("ц\u{04CF}ияб", canonicalPalochka: "\u{04CF}"),
                       "ц\u{04C0}ияб")
    }

    func testKeyLabels() {
        XCTAssertEqual(d.keys.spaceCornerLabel, "АВАР")
        XCTAssertEqual(d.keys.keyboardName, "Авар мац\u{04C0}")
        XCTAssertEqual(d.keys.emojiPageLettersKey, "АБВ")
        XCTAssertEqual(d.keys.returnLabels.count, 9)
        XCTAssertNil(d.keys.returnLabels[.default])
        XCTAssertNil(d.keys.returnLabels[.google])
        XCTAssertNil(d.keys.returnLabels[.yahoo])
    }

    func testStringsWithArguments() {
        XCTAssertEqual(d.strings.deleteWordQuestion("рагӀи"), "“рагӀи” гилдизеищ?")
        XCTAssertEqual(d.strings.aboutByline("1.0.0"), "Версия 1.0.0 · LekiTech")
        // Derived from the engine's own values, rendered exactly as released.
        XCTAssertEqual(KeyboardSettings.LearnSpeed.allCases.map { d.strings.learnUses($0.minUses) },
                       ["1 нухалъ", "3 нухалъ", "5 нухалъ"])
        XCTAssertEqual(KeyboardSettings.CalloutDelay.allCases.map { d.strings.calloutDuration($0.seconds) },
                       ["0,2 с", "0,3 с", "0,45 с"])
    }

    func testEmojiTitlesCoverTheCatalogExactly() {
        XCTAssertEqual(EmojiData.categories.map(\.id),
                       ["smileys", "nature", "food", "activity", "travel", "objects", "symbols", "flags"])
        XCTAssertEqual(Set(d.emojiCategoryTitles.keys), Set(EmojiData.categories.map(\.id)))
    }

    // MARK: - Normalization profile

    func testTheProfileIsTheBuiltInDagestanianCyrillicV1() {
        XCTAssertEqual(d.normalization, .dagestanianCyrillicV1)
        XCTAssertEqual(d.normalization.id, "dagestanian-cyrillic")
        XCTAssertEqual(d.normalization.version, 1)
        XCTAssertEqual(Normalization.version, 1, "learned-store marker and artifact version unchanged")
    }

    /// The profile declares the tails; the released engine derived them
    /// from the layout. Both released derivations must equal the profile.
    func testDeclaredDigraphTailsMatchBothReleasedDerivations() {
        var fromCallouts = Set<Character>()
        for alternates in d.layout.calloutUnion.values {
            for alternate in alternates where alternate.count == 2 {
                if let tail = alternate.lowercased().last { fromCallouts.insert(tail) }
            }
        }
        // LearnedWords (released): callouts only.
        XCTAssertEqual(fromCallouts, d.normalization.digraphTails)
        // Normalization (released): callouts plus the hard sign.
        XCTAssertEqual(fromCallouts.union(["ъ"]), d.normalization.digraphTails)
        XCTAssertEqual(LegacyNormalizationB6A5C53.digraphTails, Normalization.digraphTails)
    }

    // MARK: - Side by side with the released implementation

    private static let extensionDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("AvarKeyboard/AvarKeyboardExtension")

    private static func column(_ sql: String, file: String) -> [String] {
        var db: OpaquePointer?
        let path = extensionDirectory.appendingPathComponent(file).path
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var out: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let t = sqlite3_column_text(stmt, 0) { out.append(String(cString: t)) }
        }
        return out
    }

    /// Deterministic adversarial strings: Cyrillic, both palochkas, every
    /// lookalike and homoglyph, digits, separators, whitespace, combining
    /// marks, controls and invisibles.
    private static func fuzzCorpus(count: Int) -> [String] {
        let pool: [String] = Array("абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")
            .map(String.init) + [
            "\u{04CF}", "\u{04C0}", "I", "l", "i", "\u{0406}", "\u{0456}", "1", "|", "!",
            "a", "c", "e", "o", "p", "x", "y", "k", "m", "t", "b", "h", "z", "Q",
            "0", "7", "@", "/", ".", "-", " ", "\u{00A0}", "\t", "\n",
            "\u{0301}", "\u{0306}", "\u{001F}", "\u{200D}", "\u{200E}", "⅚", "Ⅻ", "Σ", "İ", "й",
        ]
        var state: UInt64 = 0x9E3779B97F4A7C15
        func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int(truncatingIfNeeded: state >> 33)
        }
        return (0..<count).map { _ in
            (0..<(1 + next() % 12)).map { _ in pool[next() % pool.count] }.joined()
        }
    }

    func testProfileNormalizationIsIdenticalToTheReleasedOne() {
        let words = Self.column("SELECT word FROM words", file: "avar_words.sqlite")
        let prevs = Self.column("SELECT prev FROM bigrams", file: "avar_bigrams.sqlite")
        let nexts = Self.column("SELECT word FROM bigrams", file: "avar_bigrams.sqlite")
        XCTAssertEqual(words.count, 63_879)
        XCTAssertEqual(prevs.count, 5_101)
        let inputs = words + prevs + nexts + Self.fuzzCorpus(count: 60_000)
            + words.prefix(5_000).map { $0.uppercased() }
        var mismatches: [String] = []
        for input in inputs {
            let old = LegacyNormalizationB6A5C53.self
            if Array(Normalization.canonical(input).unicodeScalars)
                != Array(old.canonical(input).unicodeScalars)
                || Normalization.isCanonical(input) != old.isCanonical(input)
                || Normalization.isValidToken(input) != old.isValidToken(input)
                || Normalization.letterCount(input) != old.letterCount(input) {
                mismatches.append(input)
                if mismatches.count >= 10 { break }
            }
        }
        XCTAssertEqual(mismatches, [], "\(inputs.count) inputs compared")
    }

    // MARK: - No engine code in the product

    /// Since Phase 3 the engine is the General Keyboard package, and its
    /// neutrality is enforced there (EngineNeutralityTests). The extension
    /// target holds only Avar's product files and a principal class that
    /// installs the Avar definition in both initializers.
    func testTheExtensionHoldsOnlyProductCode() throws {
        let swiftFiles = try FileManager.default
            .contentsOfDirectory(atPath: Self.extensionDirectory.path)
            .filter { $0.hasSuffix(".swift") }
            .sorted()
        XCTAssertEqual(swiftFiles, ["AvarDefinition.swift", "AvarIdentity.swift", "AvarLayout.swift",
                                    "AvarStrings.swift", "KeyboardViewController.swift"])

        let principal = try String(contentsOf: Self.extensionDirectory
            .appendingPathComponent("KeyboardViewController.swift"), encoding: .utf8)
        XCTAssertTrue(principal.contains("final class KeyboardViewController: GeneralKeyboardViewController"))
        XCTAssertEqual(principal.components(separatedBy: "KeyboardDefinition.install(AvarDefinition.definition)")
                        .count - 1, 2, "install in init(nibName:bundle:) and init?(coder:)")
    }
}

// MARK: - The released normalization, frozen verbatim (b6a5c53) for comparison

enum LegacyNormalizationB6A5C53 {

    /// Bumped when the rules below change. Artifacts record the version
    /// they were built with, so a mismatch is detectable rather than silent.
    static let version = 1

    /// ӏ CYRILLIC SMALL LETTER PALOCHKA (U+04CF) — the one true palochka.
    static let palochka: Character = "ӏ"

    /// Characters users and source corpora substitute for the palochka.
    /// Repaired only inside tokens that contain Cyrillic, so a genuine
    /// Latin borrowing keeps its "i".
    /// Deliberately excludes the digit 1 and the pipe: this keyboard types
    /// real digits, and `isLearnable` rejects digit-bearing tokens, so
    /// repairing «гаф1» into «гафӏ» would turn a token the store must
    /// refuse into one it accepts. Corpus sources that use 1-as-palochka
    /// are a preprocessing concern, not part of the canonical contract —
    /// and the shipped dictionary contains no such row.
    private static let palochkaLookalikes: Set<Character> = [
        "I", "l", "i",
        "І",   // U+0406 CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I
        "і",   // U+0456 its lowercase — found 34 times in the shipped dictionary
        "Ӏ",   // U+04C0 uppercase palochka
    ]

    /// Latin letters visually identical to a Cyrillic letter. Applied only
    /// to otherwise-Cyrillic tokens.
    private static let latinToCyrillic: [Character: Character] = [
        "a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
        "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н",
    ]

    /// A digraph tail extends the previous letter instead of counting as its
    /// own, so "цӏ" and "къ" are ONE letter. Derived from the layout's
    /// long-press alternates so the rule has a single source. The layout
    /// stores callouts with the typed capital palochka (Ӏ, U+04C0), while
    /// counting always runs on canonical (lowercased) tokens — so each tail
    /// is lowercased on the way into the set.
    static let digraphTails: Set<Character> = {
        var tails = Set<Character>()
        for alternates in KeyboardLayout.callouts.values {
            for alternate in alternates where alternate.count == 2 {
                if let tail = alternate.lowercased().last { tails.insert(tail) }
            }
        }
        tails.insert("ъ")   // the hard sign is a tail even without a callout
        return tails
    }()

    private static func containsCyrillic(_ token: String) -> Bool {
        token.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    /// The canonical form. Idempotent by construction:
    /// `canonical(canonical(x)) == canonical(x)`.
    static func canonical(_ token: String) -> String {
        // 1. NFC, so a decomposed «й» (и + combining breve) is the same word
        //    as the precomposed U+0439.
        var result = token.precomposedStringWithCanonicalMapping
        // 2. Trim. Internal whitespace makes a token invalid, not repairable.
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        // 3. Lowercase — this alone maps Ӏ (U+04C0) to ӏ (U+04CF).
        result = result.lowercased()
        // 4-5. Repair lookalikes, but only where the token is Cyrillic.
        if containsCyrillic(result) {
            result = String(result.map { ch in
                if palochkaLookalikes.contains(ch) { return palochka }
                return latinToCyrillic[ch] ?? ch
            })
        }
        // 6. NFC again so the function is idempotent whatever the repairs did.
        return result.precomposedStringWithCanonicalMapping
    }

    /// Whether a token is ALREADY in canonical form, compared by scalars.
    ///
    /// Swift's `==` is canonical-equivalent, so `decomposed == precomposed`
    /// is true even though SQLite — which compares bytes — treats them as
    /// two different rows. Any code deciding whether a stored value needs
    /// rewriting must use this, not `==`.
    static func isCanonical(_ token: String) -> Bool {
        Array(canonical(token).unicodeScalars) == Array(token.unicodeScalars)
    }

    /// Letters in a canonical token, digraphs counted as one.
    static func letterCount(_ token: String) -> Int {
        token.reduce(0) { digraphTails.contains($1) ? $0 : $0 + 1 }
    }

    /// Whether a canonical token may be stored, learned, or contributed.
    ///
    /// This is the CONTRACT definition. It is intentionally not wired into
    /// the released learning path yet: `LearnedWords.isLearnable` keeps its
    /// own equivalent rules, and unifying them changes what gets learned,
    /// which needs its own migration and review.
    static func isValidToken(_ token: String) -> Bool {
        // Scalars, not Characters: Python's len() counts code points, and
        // the two halves of the contract must measure length identically.
        // On canonical (NFC) Avar text the two counts agree anyway; they
        // diverge only on combining-mark sequences, exactly where an
        // implicit disagreement would hide.
        guard !token.isEmpty, token.unicodeScalars.count <= 64 else { return false }
        guard !token.contains(where: \.isWhitespace) else { return false }
        guard !token.contains(where: \.isNumber) else { return false }
        guard !token.contains("@"), !token.contains("/"), !token.contains(".") else { return false }
        guard !token.contains(where: { $0.isASCII && $0.isLetter }) else { return false }
        // No control or format characters. Controls (Cc) include U+001F,
        // which the contribution outbox uses to join bigram keys — a token
        // that could carry it would make that encoding ambiguous. Formats
        // (Cf) are the invisibles — ZWJ, ZWNJ, bidi marks — that would let
        // two identical-looking tokens be different rows.
        guard !token.unicodeScalars.contains(where: { scalar in
            let category = scalar.properties.generalCategory
            return category == .control || category == .format
        }) else { return false }
        return letterCount(token) >= 2
    }
}
