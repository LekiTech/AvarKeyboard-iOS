# The contribution outbox

Status: **structurally present, functionally inert.**
`Contribution.isEnabled == false` in every build shipped so far, and there
is no exporter, no App Group write, no networking, and no background task
anywhere in the target. This document describes what the queue *is*, so
that the phase which turns it on has a specification to be checked against
rather than a blank page.

---

## 1. Why a queue at all

The long-term goal is a Lezgi corpus improved by the people who actually
write Lezgi. That needs contributions, and contributions need a place to
accumulate between the moment someone types a word and the moment a batch
is offered for review — a place that survives the extension being killed
mid-sentence, which iOS does routinely.

The queue lives in `learned.sqlite`, in the keyboard's own sandbox. Not the
App Group: the App Group is an export bridge for a later phase, and putting
a queue there would mean writing user data outside the extension before
anyone has agreed to anything.

## 2. What may be in it, and what may not

| May hold | May never hold |
|---|---|
| A canonical token | Raw keystrokes |
| A canonical token pair | Sentences, or any span of text |
| `typed` / `picked` / `confirmations` counters | Field contents, passwords, clipboard |
| A batch UUID, per batch, discarded on acknowledgement | Keystroke timings |
| | Device or person identifiers, accounts, ad IDs |

This is enforced structurally rather than by review: the table has exactly
three TEXT columns — `kind` (an enum), `key` (canonical tokens), and
`batch_id` (a UUID) — and everything else is an integer. There is no column
a sentence could fit into.
`ContributionOutboxTests.testEveryColumnIsATokenOrAnInteger` fails if a
fourth text column ever appears, so widening the surface has to be a
deliberate act that deletes an assertion.

## 3. Schema (`schema_version` 2)

```sql
CREATE TABLE outbox(
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    kind          TEXT NOT NULL,           -- word_delta | candidate | bigram_delta
    key           TEXT NOT NULL,           -- canonical token, or prev + U+001F + word
    typed_delta   INTEGER NOT NULL DEFAULT 0,
    picked_delta  INTEGER NOT NULL DEFAULT 0,
    confirmations INTEGER NOT NULL DEFAULT 0,
    first_seen    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL,
    batch_id      TEXT NOT NULL DEFAULT ''  -- '' means unclaimed
);
CREATE UNIQUE INDEX idx_outbox_aggregate ON outbox(kind, key, batch_id);
CREATE INDEX        idx_outbox_unclaimed ON outbox(batch_id, id);
```

`batch_id` is `NOT NULL DEFAULT ''` rather than nullable for a reason worth
recording: **SQLite treats NULLs as distinct inside a UNIQUE index.** With a
nullable column, `(kind, key, NULL)` would never collide with itself, the
upsert would insert a fresh row per event, and the "aggregated queue" would
quietly become a per-keystroke log — precisely the artifact this design
exists to make impossible. The sentinel is what makes aggregation
aggregate.

## 4. Aggregation keys

One row per `(kind, key, batch_id)`, counters accumulated in place.

| Kind | Key | Meaning |
|---|---|---|
| `word_delta` | canonical word | a word already in the bundled dictionary |
| `candidate` | canonical word | a word absent from the dictionary |
| `bigram_delta` | `prev` + U+001F + `word` | an ordered pair, both sides canonical |

U+001F (unit separator) cannot occur in a canonical token, so the bigram key
is unambiguous — pinned by
`testTheSeparatorCannotOccurInACanonicalToken`.

The consequence that matters: **the queue grows with the number of distinct
words a person uses, never with the number of keystrokes.** A hundred
typings of `кӏвал` are one row with `typed = 100`. Typing rhythm, sentence
length, and message boundaries are not merely unrecorded — they are
unrepresentable.

## 5. The gate

Collection requires **all three**, checked together in
`isContributionActive`:

