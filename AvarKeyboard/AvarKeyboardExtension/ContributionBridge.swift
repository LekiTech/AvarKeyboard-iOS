//
//  ContributionBridge.swift
//  AvarKeyboardExtension
//
//  The file protocol between the keyboard's outbox and the containing app:
//
//      learned.sqlite outbox ── claim ──► outgoing/<batch>.json
//      containing app ── reads outgoing, writes ──► ack/<batch>.ack
//      keyboard ── sees ack ──► acknowledge (rows deleted), files removed
//
//  Every path here takes the bridge directory as a parameter. Nothing in
//  this file knows about App Groups, entitlements, or Full Access — the
//  production directory (the App Group container) arrives in a later,
//  separately-approved change, and until then the only directories these
//  functions ever see belong to tests.
//
//  DESIGN RULES
//    * No shared writable database. Each file has exactly one writer:
//      the keyboard writes outgoing/, the app writes ack/. Handoff is by
//      rename, which is atomic on the same volume, so a reader can never
//      observe a half-written file.
//    * The keyboard never exports unless the full gate holds: build flag,
//      user consent, writable store, AND Full Access. Any of them missing
//      means no file is written and no claim is left dangling.
//    * A batch file contains the format version, the batch id, and the
//      aggregated rows. No timestamps of any kind — see
//      docs/CONTRIBUTION_OUTBOX.md §9 — and nothing about the device or
//      the person.
//    * Serialization is deterministic (sorted keys, claim order), so
//      re-exporting the same batch is byte-identical and a retry can be
//      deduplicated by content as well as by id.
//

import Foundation

// MARK: - The serialized batch format

/// Version 1 of the bridge file format. Bumped only with a reviewed
/// change; readers refuse versions they do not know.
struct ContributionBatchFile: Codable, Equatable {
    struct Row: Codable, Equatable {
        let kind: String
        let key: String
        let typed: Int
        let picked: Int
        let confirmations: Int
    }

    let format: Int
    let batch: String
    let rows: [Row]

    static let currentFormat = 1

    /// Deterministic bytes: sorted keys, no formatting whitespace, rows in
    /// claim (id) order as `contributionBatch` returns them.
    func serialized() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    static func parse(_ data: Data) -> ContributionBatchFile? {
        guard let file = try? JSONDecoder().decode(ContributionBatchFile.self, from: data),
              file.format == currentFormat else { return nil }
        return file
    }
}

// MARK: - Shared directory layout

enum ContributionBridge {

    /// Batches the keyboard has exported and the app has not yet
    /// acknowledged. Written only by the keyboard.
    static func outgoingDirectory(in bridge: URL) -> URL {
        bridge.appendingPathComponent("Contribution/outgoing", isDirectory: true)
    }

    /// Acknowledgements. Written only by the app.
    static func ackDirectory(in bridge: URL) -> URL {
        bridge.appendingPathComponent("Contribution/ack", isDirectory: true)
    }

    /// Scratch space for atomic writes; files are renamed out of here.
    static func stagingDirectory(in bridge: URL) -> URL {
        bridge.appendingPathComponent("Contribution/tmp", isDirectory: true)
    }

    /// The keyboard stops claiming new batches once this many exported
    /// files are waiting — the "containing app never opened" bound. The
    /// outbox's own row cap bounds the database side.
    static let maxPendingFiles = 3

    /// A batch file may not exceed this size; the exporter halves the row
    /// limit until the serialized batch fits. 128 KB is deliberately LOW
    /// enough that a 500-row batch of maximum-length bigram keys (~165 KB)
    /// actually exceeds it — a cap no reachable batch can hit is not a cap,
    /// and the shrinking path would be dead code.
    static let maxBatchBytes = 131_072

    /// An exported file the app has not picked up after this long is
    /// withdrawn: the file is deleted and its rows return to the queue,
    /// counters intact. Uses filesystem metadata, not exported content.
    static let pendingFileRetention: TimeInterval = 30 * 24 * 3600

    /// Atomic publication: write to the staging directory, then rename
    /// into place. Rename is atomic on the same volume, so `destination`
    /// either does not exist or is complete — never partial.
    static func atomicWrite(_ data: Data, to destination: URL, in bridge: URL) throws {
        let staging = stagingDirectory(in: bridge)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let temp = staging.appendingPathComponent(UUID().uuidString)
        try data.write(to: temp)
        do {
            try FileManager.default.moveItem(at: temp, to: destination)
        } catch {
            // Lost the race to a file that already exists (a retry of the
            // same batch): the existing bytes are identical by determinism,
            // so keeping them is correct.
            try? FileManager.default.removeItem(at: temp)
            if !FileManager.default.fileExists(atPath: destination.path) { throw error }
        }
    }
}

// MARK: - Keyboard side: the exporter

extension LearnedWords {

    /// Everything the keyboard's bridge pass does, in order: recover,
    /// enforce bounds, export. Call sites do not exist yet — the gate is
    /// closed and the production bridge directory does not exist — but the
    /// whole lifecycle is exercised by tests through this one entry point.
    ///
    /// `hasFullAccess` is a parameter rather than a UIKit read so the
    /// policy is testable; the future call site passes
    /// `UIInputViewController.hasFullAccess`.
    /// Returns the URL of a newly exported batch file, if one was written.
    @discardableResult
    func runContributionBridge(at bridge: URL, hasFullAccess: Bool) -> URL? {
        guard Contribution.isEnabled else { return nil }
        return runContributionBridgeIgnoringFlag(at: bridge, hasFullAccess: hasFullAccess)
    }

