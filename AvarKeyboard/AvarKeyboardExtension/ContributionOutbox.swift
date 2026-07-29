//
//  ContributionOutbox.swift
//  AvarKeyboardExtension
//
//  The local, durable queue of AGGREGATED contributions the keyboard may
//  one day offer to a corpus review process. Nothing here exports, uploads,
//  writes to an App Group, schedules background work, or touches the
//  network — none of that exists yet, and the queue stays empty until both
//  a build-time flag and a user consent state say otherwise.
//
//  WHAT IT MAY HOLD
//    * per-word counters: how many times a word was typed / picked
//    * candidate words absent from the bundled dictionary
//    * per-pair counters for (previous word, next word)
//
//  WHAT IT MUST NEVER HOLD
//    Raw keystrokes, sentences, surrounding text, field contents,
//    passwords, clipboard contents, keystroke timings, or anything
//    identifying a device or a person. Every row is one canonical token
//    (or a pair of them) plus integers. There is deliberately no column a
//    sentence could fit into.
//
//  Rows are AGGREGATED IN PLACE: one row per (kind, key), counters
//  incremented. The queue grows with the number of distinct words a person
//  uses, never with the number of keystrokes — which is what bounds it, and
//  what makes leaking typing rhythm structurally impossible rather than
//  merely unintended.
//

import Foundation
import SQLite3

private let SQLITE_TRANSIENT_OUTBOX = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum ContributionKind: String {
    /// A word already in the bundled dictionary: how often it was typed and
    /// how often it was accepted from the suggestion bar.
    case wordDelta = "word_delta"
    /// A word absent from the dictionary — the sensitive category, since
    /// names, places and private coinages land here. Held to a stricter bar
    /// than the others: see `Contribution.candidateMinimumConfirmations`.
    case candidate = "candidate"
    /// A (previous, next) pair, both sides canonical.
    case bigramDelta = "bigram_delta"
}

enum Contribution {

    /// **The feature flag. Contribution is OFF.**
    ///
    /// While false, `recordContribution` records nothing, so no contribution
    /// data can accumulate before the consent experience exists. Flipping it
    /// alone still sends nothing anywhere: there is no exporter, no App
    /// Group write, and no networking in this target.
    static let isEnabled = false

    /// A candidate word must be confirmed locally this many times before it
    /// may enter a batch. It still accumulates in the queue below that bar —
    /// it simply is not eligible to leave.
    static let candidateMinimumConfirmations = 3

    /// Hard cap on queued rows.
    static let maxRows = 2000

    /// Rows untouched for this long are dropped. A contribution nobody has
    /// reinforced in half a year is stale, and retention should not be
    /// indefinite by default.
    static let retention: TimeInterval = 180 * 24 * 3600

    /// Marks a row as not belonging to any batch.
    ///
    /// Empty string rather than NULL on purpose: SQLite treats NULLs as
    /// distinct inside a UNIQUE index, so `(kind, key, NULL)` would never
    /// collide with itself and the aggregating upsert would silently insert
    /// a new row per event — turning a bounded queue into a per-keystroke
    /// log. The sentinel is what makes aggregation actually aggregate.
    static let unclaimed = ""

    /// Separator between the halves of a bigram key. U+001F is a control
    /// character, and `Normalization.isValidToken` rejects every control and
    /// format character — so no valid token can carry the separator, which
    /// is what makes the encoding injective: the separator's position in a
    /// well-formed key is unique, and two different pairs can never encode
    /// to the same string. `decodeBigramKey` is the enforcement.
    static let keySeparator = "\u{1F}"

    static func bigramKey(previous: String, word: String) -> String {
        previous + keySeparator + word
    }

    /// The exact inverse of `bigramKey`, or nil for anything malformed.
    ///
    /// A valid key splits into exactly two halves, each of which is a
    /// canonical, valid token. Any other shape — zero separators, two
    /// separators, an invalid or non-canonical half — decodes to nothing
    /// rather than to a guess.
    static func decodeBigramKey(_ key: String) -> (previous: String, word: String)? {
        let halves = key.components(separatedBy: keySeparator)
        guard halves.count == 2,
              halves.allSatisfy({ Normalization.isCanonical($0) && Normalization.isValidToken($0) })
        else { return nil }
        return (halves[0], halves[1])
    }

