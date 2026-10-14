//
//  AvarDefinition.swift
//  AvarKeyboardExtension
//
//  The Avar keyboard as a KeyboardDefinition: everything Avar-specific the
//  engine uses, assembled in one value. Layouts live in AvarLayout.swift,
//  strings and key names in AvarStrings.swift.
//

import Foundation

enum AvarDefinition {

    static let definition = KeyboardDefinition(
        data: LanguageData(
            appGroupID: AvarIdentity.appGroupID,
            wordsArtifact: "avar_words",
            bigramsArtifact: "avar_bigrams",
            diagnosticsSubsystem: "AvarKeyboardExtension"
        ),
        layout: AvarLayout.capabilities,
        keys: AvarStrings.keys,
        text: TextConventions(
            // Project-wide convention: everything the user SEES carries the
            // typed uppercase palochka Ӏ (U+04C0); every stored row keeps
            // the canonical ӏ (U+04CF).
            visiblePalochka: "\u{04C0}",
            // Ӏ is category Lu but caseless by convention: «ЦӀ» is a
            // capitalized digraph, not an ALL-CAPS prefix.
            caseNeutral: ["\u{04C0}", "\u{04CF}"]
        ),
        normalization: .dagestanianCyrillicV1,
        strings: AvarStrings.strings,
        emojiCategoryTitles: AvarStrings.emojiCategoryTitles
    )
}

extension KeyboardDefinition {
    /// Phase 1 binding: the product supplies the definition statically.
    /// Phase 2 replaces this with installation by the principal class.
    static let current: KeyboardDefinition = AvarDefinition.definition
}