1. `Contribution.isEnabled` — a build-time `let`, currently `false`;
2. `hasContributionConsent` — a `meta` row, absent (and therefore false) on
   every database in the field;
3. `!isReadOnly` — a database from a future schema is never written.

Consent alone collects nothing; the flag alone collects nothing. Both are
tested (`testRecordingIsANoOpWhileTheFlagIsOff`,
`testRecordingIsANoOpWithoutConsent`).

**No historical backfill.** Granting consent starts collection at that
moment; nothing already in `user_word` or `user_bigram` is swept in.
Whatever someone typed before agreeing was typed without an agreement, and
it stays where it is. Pinned by
`testGrantingConsentDoesNotSweepInExistingLearnedData` and, for the upgrade
path, `testTheOutboxStartsEmptyOnAnUpgradedDatabase`.

**Withdrawal empties the queue**, including rows already claimed by a batch
that was never acknowledged.

## 6. Unknown words are held to a higher bar

`candidate` rows carry the sensitive material — names, places, private
coinages, a friend's nickname. They accumulate in the queue like anything
else, but they are **not eligible to enter a batch** until
`confirmations >= Contribution.candidateMinimumConfirmations` (3). A word
typed once, by one person, in one context, never becomes exportable.

Dictionary words are not subject to this bar: their existence is already
public knowledge, and only the counter is new.

## 7. Capacity and retention

| Bound | Value | Behavior |
|---|---|---|
| `maxRows` | 2000 | over capacity, evict lowest `confirmations`, oldest first |
| `retention` | 180 days | rows untouched for longer are dropped |

Pruning runs on write, so it costs nothing when nobody is typing. **Claimed
rows are never pruned** — they belong to a batch that may still be
acknowledged (`testClaimedRowsAreNeverPruned`).

Eviction order is deliberate: under pressure what survives is what the
person actually reuses, not what they happened to type most recently.

## 8. Batch lifecycle

```
enqueue ──► unclaimed ──claim──► batch_id=UUID ──ack──► deleted
                 ▲                     │
                 └──── release ────────┘   (crash, or an upload with no answer)
```

* **Claim** moves up to `limit` eligible rows into a fresh UUID. The UUID is
  generated at claim time, never reused, and disappears on
  acknowledgement — it is **not** a device identifier. It exists so a server
  can recognize a retry of the same batch.
* **Events during an in-flight batch start a fresh unclaimed row**, because
  `batch_id` is part of the uniqueness key. The claimed snapshot never moves
  underneath the exporter that read it, and the new event is not lost
  (`testEventsDuringAnInFlightBatchStartAFreshRow`).
* **Reading a batch twice yields identical rows in identical order**, which
  is what lets a retried upload be byte-identical and therefore safely
  deduplicated server-side.
* **Acknowledge** deletes the batch's rows. Acknowledging an unknown or
  already-acknowledged id deletes nothing and reports nothing wrong, so a
  duplicate reply after a crash is harmless. The unclaimed sentinel is
  explicitly refused, so an empty id can never mean "every unclaimed row"
  (`testAcknowledgingTheUnclaimedSentinelCannotWipeTheQueue`).
* **Release** returns abandoned claims to the queue with counters intact.
  The old batch id then names no rows, so a *late acknowledgement* of it
  deletes nothing that has since been re-queued
  (`testALateAcknowledgementOfAReleasedBatchDeletesNothing`), and a late
  *upload* of it cannot double-count.

The crash case — killed between claim and acknowledgement — is covered end
to end by `testAClaimThatNeverCompletedIsRecoveredOnTheNextLaunch`: nothing
lost, nothing counted twice.

## 9. Not in this phase

No exporter, no serialization format, no App Group write, no
`RequestsOpenAccess` change, no networking, no `BGTaskScheduler`, no consent
UI, no server. Each is its own phase with its own review.

`releaseStaleContributionClaims()` is written and tested but is not yet
called on launch — wiring it in belongs with the exporter that creates
claims in the first place.