    /// Whether a key may enter the outbox at all. Word keys must be single
    /// canonical valid tokens; bigram keys must decode. Everything else is
    /// refused at the door — a non-canonical key would split aggregation
    /// into parallel rows, and an unparseable one could never be exported.
    static func isAcceptableKey(_ key: String, for kind: ContributionKind) -> Bool {
        switch kind {
        case .wordDelta, .candidate:
            return Normalization.isCanonical(key) && Normalization.isValidToken(key)
        case .bigramDelta:
            return decodeBigramKey(key) != nil
        }
    }
}

extension LearnedWords {

    // MARK: - The gate

    /// Contribution collects only when the build allows it, the user has
    /// opted in, and the store is writable. All three, every time.
    var isContributionActive: Bool {
        Contribution.isEnabled && !isReadOnly && hasContributionConsent
    }

    // MARK: - Recording

    /// Records one aggregated contribution event. The only gated entry point
    /// callers outside this file should use.
    func recordContribution(kind: ContributionKind,
                            key: String,
                            typedDelta: Int = 0,
                            pickedDelta: Int = 0,
                            now: Date = Date()) {
        guard isContributionActive else { return }
        enqueueContribution(kind: kind, key: key, typedDelta: typedDelta,
                            pickedDelta: pickedDelta, now: now)
    }

    /// The ungated primitive, so tests can exercise queue mechanics while
    /// the flag stays a genuine `let false`. Not for production callers:
    /// everything that records real typing goes through
    /// `recordContribution`, which is where the gate lives.
    func enqueueContribution(kind: ContributionKind,
                             key: String,
                             typedDelta: Int = 0,
                             pickedDelta: Int = 0,
                             now: Date = Date()) {
        guard !isReadOnly, Contribution.isAcceptableKey(key, for: kind) else { return }
        let timestamp = Int64(now.timeIntervalSince1970)
        // Aggregation in place. A row already claimed by a batch is left
        // untouched and a fresh unclaimed row starts beside it, so an
        // in-flight batch never changes underneath the export that owns it.
        SQL.run(db, """
            INSERT INTO outbox(kind, key, typed_delta, picked_delta, confirmations,
                               first_seen, updated_at, batch_id)
            VALUES(?1, ?2, \(typedDelta), \(pickedDelta), 1, \(timestamp), \(timestamp), ?3)
            ON CONFLICT(kind, key, batch_id) DO UPDATE SET
                typed_delta = MIN(typed_delta + \(typedDelta), \(Self.counterCeiling)),
                picked_delta = MIN(picked_delta + \(pickedDelta), \(Self.counterCeiling)),
                confirmations = MIN(confirmations + 1, \(Self.counterCeiling)),
                updated_at = \(timestamp)
            """, kind.rawValue, key, Contribution.unclaimed)
        pruneOutbox(now: timestamp)
    }

    private static let counterCeiling = 1_000_000_000

    // MARK: - Consent

    /// Whether the user has explicitly opted in. Absent means false: a
    /// database that predates this column is a database that never agreed.
    var hasContributionConsent: Bool {
        SQL.int(db, "SELECT value FROM meta WHERE key = 'contribution_consent'") == 1
    }

    /// Records the consent decision.
    ///
    /// **No backfill.** Consent starts collection from this moment; nothing
    /// already in `user_word` or `user_bigram` is swept into the queue. What
    /// someone typed before agreeing was typed without an agreement, and it
    /// stays where it is.
    ///
    /// Withdrawal empties the queue, including rows already claimed by a
    /// batch that was never acknowledged.
    func setContributionConsent(_ granted: Bool, now: Date = Date()) {
        guard !isReadOnly else { return }
        SQL.exec(db, "INSERT OR REPLACE INTO meta(key, value) VALUES('contribution_consent', \(granted ? 1 : 0))")
        SQL.exec(db, "INSERT OR REPLACE INTO meta(key, value) VALUES('contribution_since', \(Int64(now.timeIntervalSince1970)))")
        if !granted { SQL.exec(db, "DELETE FROM outbox") }
    }

    // MARK: - Capacity

    /// Drops stale rows, then the least significant rows if still over
    /// capacity. Claimed rows are never pruned: they belong to a batch that
    /// may still be acknowledged.
    private func pruneOutbox(now: Int64) {
        let cutoff = now - Int64(Contribution.retention)
        SQL.run(db, "DELETE FROM outbox WHERE batch_id = ?1 AND updated_at < \(cutoff)",
                Contribution.unclaimed)
        let excess = SQL.int(db, "SELECT COUNT(*) FROM outbox") - Contribution.maxRows
        guard excess > 0 else { return }
        // Least-confirmed first, oldest first among equals: what survives
        // pressure is what the person actually reuses.
        SQL.run(db, """
            DELETE FROM outbox WHERE id IN (
                SELECT id FROM outbox WHERE batch_id = ?1
                ORDER BY confirmations ASC, updated_at ASC, id ASC
                LIMIT \(excess)
            )
            """, Contribution.unclaimed)
    }

