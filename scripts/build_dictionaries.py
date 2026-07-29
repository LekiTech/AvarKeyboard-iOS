#!/usr/bin/env python3
"""Builds the two bundled, read-only artifacts the keyboard ships with.

    lezgi_words.sqlite     words + base_score + artifact metadata
    lezgi_bigrams.sqlite   static (prev, word) weights + artifact metadata

Both are regenerated from scratch so a build is reproducible: same input,
byte-identical output. Run from the repo root:

    python3 scripts/build_dictionaries.py            # rebuild both
    python3 scripts/build_dictionaries.py --check    # report, write nothing

WHAT THIS SCRIPT DOES NOT DO
----------------------------
It does not invent linguistic data. Every word keeps base_score = 0
(NEUTRAL_BASE_SCORE) until a reviewed corpus exists, and the bigram
artifact ships empty. Those are the states the runtime must degrade to
cleanly, so they are the states we ship first.

NORMALIZATION
-------------
The canonical form is defined once, here, and mirrored by
Normalization.swift on the runtime side. See docs/ARTIFACT_CONTRACT.md;
the two must be changed together and NORMALIZATION_VERSION bumped.
"""

import argparse
import os
import sqlite3
import sys
import unicodedata
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYBOARD = os.path.join(REPO, "AvarKeyboard", "AvarKeyboardExtension")
WORDS_DB = os.path.join(KEYBOARD, "lezgi_words.sqlite")
BIGRAMS_DB = os.path.join(KEYBOARD, "lezgi_bigrams.sqlite")

# Artifact schema — the shape of the tables. Bump when columns change.
SCHEMA_VERSION = 1
# Data revision — bump on every content change, even without a schema change.
CONTENT_VERSION = 1
# Canonical normalization — bump when the rules below change, which forces
# a rebuild of every artifact and a migration of learned data.
NORMALIZATION_VERSION = 1
# Oldest runtime that can read this artifact correctly.
MIN_READER_SCHEMA = 1

# No corpus yet: every word is equally weighted, so ordering degrades to
# the released behavior (shortest first).
NEUTRAL_BASE_SCORE = 0

PALOCHKA = "ӏ"          # ӏ CYRILLIC SMALL LETTER PALOCHKA — canonical
PALOCHKA_UPPER = "Ӏ"    # Ӏ its uppercase form
# The digit 1 and the pipe are deliberately absent: the runtime half of
# this contract must not repair them, because the keyboard types real
# digits and digit-bearing tokens are rejected outright. Kept identical
# here so the two halves cannot drift.
PALOCHKA_LOOKALIKES = {
    "I", "l", "i",
    "І",                # І CYRILLIC CAPITAL LETTER BYELORUSSIAN-UKRAINIAN I
    "і",                # і its lowercase
    PALOCHKA_UPPER,
}

# Latin letters that are visually identical to a Cyrillic letter. Applied
# ONLY to tokens that are otherwise Cyrillic, so genuine Latin borrowings
# are never mangled.
LATIN_TO_CYRILLIC = {
    "a": "а", "c": "с", "e": "е", "o": "о", "p": "р", "x": "х",
    "y": "у", "k": "к", "m": "м", "t": "т", "b": "ь", "h": "н",
}

# Digraph tails: a tail extends the previous letter instead of counting as
# its own, so "цӏ" and "къ" are ONE Lezgi letter. Mirrors KeyboardLayout.
DIGRAPH_TAILS = {PALOCHKA, "ь", "ъ"}

MAX_WORD_LENGTH = 64


def has_cyrillic(token: str) -> bool:
    return any("Ѐ" <= ch <= "ӿ" for ch in token)


