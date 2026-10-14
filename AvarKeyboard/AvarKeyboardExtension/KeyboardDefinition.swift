//
//  KeyboardDefinition.swift
//  AvarKeyboardExtension
//
//  The boundary between the keyboard engine and one concrete language
//  keyboard (GENERAL_KEYBOARD_DESIGN.md §2). Everything the engine needs to
//  know about a language or a product arrives through a single value of
//  this type: layouts, key labels, native UI strings, the dictionary
//  artifacts, the App Group, the presentation conventions and the
//  normalization profile. Engine files do not spell any of those; the
//  exceptions are deliberate and tested (DefinitionTests): the built-in
//  normalization profile and one frozen historical migration. Two engine
//  conventions are not yet configurable — the «…» quoting of an unknown
//  word and the tokenizer's separator set — and are listed for Phase 2.
//
//  Phase 1: engine and definition still share one module, so the product
//  binds `KeyboardDefinition.current` statically (AvarDefinition.swift).
//  Phase 2 moves the engine into the General Keyboard package and replaces
//  that binding with installation by the product's principal class.
//

import UIKit

struct KeyboardDefinition: Sendable {
    var data: LanguageData
    var layout: LayoutCapabilities
    var keys: KeyLabels
    var text: TextConventions
    var normalization: NormalizationProfile
    var strings: KeyboardStrings
    /// Native section titles of the emoji catalog, keyed by `EmojiCategory.id`.
    var emojiCategoryTitles: [String: String]

    /// Structural problems a product definition must not ship with. Checked
    /// by the product's definition tests; never enforced at runtime, so a
    /// definition mistake can never take a running keyboard down.
    func validationErrors() -> [String] {
        var errors = layout.validationErrors()
        for category in EmojiData.categories where emojiCategoryTitles[category.id] == nil {
            errors.append("no emoji title for category \(category.id)")
        }
        for key in emojiCategoryTitles.keys
        where !EmojiData.categories.contains(where: { $0.id == key }) {
            errors.append("emoji title for unknown category \(key)")
        }
        return errors
    }
}

// MARK: - Data and identity

struct LanguageData: Sendable {
    /// App Group shared by the container app and the keyboard (contribution bridge).
    var appGroupID: String
    /// Bundled dictionary: the resource name without `.sqlite`, which is
    /// also the `artifact` value its meta table must carry.
    var wordsArtifact: String
    /// Bundled static bigrams, same convention.
    var bigramsArtifact: String
    /// Logger subsystem when `Bundle.main` has no identifier (DEBUG-only diagnostics).
    var diagnosticsSubsystem: String
}

/// The running bundle's marketing version, shown in the settings panel. In
/// the keyboard extension `Bundle.main` is the .appex, whose
/// CFBundleShortVersionString is the project's MARKETING_VERSION. Tests
/// assign a fixed value.
enum BundleInfo {
    nonisolated(unsafe) static var marketingVersion: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
}

// MARK: - Layout capabilities

/// Identifier of one letter grid. Open rather than a closed enum: a product
/// names its own styles. The raw value is persisted in UserDefaults, so a
/// shipped style must never be renamed.
struct LayoutStyle: RawRepresentable, Hashable, CaseIterable, CustomStringConvertible, Sendable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    var description: String { rawValue }

    /// Conventional identifiers; any product may define others.
    static let threeRow = LayoutStyle(rawValue: "threeRow")
    static let fourRow = LayoutStyle(rawValue: "fourRow")

    /// The styles the current keyboard offers, in settings order.
    static var allCases: [LayoutStyle] { KeyboardDefinition.current.layout.styles.map(\.id) }
}

/// One complete grid: letter, number and symbol pages, the long-press map,
/// the vertical geometry, and how the style is named in settings.
struct LayoutStyleSpec: Sendable {
    var id: LayoutStyle
    var letterRows: [[KeyCap]]
    var numberRows: [[KeyCap]]
    var symbolRows: [[KeyCap]]
    /// Alternates per base key, lowercase keys; the popup prepends the base.
    var callouts: [String: [String]]
    var metrics: KeyboardLayout.Metrics
    /// Native title of the style's row in the settings panel.
    var settingsTitle: String
    /// Explanatory subtitle (already localized).
    var settingsSubtitle: String
}

struct LayoutCapabilities: Sendable {
    /// Every style the keyboard offers, in settings order. Never empty.
    var styles: [LayoutStyleSpec]
    var defaultStyle: LayoutStyle
    /// Whether the settings panel lets the user switch. Honored only when
    /// more than one style exists.
    var showsStyleSelector: Bool
    /// UserDefaults key holding the chosen style's raw value. Part of the
    /// product's persisted contract — never rename.
    var persistenceKey: String

    var showsSelector: Bool { showsStyleSelector && styles.count > 1 }

