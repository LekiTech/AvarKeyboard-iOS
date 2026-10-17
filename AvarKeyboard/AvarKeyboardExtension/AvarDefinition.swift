//
//  AvarDefinition.swift
//  AvarKeyboardExtension
//
//  The Avar keyboard as a KeyboardDefinition: everything Avar-specific the
//  engine uses, assembled in one value. Layouts live in AvarLayout.swift,
//  strings and key names in AvarStrings.swift.
//

import Foundation
import GeneralKeyboard

enum AvarDefinition {

    static let definition = KeyboardDefinition(
        // Stable identity: the extension's bundle identifier. Never reused
        // for a different definition.
        id: "org.lekitech.avarkeyboard.AvarKeyboardExtension",
        data: LanguageData(
            appGroupID: AvarIdentity.appGroupID,
            wordsArtifact: "avar_words",
            bigramsArtifact: "avar_bigrams",
            diagnosticsSubsystem: "AvarKeyboardExtension"
        ),
        layout: AvarLayout.capabilities,
        keys: AvarStrings.keys,
        text: TextConventions(
            // Project-wide convention: everything the user sees and types
            // carries the palochka Ӏ (U+04C0); lookup keys and every stored
            // row keep its case folding ӏ (U+04CF).
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
