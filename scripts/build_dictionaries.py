#!/usr/bin/env python3
"""Builds the two bundled, read-only artifacts the keyboard ships with.

    avar_words.sqlite     words + base_score + artifact metadata
    avar_bigrams.sqlite   static (prev, word) weights + artifact metadata

Both are regenerated from scratch so a build is reproducible: same input,
same output (modulo the generated_at timestamp). Run from the repo root:

    python3 scripts/build_dictionaries.py --source av-ru.dictionary.jsonl
    python3 scripts/build_dictionaries.py --source ... --check   # report only
    python3 scripts/build_dictionaries.py            # repack existing artifacts
    python3 scripts/build_dictionaries.py --check    # verify, write nothing

SOURCE
------
`--source` takes the av-ru dictionary in JSONL form (one JSON object per
line; 22 842 entries). Provenance: docs/av-ru.dictionary.jsonl from
beched/avar-language-expert (upstream avar-me/sources, data/av-ru.jsonl),
lexicographic base — Gimbatov's Avar-Russian dictionary (Makhachkala,
2006). Measurements and decisions: docs/AVAR_DATA_BRIEFING.md.

WHAT GOES INTO EACH ARTIFACT (content_version 2)
------------------------------------------------
Words: `word` ∪ `forms` ∪ `gender_forms` of every entry, minus tokens
starting with "-" (bound enclitic morphemes — never free-standing).

base_score — corpus-frequency dominant, article-size prior as tiebreak:

    base_score(w) = 10 * freq(w) + min(9, prior(w))

where freq(w) counts w in the entries' Avar example sentences (36 845
clean, orthographically reviewed examples) and prior(w) sums, over every
entry whose surface set contains w, that entry's number of senses plus
examples — a lexicographic prior of commonness. The prior is capped
below one frequency unit, so real corpus evidence always outranks it;
homonym entries sum their signals. base_score stays opaque to the
runtime: it only orders candidates within the dictionary tier.

Bigrams: adjacent token pairs inside one example (tokens are Cyrillic
runs with internal hyphens, canonicalized). A pair is kept when both
tokens are contract-valid, both are rows of the words artifact, and the
pair occurs at least MIN_BIGRAM_COUNT times — 89% of raw pairs are
hapaxes and carry no reusable signal. weight = raw count.

Without `--source` the script repacks the existing artifacts verbatim
(preserving scores and pairs) — it never silently degrades data.

NORMALIZATION
-------------
The canonical form is defined once, here, and mirrored by
Normalization.swift on the runtime side. See docs/ARTIFACT_CONTRACT.md;
the two must be changed together and NORMALIZATION_VERSION bumped.
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import unicodedata
from collections import Counter
from datetime import datetime, timezone

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYBOARD = os.path.join(REPO, "AvarKeyboard", "AvarKeyboardExtension")
WORDS_DB = os.path.join(KEYBOARD, "avar_words.sqlite")
BIGRAMS_DB = os.path.join(KEYBOARD, "avar_bigrams.sqlite")

# Artifact schema — the shape of the tables. Bump when columns change.
SCHEMA_VERSION = 1
# Data revision — bump on every content change, even without a schema change.
# v2: base_score from the av-ru example corpus + article-size prior; bigram
# artifact filled from the same corpus (was: neutral scores, empty bigrams).
CONTENT_VERSION = 2
# Canonical normalization — bump when the rules below change, which forces
# a rebuild of every artifact and a migration of learned data.
NORMALIZATION_VERSION = 1
# Oldest runtime that can read this artifact correctly.
MIN_READER_SCHEMA = 1

# Fallback when a word carries no corpus signal at all: 0 = neutral, and
# ordering degrades to the released behavior (shortest first).
NEUTRAL_BASE_SCORE = 0
# Corpus frequency dominates; the lexicographic prior only breaks ties.
FREQ_WEIGHT = 10
PRIOR_CAP = 9
# 89% of raw corpus bigrams are hapaxes — below this count a pair is noise.
MIN_BIGRAM_COUNT = 2

# Tokens inside Avar example sentences: Cyrillic runs, internal hyphens OK.
TOKEN_RE = re.compile(r"[Ѐ-ӿ]+(?:-[Ѐ-ӿ]+)*")

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
# its own, so "цӏ" and "къ" are ONE letter. Mirrors KeyboardLayout.
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


def letter_count(token: str) -> int:
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
    if letter_count(token) < 2:
        issues.append("fewer than two letters")
    if any(ch.isspace() for ch in token):
        issues.append("internal whitespace")
    return issues


def read_artifact_words(path: str) -> list[tuple[str, int]]:
    if not os.path.exists(path):
        return []
    con = sqlite3.connect(path)
    try:
        return list(con.execute("SELECT word, base_score FROM words"))
    finally:
        con.close()


def read_artifact_bigrams(path: str) -> list[tuple[str, str, int]]:
    if not os.path.exists(path):
        return []
    con = sqlite3.connect(path)
    try:
        return list(con.execute("SELECT prev, word, weight FROM bigrams"))
    finally:
        con.close()


class SourceData:
    """Everything derived from the av-ru JSONL in one pass."""

    def __init__(self, path: str):
        self.surface_raw: list[str] = []      # word ∪ forms ∪ gender_forms, raw
        self.prior: Counter = Counter()       # normalized surface → summed prior
        self.freq: Counter = Counter()        # normalized corpus token → count
        self.raw_bigrams: Counter = Counter() # (prev, word) → count
        self.enclitics_skipped = 0
        self.example_count = 0

        with open(path, encoding="utf-8") as f:
            for line in f:
                entry = json.loads(line)
                surfaces = ([entry["word"]] + entry.get("forms", [])
                            + entry.get("gender_forms", []))
                kept = []
                for token in surfaces:
                    # Hyphen-initial entries are bound enclitic morphemes
                    # (-ги, -цин, …): real morphology, but never free-standing
                    # tokens, so they are not dictionary rows.
                    if token.startswith("-"):
                        self.enclitics_skipped += 1
                        continue
                    kept.append(token)
                self.surface_raw.extend(kept)

                senses = entry.get("senses", [])
                examples = [ex.get("av", "")
                            for s in senses for ex in s.get("examples", [])]
                # Lexicographic prior: bigger articles describe commoner
                # words. Propagated from the headword to every form; homonym
                # entries with the same surface simply sum.
                prior = len(senses) + len(examples)
                for token in {normalize(t) for t in kept}:
                    self.prior[token] += prior

                for av in examples:
                    self.example_count += 1
                    tokens = [normalize(t) for t in TOKEN_RE.findall(av)]
                    self.freq.update(tokens)
                    for pair in zip(tokens, tokens[1:]):
                        self.raw_bigrams[pair] += 1

    def base_score(self, word: str) -> int:
        score = FREQ_WEIGHT * self.freq.get(word, 0) + min(PRIOR_CAP, self.prior.get(word, 0))
        return score if score else NEUTRAL_BASE_SCORE


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


def build_words(check_only: bool, source: "SourceData | None") -> int:
    if source is not None:
        raw_words = source.surface_raw
    else:
        raw_words = [w for w, _ in read_artifact_words(WORDS_DB)]
    if not raw_words:
        print("ERROR: no source words found — refusing to write an empty dictionary",
              file=sys.stderr)
        return 1

    repaired, dropped, kept_dirty, seen = [], [], [], {}
    for raw in raw_words:
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
    if source is not None:
        rows = [(w, source.base_score(w)) for w in words]
    else:
        # Repack: preserve the scores already shipped.
        existing = dict(read_artifact_words(WORDS_DB))
        rows = [(w, existing.get(w, NEUTRAL_BASE_SCORE)) for w in words]

    merged = len(raw_words) - len(dropped) - len(words)
    scored = sum(1 for _, s in rows if s > 0)
    print(f"words: {len(raw_words)} in → {len(words)} out "
          f"({len(repaired)} repaired, {merged} merged duplicates, "
          f"{len(dropped)} dropped, {len(kept_dirty)} kept with warnings); "
          f"{scored} rows carry a base_score signal")
    if source is not None:
        print(f"  enclitic tokens skipped: {source.enclitics_skipped}")
        # The word SET must not drift when only scores change: compare
        # against the artifact being replaced.
        old = {w for w, _ in read_artifact_words(WORDS_DB)}
        if old:
            added, removed = sorted(set(words) - old), sorted(old - set(words))
            print(f"  word-set drift vs shipped artifact: +{len(added)} -{len(removed)}")
            for w in added[:10]:
                print(f"    + {w!r}")
            for w in removed[:10]:
                print(f"    - {w!r}")
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
        con.executemany("INSERT INTO words(word, base_score) VALUES(?, ?)", rows)
        write_meta(con, len(words), "avar_words")
        con.commit()
        con.execute("VACUUM")
    finally:
        con.close()
    os.replace(tmp, WORDS_DB)
    print(f"wrote {WORDS_DB} ({os.path.getsize(WORDS_DB) // 1024} KB)")
    return 0


def build_bigrams(check_only: bool, source: "SourceData | None",
                  words_in_artifact: set[str]) -> int:
    if source is not None:
        # Both tokens must be contract-valid, and `word` must be a row of
        # the words artifact: nextWords surfaces it directly, so it must
        # never suggest an out-of-dictionary string. `prev` is only ever a
        # lookup key compared against what the user actually typed, so an
        # out-of-dictionary prev (an inflected form the dictionary lacks)
        # is still a perfectly good key. Hapax pairs are dropped: with 89%
        # of raw pairs seen once, they are noise, not reusable context.
        dropped_invalid = dropped_unknown = dropped_rare = 0
        pairs = []
        for (prev, word), count in sorted(source.raw_bigrams.items()):
            if count < MIN_BIGRAM_COUNT:
                dropped_rare += 1
                continue
            if any(is_unusable(t) or contract_violations(t) for t in (prev, word)):
                dropped_invalid += 1
                continue
            if word not in words_in_artifact:
                dropped_unknown += 1
                continue
            pairs.append((prev, word, count))
        print(f"bigrams: {len(source.raw_bigrams)} raw pairs from "
              f"{source.example_count} examples → {len(pairs)} kept "
              f"({dropped_rare} below count {MIN_BIGRAM_COUNT}, "
              f"{dropped_invalid} contract-invalid, "
              f"{dropped_unknown} with out-of-dictionary tokens)")
        for (prev, word), count in source.raw_bigrams.most_common(5):
            print(f"  top: {prev!r} {word!r} × {count}")
    else:
        # Repack: preserve the pairs already shipped.
        pairs = sorted(read_artifact_bigrams(BIGRAMS_DB))
        print(f"bigrams: repacking {len(pairs)} existing pairs")
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
        write_meta(con, len(pairs), "avar_bigrams")
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
    parser.add_argument("--source", metavar="JSONL",
                        help="av-ru dictionary in JSONL form; without it the "
                             "existing artifacts are repacked verbatim")
    args = parser.parse_args()

    source = SourceData(args.source) if args.source else None
    status = build_words(args.check, source)
    if status:
        return status
    if source is not None:
        # The bigram membership gate uses the words that were just written
        # (or would be written, under --check): recompute the same set.
        words = set()
        for raw in source.surface_raw:
            norm = normalize(raw)
            if not is_unusable(norm):
                words.add(norm)
    else:
        words = {w for w, _ in read_artifact_words(WORDS_DB)}
    return build_bigrams(args.check, source, words)


if __name__ == "__main__":
    raise SystemExit(main())
