//
//  KeyboardLayout.swift
//  AvarKeyboardExtension
//
//  Created by Enver Eskendarov on 6/28/26.
//
//  Single source of truth for key definitions, labels, callouts, and sizing.
//  To add or reorder keys, edit letterRows only.
//

import SwiftUI

/// What a key does when tapped.
/// .character("Ӏ") inserts Cyrillic Palochka (U+04C0) — the caseless bar
/// letter as conventionally typed in Avar text. `lowercased()` maps it to
/// the lowercase palochka `ӏ` (U+04CF), which is the form the dictionary
/// lookups and the learning store normalize to.
enum KeyCap: Equatable {
    case character(String)
    case shift
    case backspace
    case numbers    // switch to "123" page
    case symbols    // switch to "#+=" page
    case letters    // switch back to alphabet
    case globe      // input mode switch (required for App Store)
    case emoji      // emoji page (Step 4)
    case settings   // opens the in-keyboard settings panel
    case space
    case `return`
    /// Invisible, non-interactive gap of the given width weight —
    /// used by the symbol rows to center the punctuation cluster.
    case spacer(CGFloat)
}

enum KeyboardPage {
    case letters, numbers, symbols, emoji
}

/// Which letter grid the user types on — user-selectable in the settings
/// panel. `.threeRow` is the original layout. `.fourRow` adds ONE digraph
/// row ABOVE it and changes nothing else: the three existing rows keep
/// every key exactly in place, so muscle memory transfers and switching
/// feels like the same keyboard with an extra row.
enum LayoutStyle: String, CaseIterable {
    case threeRow, fourRow
}

enum KeyboardLayout {