def normalize(token: str) -> str:
    """The canonical form. Mirrored by Normalization.swift — keep in sync."""
    # 1. Unicode NFC, so a decomposed «й» (и + breve) equals the precomposed one.
    token = unicodedata.normalize("NFC", token)
    # 2. Trim; internal whitespace makes a token invalid, not repairable.
    #    NOT str.strip(): Python counts U+001C-U+001F (FS/GS/RS/US) as
    #    whitespace and Swift's whitespacesAndNewlines does not, and U+001F
    #    is the contribution bigram-key separator -- the halves of the
    #    contract must agree exactly on what disappears at the boundary.
    token = trim_like_swift(token)
    # 3. Case-fold to lowercase; this also maps Ӏ (U+04C0) to ӏ (U+04CF).
    token = token.lower()
    # 4. Repair palochka lookalikes, but only inside Cyrillic tokens — a
    #    Latin word containing "i" must stay Latin.
    if has_cyrillic(token):
        token = "".join(PALOCHKA if ch in PALOCHKA_LOOKALIKES else ch for ch in token)
        # 5. Repair Latin homoglyphs in otherwise-Cyrillic tokens.
        token = "".join(LATIN_TO_CYRILLIC.get(ch, ch) for ch in token)
    # NFC again: step 3-5 can only produce precomposed characters, but the
    # second pass makes the function idempotent by construction.
    return unicodedata.normalize("NFC", token)


# What Swift's CharacterSet.whitespacesAndNewlines strips: Unicode space
# separators (Zs), line/paragraph separators (Zl/Zp), and the ASCII/Latin-1
# controls it blesses -- NOT the C0 information separators U+001C-U+001F.
_SWIFT_WHITESPACE = "\t\n\x0b\x0c\r\x85" + "".join(
    chr(cp) for cp in range(0x110000)
    if unicodedata.category(chr(cp)) in ("Zs", "Zl", "Zp")
)


def trim_like_swift(token: str) -> str:
    return token.strip(_SWIFT_WHITESPACE)


def lezgi_letter_count(token: str) -> int:
    return sum(0 if ch in DIGRAPH_TAILS else 1 for ch in token)


def is_unusable(token: str) -> str:
    """Reasons to drop an entry outright. Deliberately narrow: dropping a
    row removes a suggestion users see today, so only entries that cannot
    be typed or would corrupt insertion qualify."""
    if not token:
        return "empty"
    if len(token) > MAX_WORD_LENGTH:
        return "too long"
    if any(ch.isdigit() for ch in token):
        return "contains a digit"
    if any(ch in token for ch in ("@", "/", ".")):
        return "email/path punctuation"
    if any("a" <= ch <= "z" for ch in token):
        return "unrepairable mixed script"
    # Mirrors Normalization.isValidToken: controls (Cc) include U+001F, the
    # contribution bigram-key separator; formats (Cf) are the invisibles
    # that make two identical-looking tokens distinct rows.
    if any(unicodedata.category(ch) in ("Cc", "Cf") for ch in token):
        return "control or format character"
    return ""


def contract_violations(token: str) -> list[str]:
    """Entries that break the canonical token contract but are KEPT, because
    they are reachable in the released keyboard and removing them would
    change suggestions. Reported so the cleanup can be reviewed on its own.

    - single letters / lone digraphs: alphabet rows, not words; today they
      sort first (shortest) and dominate the bar for a one-letter prefix
    - internal whitespace: multi-word phrases; tapping one inserts a phrase
      where the replacement math expects a single token
    """
    issues = []
    if lezgi_letter_count(token) < 2:
        issues.append("fewer than two Lezgi letters")
    if any(ch.isspace() for ch in token):
        issues.append("internal whitespace")
    return issues


def read_source_words(path: str) -> list[str]:
    if not os.path.exists(path):
        return []
    con = sqlite3.connect(path)
    try:
        return [row[0] for row in con.execute("SELECT word FROM words")]
    finally:
        con.close()