    /// Ungated variant for tests — the same reason enqueueContribution has
    /// one: the flag is a genuine compile-time `false`.
    @discardableResult
    func runContributionBridgeIgnoringFlag(at bridge: URL, hasFullAccess: Bool) -> URL? {
        guard !isReadOnly, hasContributionConsent, hasFullAccess else {
            // Not eligible. Deliberately do nothing at all: no recovery, no
            // cleanup, no directory creation. Losing Full Access between a
            // claim and an export leaves the claim in place; the rows are
            // frozen, not lost, and the next eligible pass recovers them.
            return nil
        }

        let fm = FileManager.default
        let outgoing = ContributionBridge.outgoingDirectory(in: bridge)
        let ack = ContributionBridge.ackDirectory(in: bridge)
        try? fm.createDirectory(at: outgoing, withIntermediateDirectories: true)
        try? fm.createDirectory(at: ack, withIntermediateDirectories: true)

        // 1. Consume acknowledgements: delete the batch's rows, then both
        //    files. Ack-before-file-removal order means a crash here leaves
        //    an ack for an already-deleted batch — and acknowledging an
        //    unknown id is a no-op, so the retry is harmless.
        for ackFile in (try? fm.contentsOfDirectory(at: ack, includingPropertiesForKeys: nil)) ?? []
        where ackFile.pathExtension == "ack" {
            let batchID = ackFile.deletingPathExtension().lastPathComponent
            acknowledgeContributionBatch(batchID)
            try? fm.removeItem(at: outgoing.appendingPathComponent("\(batchID).json"))
            try? fm.removeItem(at: ackFile)
        }

        let pendingFiles = ((try? fm.contentsOfDirectory(at: outgoing, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .filter { $0.pathExtension == "json" }

        // 2. Withdraw exported files the app has ignored past retention:
        //    delete the file FIRST, then release the rows. A crash between
        //    the two leaves a claimed batch with no file — exactly what
        //    step 3 recovers. The reverse order could duplicate rows into
        //    a second file while the first still existed.
        var remaining: [URL] = []
        for file in pendingFiles {
            let age = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate.map { -$0.timeIntervalSinceNow } ?? 0
            if age > ContributionBridge.pendingFileRetention {
                try? fm.removeItem(at: file)
                releaseContributionClaim(file.deletingPathExtension().lastPathComponent)
            } else {
                remaining.append(file)
            }
        }

        // 3. Recover claims that died between claiming and writing: a
        //    claimed batch with no file on disk can never be acknowledged,
        //    so its rows go back to the queue, counters intact.
        let onDisk = Set(remaining.map { $0.deletingPathExtension().lastPathComponent })
        for batchID in claimedContributionBatchIDs where !onDisk.contains(batchID) {
            releaseContributionClaim(batchID)
        }

        // 4. Export one new batch, if there is room and material.
        guard remaining.count < ContributionBridge.maxPendingFiles else { return nil }
        return exportOneBatch(to: outgoing, in: bridge)
    }

    private func exportOneBatch(to outgoing: URL, in bridge: URL) -> URL? {
        var limit = 500
        while limit >= 1 {
            guard let batchID = claimBatch(limit: limit) else { return nil }
            let rows = contributionBatch(batchID).map {
                ContributionBatchFile.Row(kind: $0.kind, key: $0.key, typed: $0.typed,
                                          picked: $0.picked, confirmations: $0.confirmations)
            }
            let file = ContributionBatchFile(format: ContributionBatchFile.currentFormat,
                                             batch: batchID, rows: rows)
            guard let data = try? file.serialized() else {
                releaseContributionClaim(batchID)
                return nil
            }
            guard data.count <= ContributionBridge.maxBatchBytes else {
                // Too big: put the rows back and try a smaller claim. The
                // released rows re-queue in id order, so the next claim
                // takes the same head rows — nothing is skipped.
                releaseContributionClaim(batchID)
                limit /= 2
                continue
            }
            let destination = outgoing.appendingPathComponent("\(batchID).json")
            do {
                try ContributionBridge.atomicWrite(data, to: destination, in: bridge)
                return destination
            } catch {
                // Nothing reached the outgoing directory, so releasing the
                // claim leaves the world exactly as before this call.
                releaseContributionClaim(batchID)
                return nil
            }
        }
        return nil
    }
}

// MARK: - App side: the inbox

/// The containing app's half: read exported batches, acknowledge them.
/// Owns no database and holds no state — the filesystem is the state.
enum ContributionInbox {

    /// Parses every well-formed batch waiting in the bridge and writes an
    /// acknowledgement for each. Malformed or foreign files are left in
    /// place untouched — never acknowledged (an ack deletes the keyboard's
    /// rows, so acking what could not be read would destroy data), never
    /// deleted (the keyboard's retention handles withdrawal).
    ///
    /// In this proof of concept "picked up" means parsed and returned to
    /// the caller. The upload phase will move acknowledgement to after
    /// server acceptance; the protocol does not change.
    static func pickUp(from bridge: URL) -> [ContributionBatchFile] {
        let fm = FileManager.default
        let outgoing = ContributionBridge.outgoingDirectory(in: bridge)
        let ack = ContributionBridge.ackDirectory(in: bridge)
        try? fm.createDirectory(at: ack, withIntermediateDirectories: true)

        var pickedUp: [ContributionBatchFile] = []
        for file in (try? fm.contentsOfDirectory(at: outgoing, includingPropertiesForKeys: nil)) ?? []
        where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let batch = ContributionBatchFile.parse(data),
                  batch.batch == file.deletingPathExtension().lastPathComponent
            else { continue }
            let ackFile = ack.appendingPathComponent("\(batch.batch).ack")
            guard (try? ContributionBridge.atomicWrite(Data(batch.batch.utf8),
                                                       to: ackFile, in: bridge)) != nil
            else { continue }
            pickedUp.append(batch)
        }
        return pickedUp
    }
}
