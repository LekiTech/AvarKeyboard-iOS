//
//  AvarIdentity.swift
//  AvarKeyboardExtension
//
//  Product identifiers that the keyboard AND the container app both need.
//  Compiled into both targets (a target-membership exception, like
//  ContributionBridge.swift), so the App Group is spelled once in code.
//  It must match both .entitlements files; the released value never changes.
//

enum AvarIdentity {
    static let appGroupID = "group.org.lekitech.avarkeyboard"
}
