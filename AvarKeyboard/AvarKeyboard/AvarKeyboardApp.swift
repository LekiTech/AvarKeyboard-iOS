//
//  AvarKeyboardApp.swift
//  AvarKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI

@main
struct AvarKeyboardApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active,
                  let bridge = ContributionBridge.productionDirectory else { return }
            // Passive by design: batch files exist only if the keyboard's
            // exporter — behind its build flag, user consent, and Full
            // Access — ever wrote any. Today it cannot, so this scans an
            // empty directory and acknowledges nothing. The upload phase
            // will move acknowledgement to after server acceptance.
            _ = ContributionInbox.pickUp(from: bridge)
        }
    }
}