    /// The persisted raw value if it names an offered style, else the
    /// default. A value is never rewritten until the user picks a style.
    func resolve(_ raw: String?) -> LayoutStyle {
        guard let raw, let match = styles.first(where: { $0.id.rawValue == raw })
        else { return defaultStyle }
        return match.id
    }

    func spec(for style: LayoutStyle) -> LayoutStyleSpec {
        styles.first { $0.id == style }
            ?? styles.first { $0.id == defaultStyle }
            ?? styles[0]
    }

    /// Every style's callouts in one map, later styles winning on a shared
    /// key — the style-blind view the definition tests check the digraph
    /// tails against. Never used for rendering.
    var calloutUnion: [String: [String]] {
        styles.reduce(into: [:]) { union, spec in
            union.merge(spec.callouts) { _, later in later }
        }
    }

    func validationErrors() -> [String] {
        var errors: [String] = []
        if styles.isEmpty { errors.append("no layout styles") }
        if Set(styles.map(\.id)).count != styles.count { errors.append("duplicate style ids") }
        if !styles.contains(where: { $0.id == defaultStyle }) {
            errors.append("default style \(defaultStyle) is not offered")
        }
        for spec in styles {
            if spec.numberRows.count != spec.symbolRows.count {
                errors.append("\(spec.id): number and symbol pages differ in row count")
            }
            if spec.letterRows.count != spec.numberRows.count {
                errors.append("\(spec.id): letter and number pages differ in row count")
            }
            for key in spec.callouts.keys where key != key.lowercased() {
                errors.append("\(spec.id): callout key \(key) is not lowercase")
            }
        }
        return errors
    }
}

// MARK: - Keys, presentation, strings

struct KeyLabels: Sendable {
    /// `KeyboardLayout.label(for: .space)`; the bar itself draws `spaceCornerLabel`.
    var space: String
    /// Small label in the space bar's corner (settings toggle `spaceLabel`).
    var spaceCornerLabel: String
    /// Flashed in the middle of the space bar when the keyboard appears.
    var keyboardName: String
    /// The «back to letters» key on the number and symbol pages.
    var lettersKey: String
    var lettersKeyShifted: String
    /// The «back to letters» item in the emoji category bar.
    var emojiPageLettersKey: String
    /// Action labels; a missing type shows the return icon. `.search`
    /// always draws the magnifying glass — its label only sets the key's
    /// width (KeyboardLayout.returnKeyWeight).
    var returnLabels: [UIReturnKeyType: String]
}

struct TextConventions: Sendable {
    /// The form the canonical palochka is SHOWN in (suggestions, saved
    /// words). Stored rows keep the canonical form. nil shows it as stored.
    var visiblePalochka: Character?
    /// Letters that never vote in the ALL-CAPS test of a typed prefix.
    var caseNeutral: Set<Character>

    func visibleForm(_ word: String, canonicalPalochka: Character?) -> String {
        guard let visible = visiblePalochka, let canonical = canonicalPalochka else { return word }
        return word.replacingOccurrences(of: String(canonical), with: String(visible))
    }
}

/// Every native-language string the keyboard draws. Explanatory subtitles
/// that follow the system language stay in the engine's string catalog,
/// except the ones that name the language (supplied here, localized).
struct KeyboardStrings: Sendable {
    // Suggestion bar
    var deleteWordQuestion: @Sendable (String) -> String
    var no: String
    var delete: String
    // Emoji page
    var emojiRecents: String
    // Settings panel: chrome
    var back: String
    var close: String
    var settingsCaption: String
    var settingsTitle: String
    var pageInput: String
    var pageTheme: String
    var pageDictionary: String
    var pageAbout: String
    // Settings panel: sections
    var sectionLayout: String
    var sectionSuggestions: String
    var sectionKeys: String
    var sectionLearning: String
    var sectionLongPress: String
    var sectionTheme: String
    // Settings panel: toggles
    var wordSuggestions: String
    var nextWordSuggestion: String
    var autoSpace: String
    var doubleSpacePeriod: String
    var spaceCursor: String
    var spaceCornerToggle: String
    var spaceCornerToggleSubtitle: String
    // Learning speed
    var learnFast: String
    var learnNormal: String
    var learnSlow: String
    /// «N uses», given the engine's threshold for a speed (1, 3, 5).
    var learnUses: @Sendable (Int) -> String
    // Long-press delay
    var calloutShort: String
    var calloutNormal: String
    var calloutLong: String
    /// The delay in the language's notation, given the engine's seconds.
    var calloutDuration: @Sendable (Double) -> String
    // Theme
    var themeSystem: String
    var themeLight: String
    var themeDark: String
    // Dictionary page
    var learnedWordsCaption: String
    var noWordsYet: String
    var deleteAll: String
    var deleteAllQuestion: String
    // About page
    var aboutInitial: String
    var aboutTitle: String
    var aboutByline: @Sendable (String) -> String
}