    // MARK: - Batch lifecycle
    //
    // Defined and tested now; called by nobody, because the exporter that
    // would call it belongs to a later phase.

    /// Claims up to `limit` eligible unclaimed rows into a new batch.
    ///
    /// The returned id is a fresh UUID generated at claim time. It is **not**
    /// a device identifier: it is never reused, never stored outside the
    /// rows it claims, and disappears when the batch is acknowledged. It
    /// exists only so a server can recognize a retry of the same batch.
    func claimContributionBatch(limit: Int = 500) -> String? {
        guard isContributionActive else { return nil }
        return claimBatch(limit: limit)
    }

    /// Ungated primitive — see `enqueueContribution`.
    func claimBatch(limit: Int = 500) -> String? {
        guard !isReadOnly else { return nil }
        let batchID = UUID().uuidString
        // Candidates below the confirmation bar stay behind: unknown words
        // need repeated independent use before they are worth proposing.
        SQL.run(db, """
            UPDATE outbox SET batch_id = ?1
            WHERE id IN (
                SELECT id FROM outbox
                WHERE batch_id = ?2
                  AND (kind <> '\(ContributionKind.candidate.rawValue)'
                       OR confirmations >= \(Contribution.candidateMinimumConfirmations))
                ORDER BY id LIMIT \(limit)
            )
            """, batchID, Contribution.unclaimed)
        return contributionBatch(batchID).isEmpty ? nil : batchID
    }

    /// The rows belonging to a batch, ready for a future exporter to
    /// serialize. Re-reading the same id yields the same rows in the same
    /// order, which is what lets a retried upload be byte-identical and so
    /// safely deduplicated by a server.
    func contributionBatch(_ batchID: String) -> [(kind: String, key: String,
                                                   typed: Int, picked: Int, confirmations: Int)] {
        var stmt: OpaquePointer?
        let sql = """
            SELECT kind, key, typed_delta, picked_delta, confirmations
            FROM outbox WHERE batch_id = ?1 ORDER BY id
            """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, batchID, -1, SQLITE_TRANSIENT_OUTBOX)
        var rows: [(String, String, Int, Int, Int)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let kind = sqlite3_column_text(stmt, 0),
                  let key = sqlite3_column_text(stmt, 1) else { continue }
            rows.append((String(cString: kind), String(cString: key),
                         Int(sqlite3_column_int64(stmt, 2)),
                         Int(sqlite3_column_int64(stmt, 3)),
                         Int(sqlite3_column_int64(stmt, 4))))
        }
        return rows
    }

    /// Acknowledges a delivered batch by deleting its rows. Acknowledging an
    /// unknown or already-acknowledged id deletes nothing and reports
    /// nothing wrong, so a duplicate acknowledgement after a crash — or a
    /// server that answers twice — is harmless.
    func acknowledgeContributionBatch(_ batchID: String) {
        guard !isReadOnly, batchID != Contribution.unclaimed else { return }
        SQL.run(db, "DELETE FROM outbox WHERE batch_id = ?1", batchID)
    }

    /// Returns rows from batches that were claimed but never acknowledged —
    /// the crash case, and the case where an upload never got an answer.
    ///
    /// Counters come back intact, so nothing is lost. The old batch id stops
    /// existing, so a late acknowledgement of it is a no-op rather than a
    /// deletion of data that has since been re-queued, and a late *upload*
    /// of it cannot double-count: the server sees the same batch id it
    /// already has, or a new id whose rows were never delivered.
    func releaseStaleContributionClaims() {
        guard !isReadOnly else { return }
        SQL.run(db, "UPDATE outbox SET batch_id = ?1 WHERE batch_id <> ?1",
                Contribution.unclaimed)
    }

    /// Rows waiting to be claimed. Diagnostics and tests.
    var pendingContributionCount: Int {
        SQL.int(db, "SELECT COUNT(*) FROM outbox WHERE batch_id = '\(Contribution.unclaimed)'")
    }
}
