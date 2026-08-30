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

    // MARK: - Letter rows (fixed Avar layout)
    //
    // ↓↓↓  ADD OR REORDER KEYS HERE ONLY  ↓↓↓
    static let letterRows: [[KeyCap]] = [
        ["й","ц","у","к","е","н","г","ш","щ","з","х"].map { .character($0) },  // 11 keys
        ["ъ","Ӏ","в","а","п","р","о","л","д","ж","э"].map { .character($0) },  // 11 keys
        [.shift]
            + ["я","ч","с","м","и","т","ь","б","ю"].map { KeyCap.character($0) }
            + [.backspace],
    ]
    // ↑↑↑  -----------------------------------  ↑↑↑

    /// The extra top row of the `.fourRow` style: every Avar digraph that
    /// already exists as a long-press alternate, now also one tap away.
    /// Palochka digraphs use the visible Ӏ (U+04C0) like the callouts, so
    /// a digraph key inserts exactly the same text as its callout twin —
    /// the engine cannot tell them apart. Callouts stay active in both
    /// styles; this row never replaces them.
    static let digraphRow: [KeyCap] =
        ["гъ","хъ","къ","кӀ","тӀ","цӀ","чӀ","хӀ","гӀ","кь","хь"].map { .character($0) }  // 11 keys

    /// Letter rows for the chosen style. `.threeRow` returns `letterRows`
    /// unchanged; `.fourRow` prepends the digraph row and touches nothing
    /// else.
    static func letterRows(style: LayoutStyle) -> [[KeyCap]] {
        switch style {
        case .threeRow: return letterRows
        case .fourRow:  return [digraphRow] + letterRows
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
    }

    static func metrics(for style: LayoutStyle) -> Metrics {
        switch style {
        case .threeRow: return Metrics(totalHeight: 250, keyHeight: 43, rowSpacing: 11)
        case .fourRow:  return Metrics(totalHeight: 304, keyHeight: 43, rowSpacing: 11)
        }
    }

    // MARK: - Number page ("123") — standard iOS set
    static let numberRows: [[KeyCap]] = [
        ["1","2","3","4","5","6","7","8","9","0"].map { .character($0) },
        ["-","/",":",";","(",")","₽","&","@","\""].map { .character($0) },
        [.symbols] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Symbol page ("#+=") — standard iOS set
    static let symbolRows: [[KeyCap]] = [
        ["[","]","{","}","#","%","^","*","+","="].map { .character($0) },
        ["_","\\","|","~","<",">","€","£","¥","•"].map { .character($0) },
        [.numbers] + [".",",","?","!","'"].map { KeyCap.character($0) } + [.backspace],
    ]

    // MARK: - Long-press callouts (Step 3)
    // Alternates are inserted as a whole string (e.g. "цӀ" = ц + palochka U+04C0).
    static let callouts: [String: [String]] = [
        "ц": ["цӀ"],
        "к": ["кӀ", "къ", "кь"],
        "е": ["ё"],
        "г": ["гӀ", "гъ", "гь"],
        "х": ["хӀ", "хъ", "хь"],
        "п": ["ф"],
        "л": ["лъ", "лӀ"],
        "ч": ["чӀ"],
        "и": ["ы"],
        "т": ["тӀ"]
    ]

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
        case .letters:          return "АБВ"
        case .globe:            return "🌐"
        case .emoji:            return "😀"
        case .settings:         return ""    // gear icon, rendered by KeyButton
        case .space:            return "Гьоркьоб бакӀ"
        case .return:           return "Ввод"
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
        }
    }

    // MARK: - Return key

    /// Action label for the return key, in Avar. `.search` is empty on
    /// purpose: it renders as the universal magnifying-glass icon — the
    /// familiar convention on modern keyboards. An empty label means
    /// "show an icon".
    static func returnLabel(for type: UIReturnKeyType) -> String {
        switch type {
        case .go:               return "Ине"
        case .send:             return "БитӀизе"
        case .done:             return "ЛъугӀана"
        case .next:             return "Хадусеб"
        case .`continue`:       return "Цебе бачине"
        case .join:             return "Лъугьине"
        case .route:            return "Нух"
        case .emergencyCall:    return "Кумекалъе ахӀи"
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