    // MARK: - Letter rows (fixed Avar layouts, defined independently)
    //
    // The two styles are separate specifications — neither derives from
    // the other. Shift layers come from applyCase (first letter only), so
    // «кӏ» previews and inserts «Кӏ», «гь» → «Гь», exactly per the spec.
    //
    // ↓↓↓  ADD OR REORDER KEYS HERE ONLY  ↓↓↓
    private static let threeRowRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","щ","з","х","ъ"].map { .character($0) },  // 12 keys
        ["ф","ӏ","в","а","п","р","о","л","д","ж","э"].map { .character($0) },      // 11 keys
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }
            + [.backspace],
    ]

    private static let fourRowRows: [[KeyCap]] = [
        ["гъ","хъ","къ","кӏ","тӏ","цӏ","чӏ","хӏ","гӏ","кь","хь"].map { .character($0) },  // 11 keys
        ["й","ц","у","к","е","н","г","ш","щ","з","х"].map { .character($0) },              // 11 keys
        ["ф","лъ","в","а","п","р","о","л","д","ж","э"].map { .character($0) },             // 11 keys
        [.shift]
            + ["я","ч","с","м","и","т","гь","б","ю"].map { KeyCap.character($0) }
            + [.backspace],
    ]
    // ↑↑↑  -----------------------------------  ↑↑↑

    static func letterRows(style: LayoutStyle) -> [[KeyCap]] {
        switch style {
        case .threeRow: return threeRowRows
        case .fourRow:  return fourRowRows
        }
    }

    // MARK: - Vertical geometry per style

    /// The vertical numbers the keyboard is built from. `.threeRow` is the
    /// original hand-tuned geometry and must stay frozen. `.fourRow` keeps
    /// the SAME key height and row gap — the familiar rows are not
    /// compressed at all — and pays for its extra row purely in keyboard
    /// height: 36 bar + 8 gap + 5×43 keys + 4×11 gaps + the same 1 pt of
    /// slack the original budget carries = 304.
    struct Metrics: Equatable {
        let totalHeight: CGFloat
        let keyHeight: CGFloat
        let rowSpacing: CGFloat
        /// Emoji page grid: emojis per column and the cell height. The
        /// taller 4-row keyboard fits one more emoji per column in
        /// slightly taller cells, so the grid fills the same content area
        /// as the letter/symbol pages and the category bar stays put.
        let emojiRows: Int
        let emojiCellHeight: CGFloat
    }

    static func metrics(for style: LayoutStyle) -> Metrics {
        switch style {
        case .threeRow: return Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11,
                                       emojiRows: 5, emojiCellHeight: 33)
        case .fourRow:  return Metrics(totalHeight: 304, keyHeight: 43, rowSpacing: 11,
                                       emojiRows: 6, emojiCellHeight: 36)
        }
    }

    // MARK: - Symbol pages, per style
    //
    // The 4-row style's symbol pages carry four rows so the keyboard's
    // vertical geometry never moves when switching ABC ↔ 123: letters and
    // symbols always have the same row count per style. The extra rows
    // hold the full currency set and the typographic/math characters from
    // the long-press inventory — visible AND still on long-press.

    private static let punctuationRow: [KeyCap] =
        [.symbols, .spacer(0.25)]
            + [".",",","?","!","'"].map { KeyCap.character($0) }
            + [.spacer(0.25), .backspace]

    private static let punctuationRowSymbols: [KeyCap] =
        [.numbers, .spacer(0.25)]
            + [".",",","?","!","'"].map { KeyCap.character($0) }
            + [.spacer(0.25), .backspace]

    private static let threeRowNumberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        punctuationRow,
    ]

    private static let fourRowNumberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        ["$","€","£","¥","￦","°","№","«","»","…"].map { .character($0) },
        punctuationRow,
    ]

    private static let threeRowSymbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","$","€","¥","•"].map { .character($0) },
        punctuationRowSymbols,
    ]

    private static let fourRowSymbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","•","–","—","§"].map { .character($0) },
        ["≠","≈","‰","∞","¿","¡","’","„","“","”"].map { .character($0) },
        punctuationRowSymbols,
    ]

    static func numberRows(style: LayoutStyle) -> [[KeyCap]] {
        switch style {
        case .threeRow: return threeRowNumberRows
        case .fourRow:  return fourRowNumberRows
        }
    }

    static func symbolRows(style: LayoutStyle) -> [[KeyCap]] {
        switch style {
        case .threeRow: return threeRowSymbolRows
        case .fourRow:  return fourRowSymbolRows
        }
    }

    // MARK: - Long-press callouts, per style
    // Alternates are inserted as a whole string; the popup auto-prepends
    // the base key, so alternates never repeat it. Uppercase variants are
    // derived mechanically: the bubble and the insertion both run the
    // selected option through applyCase, so «Лъ» offers «Лӏ Ы» from the
    // same lowercase entries. These maps reproduce the ava-3-rows /
    // ava-4-rows long-press specification natively: the shared block is
    // the digraph sets, the accented vowels, and the symbol variants; the
    // 3-row style adds ӏ→ы (it has a standalone ӏ key), and the 4-row
    // style adds component access on its digraph keys because standalone
    // ь, ъ and ӏ have no dedicated keys there. The slash deliberately has
    // no alternatives.
    private static let sharedCallouts: [String: [String]] = [
        // Digraphs on the base letters
        "ц": ["цӏ"],
        "к": ["кӏ", "къ", "кь"],
        "г": ["гӏ", "гъ", "гь"],
        "х": ["хӏ", "хъ", "хь"],
        "л": ["лъ", "лӏ"],
        "ч": ["чӏ"],
        "т": ["тӏ"],
        // Vowels: existing alternates first, stress accent appended
        "а": ["а\u{0301}"],
        "е": ["ё", "е\u{0301}"],
        "и": ["ы", "и\u{0301}"],
        "о": ["о\u{0301}"],
        "у": ["у\u{0301}"],
        "э": ["э\u{0301}"],
        "я": ["я\u{0301}"],
        "ю": ["ю\u{0301}"],
        // Symbols
        "0": ["°"],
        "₽": ["$", "€", "£", "¥", "￦"],
        "#": ["№"],
        ".": ["…"],
        "%": ["‰", "∞"],
        "=": ["≠", "≈"],
        "-": ["•", "–", "—"],
        "&": ["§"],
        "?": ["¿"],
        "!": ["¡"],
        "'": ["’", "‘", "`"],
        "\"": ["”", "“", "„", "»", "«"],
    ]

    static func callouts(style: LayoutStyle) -> [String: [String]] {
        switch style {
        case .threeRow:
            return sharedCallouts.merging(["ӏ": ["ы"]]) { current, _ in current }
        case .fourRow:
            return sharedCallouts.merging([
                "гь": ["ь", "ъ"],
                "гъ": ["ъ"],
                "кӏ": ["ӏ"],
                "лъ": ["лӏ", "ы"],
            ]) { current, _ in current }
        }
    }

    /// Union of both styles' maps — the single style-blind source the
    /// engine derives its digraph tails from (Normalization, LearnedWords).
    /// Never used for rendering.
    static let callouts: [String: [String]] =
        callouts(style: .fourRow)
            .merging(callouts(style: .threeRow)) { fourRow, _ in fourRow }

    // MARK: - Case helpers

    /// Capitalizes only the first character — correct for digraphs: "къ" → "Къ", "лъ" → "Лъ".
    static func capitalizedFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return String(f).uppercased() + s.dropFirst()
    }

    /// Applies shift state to a string. Use instead of .uppercased().
    /// - capsLock true  → fully uppercase ("къ" → "КЪ")
    /// - capsLock false → first letter only ("къ" → "Къ")
    static func applyCase(_ s: String, capsLock: Bool) -> String {
        capsLock ? s.uppercased() : capitalizedFirst(s)
    }

    // MARK: - Key labels

    static func label(for cap: KeyCap, shifted: Bool, capsLock: Bool = true) -> String {
        switch cap {
        // applyCase keeps digraph keys honest under shift-once: «гъ»
        // previews as «Гъ», not «ГЪ» — exactly what a tap will insert.
        // Single letters are unaffected (first-letter == whole label).
        case .character(let s): return shifted ? applyCase(s, capsLock: capsLock) : s
        case .shift:            return "⇧"
        case .backspace:        return "⌫"
        case .numbers:          return "123"
        case .symbols:          return "#+="
        case .letters:          return shifted ? "АИУ" : "аиу"
        case .globe:            return "🌐"
        case .emoji:            return "😀"
        case .settings:         return ""    // gear icon, rendered by KeyButton
        case .spacer:           return ""
        case .space:            return "Гьоркьобакӏ"
        case .return:           return ""   // ⏎ symbol, drawn by KeyButton
        }
    }

    // MARK: - Key width weight (relative, used as layoutPriority)

    static func weight(_ cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                    return 1.0
        case .shift, .backspace:            return 1.0
        // The «123» / gear / emoji cluster must be exactly equal-sized
        case .settings, .globe, .emoji,
             .numbers, .symbols, .letters:  return 1.2
        case .return:                       return 1.8
        case .space:                        return 4.5
        case .spacer(let w):                return w
        }
    }

    // MARK: - Return key

    /// Action label for the return key, in Avar, per the layout spec's
    /// key-name table. An empty label means "show an icon" — the plain
    /// return key deliberately shows the ⏎ symbol, not a word.
    static func returnLabel(for type: UIReturnKeyType) -> String {
        switch type {
        case .go:               return "Рагьизе"
        case .send:             return "Битӏизе"
        case .done:             return "Лъугӏана"
        case .next:             return "Хадусеб"
        case .`continue`:       return "Цебехун"
        case .join:             return "Цолъизе"
        case .route:            return "Нух"
        case .search:           return "Хъирщи"
        case .emergencyCall:    return "SOS"
        default:                return ""
        }
    }

    /// Return-key width in row units, adapted to its label: icons and
    /// short labels keep the native 1.8, longer labels get more
    /// room so the typography stays readable instead of shrinking. Row
    /// weights normalize against their total, so the space bar absorbs
    /// the difference and the layout stays balanced.
    static func returnKeyWeight(for type: UIReturnKeyType) -> CGFloat {
        returnLabel(for: type).count <= 6 ? 1.8 : 2.3
    }

    // MARK: - Label font size

    static func fontSize(for cap: KeyCap) -> CGFloat {
        switch cap {
        case .character:                   return 22
        case .shift, .backspace,
             .globe, .emoji, .settings:    return 20
        case .space:                       return 13
        case .return:                      return 13
        case .numbers, .symbols, .letters: return 18
        case .spacer:                      return 0
        }
    }

    /// Size for the label actually rendered on the key. Lowercase letters
    /// are optically much smaller than caps at the same point size (x-height
    /// vs cap height), so they get a 1.2× bump to match the native keyboard;
    /// uppercase already matches native one-to-one. Digits and punctuation
    /// have no case and keep the base size.
    static func fontSize(for cap: KeyCap, label: String) -> CGFloat {
        let base = fontSize(for: cap)
        // Digraph keys draw two glyphs in a single-key width; the lowercase
        // bump would overflow the cap, so they step down instead.
        if case .character = cap, label.count > 1 {
            return base * 0.8
        }
        if case .character = cap, label != label.uppercased() {
            return base * 1.2
        }
        return base
    }

    /// Character keys match the native iOS Russian keyboard, tuned by eye
    /// on device: SF's continuous variable axes via a UIKit descriptor,
    /// because SwiftUI's `Font.Weight` only exposes fixed steps and the
    /// match sits between regular (0.0) and medium (0.23). Width is
    /// slightly narrowed the same way (standard 0, condensed -0.2).
    /// All other key labels keep the plain system font.
    private static let characterWeight: CGFloat = 0.19
    private static let characterWidth: CGFloat = -0.1

    static func keyLabelFont(for cap: KeyCap, label: String) -> Font {
        let size = fontSize(for: cap, label: label)
        guard case .character = cap else {
            return .system(size: size)
        }
        let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor
            .addingAttributes([.traits: [
                UIFontDescriptor.TraitKey.weight: characterWeight,
                UIFontDescriptor.TraitKey.width: characterWidth,
            ]])
        return Font(UIFont(descriptor: descriptor, size: size))
    }
}
