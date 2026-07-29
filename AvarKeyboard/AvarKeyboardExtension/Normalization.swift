//
//  Normalization.swift
//  AvarKeyboardExtension
//
//  The canonical form of a Lezgi token — one definition for the bundled
//  dictionary, the static bigrams, learned words, learned bigrams, future
//  contribution batches, and future server processing. A word must be the
//  same word in all six places or none of them can be joined.
//
//  This is the runtime half of a contract whose other half is
//  `normalize()` in scripts/build_dictionaries.py. The two MUST change
//  together, and any change bumps NORMALIZATION_VERSION and forces both
//  artifacts to be rebuilt. See docs/ARTIFACT_CONTRACT.md §2.
//

import Foundation

enum Normalization {

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
    /// own, so "цӏ" and "къ" are ONE Lezgi letter. Derived from the layout's
    /// long-press alternates so the rule has a single source.
    static let digraphTails: Set<Character> = {
        var tails = Set<Character>()
        for alternates in KeyboardLayout.callouts.values {
            for alternate in alternates where alternate.count == 2 {
                if let tail = alternate.last { tails.insert(tail) }
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

    /// Lezgi letters in a canonical token, digraphs counted as one.
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
        guard !token.isEmpty, token.count <= 64 else { return false }
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
