//
//  ContentView.swift
//  AvarKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI
import GeneralKeyboardApp

/// The app's only screen: the shared General Keyboard onboarding with the
/// Avar copy.
struct ContentView: View {

    var body: some View {
        KeyboardOnboardingView(
            title: "Avar Keyboard",
            tagline: "Type in your native language",
            // Step 3 of the install card, «Turn on **…**». Its own catalog
            // entry rather than the title: Russian needs the accusative
            // («Включите **Аварскую клавиатуру**»).
            keyboardName: String(localized: "install.keyboardName", defaultValue: "Avar Keyboard",
                                 comment: "Keyboard name in install step 3: Turn on **…** (Russian: accusative)"),
            features: [
                .init(0, icon: "textformat.abc", tint: .blue,
                      title: "Full Avar alphabet",
                      subtitle: "Palochka and digraphs like цӀ, къ, лъ are one long press away"),
                .init(1, icon: "text.book.closed.fill", tint: .orange,
                      title: "Word suggestions",
                      subtitle: "Over 60,000 Avar words, fully offline"),
                .init(2, icon: "keyboard.fill", tint: .green,
                      title: "Feels native",
                      subtitle: "Matches the iOS keyboard down to the details"),
                .init(3, icon: "lock.shield.fill", tint: .purple,
                      title: "Private by design",
                      subtitle: "Never asks for Full Access and sends nothing anywhere — word learning stays on this device and can be reset from the keyboard"),
            ]
        )
    }
}

#Preview {
    ContentView()
}
