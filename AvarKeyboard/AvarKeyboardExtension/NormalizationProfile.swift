//
//  NormalizationProfile.swift
//  AvarKeyboardExtension
//
//  The language-specific half of the canonical-form contract
//  (GENERAL_KEYBOARD_DESIGN.md §2.4a). The engine owns the fixed pipeline
//  and every engine-contract gate (NFC, trim, lowercase, length, digits,
//  controls…); a profile only supplies script and language data. A future
//  language brings its own profile through its KeyboardDefinition without
//  touching the engine.
//
//  Identity is (id, version). For the built-in profile the id is implicit:
//  artifacts and the learned store record only the version, under the keys
//  they always used, so Avar and Lezgi data stay byte-identical. Recording
//  the id for a non-default profile (an artifact meta key and a learned-
//  store marker key derived from it) arrives with the first such profile;
//  see GENERAL_KEYBOARD_DESIGN.md §2.4a.
//

import Foundation

struct NormalizationProfile: Equatable, Sendable {
    /// Stable identifier, [a-z0-9-]+, never reused for different rules.
    var id: String
    /// Monotonic per id; bumping it forces artifact rebuilds and a sweep
    /// of learned data.
    var version: Int
    /// Lookalike and homoglyph repair runs only on tokens containing a
    /// scalar in one of these ranges.
    var repairScripts: [ClosedRange<UInt32>]
    /// The canonical palochka every lookalike becomes; nil disables
    /// lookalike repair.
    var palochka: Character?
    /// Characters repaired into `palochka` (after lowercasing).
    var palochkaLookalikes: Set<Character>
    /// Latin letters repaired into their visual twins.
    var homoglyphs: [Character: Character]
    /// Whether a valid token may contain no ASCII letter after repair.
    var rejectsASCIILetters: Bool
    /// Characters that extend the previous letter rather than count as a
    /// letter of their own ("цӏ", "къ" are one letter each).
    var digraphTails: Set<Character>

    /// Dagestanian Cyrillic orthographies, version 1: the rules Avar and
    /// Lezgi have shipped with since normalization_version 1.
    static let dagestanianCyrillicV1 = NormalizationProfile(
        id: "dagestanian-cyrillic",
        version: 1,
        repairScripts: [0x0400...0x04FF],
        palochka: "\u{04CF}",
        // Deliberately excludes the digit 1 and the pipe: the keyboard
        // types real digits, and repairing «гаф1» into «гафӏ» would turn a
        // token the store must refuse into one it accepts.
        palochkaLookalikes: [
            "I", "l", "i",
            "\u{0406}",   // CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I
            "\u{0456}",   // its lowercase
            "\u{04C0}",   // uppercase palochka
        ],
        homoglyphs: [
            "a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
            "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н",
        ],
        rejectsASCIILetters: true,
        digraphTails: ["\u{04CF}", "\u{044C}", "\u{044A}"]   // ӏ ь ъ
    )
}
