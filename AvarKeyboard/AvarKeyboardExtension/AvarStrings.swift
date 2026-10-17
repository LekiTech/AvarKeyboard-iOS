//
//  AvarStrings.swift
//  AvarKeyboardExtension
//
//  Every native Avar string the keyboard draws, its key names and the
//  emoji section titles. Generated once from the released sources
//  (b6a5c53) and reviewed by a native speaker (docs/AVAR_TRANSLATION_REVIEW.md);
//  edit here, never in engine files. The palochka in these strings is the
//  visible form U+04C0 wherever the released UI showed it.
//

import UIKit
import GeneralKeyboard

enum AvarStrings {

    static let strings = KeyboardStrings(
        deleteWordQuestion: { word in "“\(word)” гилдизеищ?" },
        no: "Гуро",
        delete: "Гилдизе",
        emojiRecents: "Ахирисел",
        back: "Нахъе",
        close: "Клавиатура",
        settingsCaption: "АВАР КЛАВИАТУРА",
        settingsTitle: "Рекъезабиял",
        pageInput: "Хъвай",
        pageTheme: "Тема",
        pageDictionary: "Словарь",
        pageAbout: "Клавиатураялъул хӀакъалъулъ",
        sectionLayout: "Раскладка",
        sectionSuggestions: "Малълъиял",
        sectionKeys: "Клавишаби",
        sectionLearning: "Лъазаби",
        sectionLongPress: "БатӀиял хӀарпал (Ӏ, кь, къ…)",
        sectionTheme: "Тема",
        wordSuggestions: "РагӀабазул малълъиял",
        nextWordSuggestion: "Хадусеб рагӀиялъул малълъи",
        autoSpace: "Малълъиялда хадуб пробел",
        doubleSpacePeriod: "КӀиго пробел — тӀанкӀ",
        spaceCursor: "Гьоркьоб бакӀалъул курсор",
        spaceCornerToggle: "Гьоркьоб бакӀалда «авар»",
        spaceCornerToggleSubtitle: String(localized: "Show «авар» on the space bar"),
        learnFast: "Хехаб",
        learnNormal: "ГӀадатаб",
        learnSlow: "Хьадараб",
        learnUses: { count in "\(count) нухалъ" },
        calloutShort: "Къокъаб лъалхъи",
        calloutNormal: "ГӀадатаб лъалхъи",
        calloutLong: "Халатаб лъалхъи",
        // Decimal comma and the Cyrillic «с»: 0.2 → «0,2 с», 0.45 → «0,45 с».
        calloutDuration: { seconds in
            String(format: "%g", seconds).replacingOccurrences(of: ".", with: ",") + " с"
        },
        themeSystem: "Системаялъул",
        themeLight: "КанчӀаб",
        themeDark: "БецӀаб",
        learnedWordsCaption: "лъазарурал рагӀаби",
        noWordsYet: "Жиги рагӀаби гьечӀо",
        deleteAll: "Киналго лъазарурал рагӀаби гилдизе",
        deleteAllQuestion: "Киналго лъазарурал рагӀаби гилдизеищ?",
        aboutInitial: "А",
        aboutTitle: "Авар клавиатура",
        aboutByline: { version in "Версия \(version) · LekiTech" }
    )

    static let keys = KeyLabels(
        space: "ГьоркьобакӀ",
        spaceCornerLabel: "АВАР",
        keyboardName: "Авар мацӀ",
        lettersKey: "аиу",
        lettersKeyShifted: "АИУ",
        emojiPageLettersKey: "АБВ",
        returnLabels: [
            .go: "Рагьизе",
            .send: "БитӀизе",
            .done: "ЛъугӀана",
            .next: "Хадусеб",
            .`continue`: "Цебехун",
            .join: "Цолъизе",
            .route: "Нух",
            .search: "Хъирщи",
            .emergencyCall: "SOS",
        ]
    )

    /// Emoji section titles by catalog id (scripts/gen_emoji.py ids).
    static let emojiCategoryTitles: [String: String] = [
        "smileys": "Гьурмал ва гӀадамал",
        "nature": "ТӀабигӀат",
        "food": "Квен",
        "activity": "ХӀаял",
        "travel": "Сапар",
        "objects": "Жал",
        "symbols": "ГӀаламатал",
        "flags": "Байрахъал",
    ]
}
