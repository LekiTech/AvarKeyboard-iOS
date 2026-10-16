# Avar Keyboard for iOS

A native iOS keyboard for the Avar language (авар мацӀ) with a sticker pack
of a friendly eagle in a papakha — developed by [LekiTech](https://github.com/LekiTech).

> **Project status.** The keyboard engine is the shared
> **General Keyboard** Swift Package (`GeneralKeyboard-iOS`), which grew out
> of the [Lezgi Keyboard](https://github.com/LekiTech) codebase; this
> repository holds the Avar product on top of it (Avar Keyboard,
> `org.lekitech.avarkeyboard`). The **fixed Avar layout and
> long-press callouts are in place** (`AvarKeyboardExtension/AvarLayout.swift`)
> and the keyboard ships a **63,879-word Avar dictionary** with
> corpus-derived `base_score` ranking plus a **5,101-pair static bigram
> artifact**, both versioned artifacts built by
> `scripts/build_dictionaries.py` from the av-ru dictionary source
> (`docs/ARTIFACT_CONTRACT.md`, `docs/AVAR_DATA_BRIEFING.md`), alongside
> the hardened learned store, migration registry, and the inert contribution
> outbox/bridge inherited from the shared engine. Remaining `TODO(Avar)` work:
>
> - native-speaker review of the new Avar UI strings —
>   `docs/AVAR_TRANSLATION_REVIEW.md`
> - native Avar app name for the ru localization —
>   `AvarKeyboard/AvarKeyboard/Localizable.xcstrings`
>
> The in-keyboard UI now speaks Avar (pending native review), and the
> flag sticker is the Avar flag. The "lezginka" sticker name is kept
> deliberately — it names the pan-Caucasian dance, not the Lezgi people.

## The Keyboard

- Palochka (Ӏ) and digraphs are one long press away
- Two layout styles, switchable in the keyboard's settings: a compact
  3-row grid (ъ and ӏ as direct keys, digraphs on long-press), or a
  4-row grid with a dedicated digraph row on top plus лъ and гь keys
  (their components ь, ъ, ӏ stay one long-press away)
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
- `AvarKeyboard/AvarKeyboardExtension/` — the keyboard extension: the Avar
  `KeyboardDefinition` (`AvarDefinition`, `AvarLayout`, `AvarStrings`,
  `AvarIdentity`), the principal class, the dictionary artifacts and plists.
  Engine code lives in General Keyboard, linked as a local Swift Package
  (see [Building](#building))
- `Package.swift`, `Tests/AvarCoreTests/` — product tests (definition,
  persisted-state characterization, pixel snapshots, shipped artifacts),
  run through the General Keyboard engine
- `AvarKeyboard/AvarStickers/` — iMessage sticker pack target
- `AvarStickers/` — 1024×1024 source sticker PNGs
- `scripts/` — dictionary build and sticker pack generators (the emoji
  catalog generator moved to General Keyboard)
- `docs/` — product documents, plus engine documentation inherited from the
  Lezgi project (the maintained copies live in `GeneralKeyboard-iOS/docs/engine/`)

## Building

The keyboard engine is the shared **General Keyboard** Swift Package,
`GeneralKeyboard-iOS`, a private LekiTech repository; building needs read
access to it. Clone it next to this repository and use the `main` branches
of both:

```
<workspace>/
  GeneralKeyboard-iOS/   git clone https://github.com/LekiTech/GeneralKeyboard-iOS.git
  AvarKeyboard-iOS/      this repository
```

The Xcode project finds the package at `../../GeneralKeyboard-iOS`
(relative to `AvarKeyboard/AvarKeyboard.xcodeproj`) and `Package.swift` at
`../GeneralKeyboard-iOS`. The product tests run with:

```
xcodebuild test -scheme AvarCoreTests-Package \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0'
```

## Third-party components

- [TelegramStickersImport](https://github.com/TelegramMessenger/TelegramStickersImport)
  (MIT) — Telegram sticker pack export
- Emoji catalog data derived from Unicode® `emoji-test.txt`

## Organization

Developed by [LekiTech](https://github.com/LekiTech) — a team building
digital tools for the languages of Dagestan.
