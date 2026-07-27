# Avar Keyboard for iOS

A native iOS keyboard for the Avar language (авар мацӏ) with a sticker pack
of a friendly eagle in a papakha — developed by [LekiTech](https://github.com/LekiTech).

> **Project status.** This project reuses the engine of the
> [Lezgi Keyboard](https://github.com/LekiTech) codebase under a new identity
> (Avar Keyboard, `org.lekitech.avarkeyboard`). The **fixed Avar layout and
> long-press callouts are in place** (`AvarKeyboardExtension/KeyboardLayout.swift`),
> and the keyboard engine, suggestions, on-device learning, emoji, stickers,
> themes, settings, and localization system are fully functional. The
> remaining Avar resources are marked with `TODO(Avar)` comments:
>
> - built-in dictionary (`avar_words.sqlite`) — `AvarKeyboardExtension/WordSuggestions.swift`
>   (the bundled dictionary is temporarily still the inherited Lezgi one)
> - learning corpus / bigram seed data (optional) — `AvarKeyboardExtension/LearnedWords.swift`
> - localization review: in-keyboard UI strings, key labels, and emoji
>   category titles — `KeyboardLayout.swift`, `KeyboardView.swift`,
>   `SettingsPanelView.swift`, `EmojiData.swift` / `scripts/gen_emoji.py`
> - sticker artwork ("lezginka", "lezgiflag") — `StickerSharing.swift`,
>   `scripts/gen_stickers.swift`, `scripts/gen_messenger_stickers.py`

## The Keyboard

- Palochka (Ӏ) and digraphs are one long press away
- Word suggestions from an offline dictionary, plus the words and word pairs
  it learns from your own typing — including next-word suggestions. Learning
  works entirely on-device and does not depend on the built-in dictionary
- Matches the native iOS keyboard down to the details: key preview bubbles,
  callout menus with swipe selection, caps lock, auto-capitalization,
  spacebar cursor control, hold-to-repeat delete
- Full emoji page with categories and recents
- Localized in English and Russian
- Private by design: the keyboard never asks for Full Access and sends
  nothing anywhere. All learning happens on this device only — no network,
  no server, nothing you type is uploaded. Learned words live in the
  keyboard's own storage, can be managed and reset anytime from the
  keyboard's gear key (settings → dictionary), and are deleted together
  with the app

## The Stickers

Twenty illustrated stickers of an eagle chick in a papakha.

- In **iMessage** the pack appears automatically alongside the keyboard
- In **WhatsApp** and **Telegram** the pack is added with one tap from the app
  and lives in the messenger's own sticker panel

## Project layout

- `AvarKeyboard/AvarKeyboard.xcodeproj` — Xcode project (3 targets)
- `AvarKeyboard/AvarKeyboard/` — containing app (onboarding, sticker sharing)
- `AvarKeyboard/AvarKeyboardExtension/` — the keyboard extension
- `AvarKeyboard/AvarStickers/` — iMessage sticker pack target
- `AvarStickers/` — 1024×1024 source sticker PNGs
- `scripts/` — asset generators (emoji data, sticker packs)
- `docs/` — engine documentation inherited from the Lezgi project

## Third-party components

- [TelegramStickersImport](https://github.com/TelegramMessenger/TelegramStickersImport)
  (MIT) — Telegram sticker pack export
- Emoji catalog data derived from Unicode® `emoji-test.txt`

## Organization

Developed by [LekiTech](https://github.com/LekiTech) — a team building
digital tools for the languages of Dagestan.
