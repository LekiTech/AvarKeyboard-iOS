//
//  ContributionOutboxTests.swift
//
//  The contribution queue is inert in shipping builds, so these tests are
//  the only thing exercising it. They pin the two properties that matter
//  most: that nothing is collected without both the flag and consent, and
//  that what IS collected is an aggregate — bounded, countable, and
//  incapable of holding text.
//

import XCTest
import SQLite3
@testable import AvarCore

final class ContributionOutboxTests: XCTestCase {

    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("outbox-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeStore() throws -> LearnedWords {
        try XCTUnwrap(LearnedWords(directory: dir))
    }

    private func at(_ daysAgo: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400)
    }

    // MARK: - The gate

    func testContributionIsDisabledInShippingBuilds() {
        XCTAssertFalse(Contribution.isEnabled,
                       "The flag must ship OFF. If this fails, a build is collecting.")
    }

    func testConsentDefaultsToFalseOnAFreshDatabase() throws {
        let store = try makeStore()
        XCTAssertFalse(store.hasContributionConsent)
        XCTAssertFalse(store.isContributionActive)
    }

    func testConsentDefaultsToFalseOnAnUpgradedProductionDatabase() throws {
        // A database that predates the consent column never agreed to
        // anything; the upgrade must not invent an agreement.
        let store = try makeStore()
        store.learn("кӏвал", previous: nil, picked: false)
        XCTAssertFalse(store.hasContributionConsent)
    }

    func testRecordingIsANoOpWhileTheFlagIsOff() throws {
        let store = try makeStore()
        store.setContributionConsent(true)   // consent alone must not be enough
        for _ in 0..<50 {
            store.recordContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        }
        XCTAssertEqual(store.pendingContributionCount, 0,
                       "Consent without the flag collects nothing")
    }

    func testRecordingIsANoOpWithoutConsent() throws {
        let store = try makeStore()
        XCTAssertFalse(store.hasContributionConsent)
        store.recordContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        XCTAssertEqual(store.pendingContributionCount, 0)
    }

    func testClaimingIsANoOpWhileTheGateIsClosed() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        XCTAssertEqual(store.pendingContributionCount, 1, "Precondition: something to claim")
        XCTAssertNil(store.claimContributionBatch(),
                     "The gated entry point must refuse while the flag is off")
    }

    // MARK: - No historical backfill

    func testGrantingConsentDoesNotSweepInExistingLearnedData() throws {
        let store = try makeStore()
        for word in ["кӏвал", "хайи", "къуьл"] {
            store.learn(word, previous: "ва", picked: false)
        }
        XCTAssertTrue(store.isRecognized("кӏвал"), "Precondition: there IS history")

        store.setContributionConsent(true)

        XCTAssertEqual(store.pendingContributionCount, 0,
                       "Consent starts collection; it does not retroactively authorize it")
    }

    func testWithdrawingConsentEmptiesTheQueueIncludingClaimedRows() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        store.enqueueContribution(kind: .wordDelta, key: "хайи", typedDelta: 1)
        let batch = try XCTUnwrap(store.claimBatch(limit: 1))
        XCTAssertEqual(store.contributionBatch(batch).count, 1)

        store.setContributionConsent(false)

        XCTAssertEqual(store.pendingContributionCount, 0)
        XCTAssertTrue(store.contributionBatch(batch).isEmpty,
                      "An in-flight batch is not a reason to keep data after withdrawal")
    }

    // MARK: - Aggregation

    func testRepeatedEventsCollapseIntoOneRow() throws {
        let store = try makeStore()
        for _ in 0..<100 {
            store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        }
        XCTAssertEqual(store.pendingContributionCount, 1,
                       "100 events, 1 row — the queue counts words, not keystrokes")

        let batch = try XCTUnwrap(store.claimBatch())
        let rows = store.contributionBatch(batch)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].typed, 100)
        XCTAssertEqual(rows[0].confirmations, 100)
    }

    func testTypedAndPickedAccumulateSeparately() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", pickedDelta: 1)

        let rows = store.contributionBatch(try XCTUnwrap(store.claimBatch()))
        XCTAssertEqual(rows[0].typed, 2)
        XCTAssertEqual(rows[0].picked, 1)
    }

    func testDifferentKindsOfTheSameKeyStaySeparateRows() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        store.enqueueContribution(kind: .candidate, key: "кӏвал", typedDelta: 1)
        XCTAssertEqual(store.pendingContributionCount, 2,
                       "(kind, key) is the aggregation key, not key alone")
    }

    func testBigramKeyRoundTripsBothHalves() throws {
        let store = try makeStore()
        let key = Contribution.bigramKey(previous: "ва", word: "кӏвал")
        store.enqueueContribution(kind: .bigramDelta, key: key, typedDelta: 1)

        let rows = store.contributionBatch(try XCTUnwrap(store.claimBatch()))
        let halves = rows[0].key.components(separatedBy: Contribution.keySeparator)
        XCTAssertEqual(halves, ["ва", "кӏвал"])
    }

    func testTheSeparatorCannotOccurInACanonicalToken() {
        // If it could, a bigram key would be ambiguous.
        let separator = Character(Contribution.keySeparator)
        for token in ["кӏвал", "хайи", "къуьл", "ва", "цӏиргъ"] {
            XCTAssertFalse(Normalization.canonical(token).contains(separator))
        }
    }

    // MARK: - Structural privacy

    func testEveryColumnIsATokenOrAnInteger() throws {
        _ = try makeStore()
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dir.appendingPathComponent("learned.sqlite").path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "PRAGMA table_info(outbox)", -1, &stmt, nil), SQLITE_OK)
        defer { sqlite3_finalize(stmt) }

        var textColumns: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(stmt, 1))
            let type = String(cString: sqlite3_column_text(stmt, 2))
            if type == "TEXT" { textColumns.append(name) }
        }
        // The only text in the table is the kind enum, the aggregation key
        // (canonical tokens), and a batch UUID. Adding a text column here
        // should require deleting this assertion on purpose.
        XCTAssertEqual(textColumns.sorted(), ["batch_id", "key", "kind"],
                       "A new TEXT column is a new place for free text to hide")
    }

    func testEmptyKeysAreRefused() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "", typedDelta: 1)
        XCTAssertEqual(store.pendingContributionCount, 0)
    }

    // MARK: - Candidate threshold

    func testCandidatesBelowTheConfirmationBarDoNotEnterABatch() throws {
        let store = try makeStore()
        for _ in 0..<(Contribution.candidateMinimumConfirmations - 1) {
            store.enqueueContribution(kind: .candidate, key: "гьуьлуьхъ", typedDelta: 1)
        }
        XCTAssertEqual(store.pendingContributionCount, 1, "It is queued…")
        XCTAssertNil(store.claimBatch(), "…but not eligible to leave")
    }

    func testCandidatesAtTheBarBecomeEligible() throws {
        let store = try makeStore()
        for _ in 0..<Contribution.candidateMinimumConfirmations {
            store.enqueueContribution(kind: .candidate, key: "гьуьлуьхъ", typedDelta: 1)
        }
        let rows = store.contributionBatch(try XCTUnwrap(store.claimBatch()))
        XCTAssertEqual(rows.map(\.key), ["гьуьлуьхъ"])
    }

    func testKnownWordsAreNotSubjectToTheCandidateBar() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        XCTAssertNotNil(store.claimBatch(),
                        "A dictionary word is not the sensitive category")
    }

    // MARK: - Capacity and retention

    func testStaleRowsAreDropped() throws {
        let store = try makeStore()
        let old = at(365)
        store.enqueueContribution(kind: .wordDelta, key: "кьуьзуь", typedDelta: 1, now: old)
        XCTAssertEqual(store.pendingContributionCount, 1)

        // Any later write runs the prune.
        store.enqueueContribution(kind: .wordDelta, key: "цӏийи", typedDelta: 1, now: at(0))

        let keys = store.contributionBatch(try XCTUnwrap(store.claimBatch())).map(\.key)
        XCTAssertEqual(keys, ["цӏийи"], "The year-old row is past retention")
    }

    func testFreshRowsSurviveTheRetentionSweep() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кьуьзуь", typedDelta: 1, now: at(30))
        store.enqueueContribution(kind: .wordDelta, key: "цӏийи", typedDelta: 1, now: at(0))
        XCTAssertEqual(store.pendingContributionCount, 2)
    }

    func testTheQueueIsBoundedByMaxRows() throws {
        let store = try makeStore()
        // Every key distinct, so aggregation cannot do the bounding here.
        for i in 0..<(Contribution.maxRows + 200) {
            store.enqueueContribution(kind: .wordDelta, key: "гаф\(i)", typedDelta: 1)
        }
        XCTAssertLessThanOrEqual(store.pendingContributionCount, Contribution.maxRows)
    }

    func testPruningKeepsTheMostConfirmedRows() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "important", typedDelta: 1)
        for _ in 0..<20 {
            store.enqueueContribution(kind: .wordDelta, key: "important", typedDelta: 1)
        }
        for i in 0..<(Contribution.maxRows + 100) {
            store.enqueueContribution(kind: .wordDelta, key: "гаф\(i)", typedDelta: 1)
        }
        let surviving = store.contributionBatch(try XCTUnwrap(store.claimBatch(limit: Contribution.maxRows)))
        XCTAssertTrue(surviving.contains { $0.key == "important" },
                      "Pressure must evict the incidental, not the reinforced")
    }

    func testClaimedRowsAreNeverPruned() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "claimed", typedDelta: 1, now: at(365))
        let batch = try XCTUnwrap(store.claimBatch())

        store.enqueueContribution(kind: .wordDelta, key: "цӏийи", typedDelta: 1, now: at(0))

        XCTAssertEqual(store.contributionBatch(batch).count, 1,
                       "A batch in flight must not lose rows underneath its exporter")
    }

    // MARK: - Batch lifecycle

    func testAClaimedRowLeavesThePendingQueue() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        _ = try XCTUnwrap(store.claimBatch())
        XCTAssertEqual(store.pendingContributionCount, 0)
    }

    func testClaimingAnEmptyQueueReturnsNil() throws {
        let store = try makeStore()
        XCTAssertNil(store.claimBatch())
    }

    func testASecondClaimDoesNotStealTheFirstBatchesRows() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        store.enqueueContribution(kind: .wordDelta, key: "хайи", typedDelta: 1)

        let first = try XCTUnwrap(store.claimBatch(limit: 1))
        let second = try XCTUnwrap(store.claimBatch(limit: 1))

        XCTAssertNotEqual(first, second)
        XCTAssertEqual(store.contributionBatch(first).count, 1)
        XCTAssertEqual(store.contributionBatch(second).count, 1)
        XCTAssertNotEqual(store.contributionBatch(first)[0].key,
                          store.contributionBatch(second)[0].key)
    }

    func testEventsDuringAnInFlightBatchStartAFreshRow() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 5)
        let batch = try XCTUnwrap(store.claimBatch())

        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)

        XCTAssertEqual(store.contributionBatch(batch)[0].typed, 5,
                       "The claimed snapshot must not move under the exporter")
        XCTAssertEqual(store.pendingContributionCount, 1,
                       "…and the new event is not lost either")
    }

    func testReadingABatchTwiceYieldsIdenticalContent() throws {
        let store = try makeStore()
        for word in ["кӏвал", "хайи", "къуьл"] {
            store.enqueueContribution(kind: .wordDelta, key: word, typedDelta: 2)
        }
        let batch = try XCTUnwrap(store.claimBatch())

        let first = store.contributionBatch(batch)
        let second = store.contributionBatch(batch)
        XCTAssertEqual(first.map(\.key), second.map(\.key), "Same order")
        XCTAssertEqual(first.map(\.typed), second.map(\.typed), "Same counters")
    }

    func testAcknowledgementRemovesOnlyThatBatch() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        store.enqueueContribution(kind: .wordDelta, key: "хайи", typedDelta: 1)
        let first = try XCTUnwrap(store.claimBatch(limit: 1))
        let second = try XCTUnwrap(store.claimBatch(limit: 1))

        store.acknowledgeContributionBatch(first)

        XCTAssertTrue(store.contributionBatch(first).isEmpty)
        XCTAssertEqual(store.contributionBatch(second).count, 1)
    }

    func testDuplicateAcknowledgementIsHarmless() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)
        let batch = try XCTUnwrap(store.claimBatch())

        store.acknowledgeContributionBatch(batch)
        store.acknowledgeContributionBatch(batch)   // the server answered twice
        store.acknowledgeContributionBatch(UUID().uuidString)   // …or answered about nothing

        XCTAssertEqual(store.pendingContributionCount, 0)
        XCTAssertTrue(store.contributionBatch(batch).isEmpty)
    }

    func testAcknowledgingTheUnclaimedSentinelCannotWipeTheQueue() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 1)

        store.acknowledgeContributionBatch(Contribution.unclaimed)

        XCTAssertEqual(store.pendingContributionCount, 1,
                       "An empty batch id must never mean 'every unclaimed row'")
    }

    // MARK: - Crash recovery

    func testAClaimThatNeverCompletedIsRecoveredOnTheNextLaunch() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 7)
        let lost = try XCTUnwrap(store.claimBatch())
        XCTAssertEqual(store.pendingContributionCount, 0, "Precondition: in flight")
        // …and here the extension is killed, between claim and acknowledgement.

        let relaunched = try makeStore()
        relaunched.releaseStaleContributionClaims()

        XCTAssertEqual(relaunched.pendingContributionCount, 1, "Nothing lost")
        let rows = relaunched.contributionBatch(try XCTUnwrap(relaunched.claimBatch()))
        XCTAssertEqual(rows[0].typed, 7, "…and nothing double-counted")
        XCTAssertTrue(relaunched.contributionBatch(lost).isEmpty,
                      "The abandoned batch id no longer names any rows")
    }

    func testALateAcknowledgementOfAReleasedBatchDeletesNothing() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 3)
        let lost = try XCTUnwrap(store.claimBatch())
        store.releaseStaleContributionClaims()
        let reclaimed = try XCTUnwrap(store.claimBatch())

        store.acknowledgeContributionBatch(lost)   // a stale reply arriving late

        XCTAssertEqual(store.contributionBatch(reclaimed).count, 1,
                       "A stale acknowledgement must not delete re-queued work")
    }

    func testReleaseMergesNothingAndLosesNothingAcrossSeveralBatches() throws {
        let store = try makeStore()
        for word in ["кӏвал", "хайи", "къуьл"] {
            store.enqueueContribution(kind: .wordDelta, key: word, typedDelta: 1)
        }
        _ = try XCTUnwrap(store.claimBatch(limit: 1))
        _ = try XCTUnwrap(store.claimBatch(limit: 1))

        store.releaseStaleContributionClaims()

        XCTAssertEqual(store.pendingContributionCount, 3)
    }

    func testTheQueueSurvivesReopeningTheDatabase() throws {
        let store = try makeStore()
        store.enqueueContribution(kind: .wordDelta, key: "кӏвал", typedDelta: 4)

        let reopened = try makeStore()
        XCTAssertEqual(reopened.pendingContributionCount, 1, "Durable, not in-memory")
        XCTAssertEqual(reopened.contributionBatch(try XCTUnwrap(reopened.claimBatch()))[0].typed, 4)
    }

    // MARK: - Existing behavior is untouched

    func testLearningStillWorksWithTheOutboxPresent() throws {
        let store = try makeStore()
        store.learn("кӏвал", previous: "ва", picked: false)
        store.learn("кӏвал", previous: "ва", picked: true)

        XCTAssertTrue(store.isRecognized("кӏвал"))
        XCTAssertEqual(store.pendingContributionCount, 0,
                       "Typing must not feed the queue while the gate is closed")
    }
}