def write_meta(con: sqlite3.Connection, rows: int, kind: str) -> None:
    con.execute("CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)")
    con.executemany(
        "INSERT INTO meta(key, value) VALUES(?, ?)",
        [
            ("artifact", kind),
            ("schema_version", str(SCHEMA_VERSION)),
            ("content_version", str(CONTENT_VERSION)),
            ("normalization_version", str(NORMALIZATION_VERSION)),
            ("min_reader_schema", str(MIN_READER_SCHEMA)),
            ("row_count", str(rows)),
            ("generated_at", datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")),
        ],
    )


def build_words(check_only: bool) -> int:
    source = read_source_words(WORDS_DB)
    if not source:
        print("ERROR: no source words found — refusing to write an empty dictionary",
              file=sys.stderr)
        return 1

    repaired, dropped, kept_dirty, seen = [], [], [], {}
    for raw in source:
        norm = normalize(raw)
        if why := is_unusable(norm):
            dropped.append((raw, why))
            continue
        if norm != raw:
            repaired.append((raw, norm))
        if issues := contract_violations(norm):
            kept_dirty.append((norm, ", ".join(issues)))
        seen.setdefault(norm, raw)

    words = sorted(seen)
    merged = len(source) - len(dropped) - len(words)
    print(f"words: {len(source)} in → {len(words)} out "
          f"({len(repaired)} repaired, {merged} merged duplicates, "
          f"{len(dropped)} dropped, {len(kept_dirty)} kept with warnings)")
    for raw, norm in repaired:
        print(f"  repaired {raw!r} → {norm!r}")
    for raw, why in dropped:
        print(f"  DROPPED {raw!r}: {why}")
    if kept_dirty:
        counts: dict[str, int] = {}
        for _, why in kept_dirty:
            counts[why] = counts.get(why, 0) + 1
        for why, n in sorted(counts.items()):
            print(f"  kept {n} entries violating the token contract: {why}")
        print("  (kept on purpose — they are reachable today; removing them "
              "is a separate reviewed data change)")

    if check_only:
        return 0

    tmp = WORDS_DB + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    con = sqlite3.connect(tmp)
    try:
        con.execute("PRAGMA page_size = 4096")
        # base_score is opaque to the runtime: it only orders candidates and
        # is never mixed numerically with personal learning counters.
        # WITHOUT ROWID: the primary key B-tree IS the table, so a prefix
        # scan reads base_score inline — no second lookup, no duplicate
        # index, and a smaller file to page into a memory-capped extension.
        con.execute("""
            CREATE TABLE words(
                word TEXT PRIMARY KEY,
                base_score INTEGER NOT NULL DEFAULT 0
            ) WITHOUT ROWID
        """)
        con.executemany("INSERT INTO words(word, base_score) VALUES(?, ?)",
                        [(w, NEUTRAL_BASE_SCORE) for w in words])
        write_meta(con, len(words), "lezgi_words")
        con.commit()
        con.execute("VACUUM")
    finally:
        con.close()
    os.replace(tmp, WORDS_DB)
    print(f"wrote {WORDS_DB} ({os.path.getsize(WORDS_DB) // 1024} KB)")
    return 0


def build_bigrams(check_only: bool) -> int:
    # Ships EMPTY on purpose: there is no reviewed corpus yet, and the
    # runtime must degrade to the released behavior when no pair matches.
    pairs: list[tuple[str, str, int]] = []
    print(f"bigrams: {len(pairs)} pairs (empty artifact is expected until a "
          f"reviewed corpus exists)")
    if check_only:
        return 0

    tmp = BIGRAMS_DB + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)
    con = sqlite3.connect(tmp)
    try:
        con.execute("PRAGMA page_size = 4096")
        con.execute("""
            CREATE TABLE bigrams(
                prev TEXT NOT NULL,
                word TEXT NOT NULL,
                weight INTEGER NOT NULL,
                PRIMARY KEY(prev, word)
            ) WITHOUT ROWID
        """)
        con.executemany("INSERT INTO bigrams(prev, word, weight) VALUES(?, ?, ?)", pairs)
        write_meta(con, len(pairs), "lezgi_bigrams")
        con.commit()
        con.execute("VACUUM")
    finally:
        con.close()
    os.replace(tmp, BIGRAMS_DB)
    print(f"wrote {BIGRAMS_DB} ({os.path.getsize(BIGRAMS_DB) // 1024} KB)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="report what would change without writing")
    args = parser.parse_args()
    return build_words(args.check) or build_bigrams(args.check)


if __name__ == "__main__":
    raise SystemExit(main())
