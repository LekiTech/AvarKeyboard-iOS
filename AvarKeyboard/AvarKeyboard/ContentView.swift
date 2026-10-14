//
//  ContentView.swift
//  AvarKeyboard
//
//  Created by Enver Eskendarov on 6/28/26.
//

import SwiftUI
import GeneralKeyboardApp

/// The app's only screen: the shared General Keyboard onboarding with the
/// Avar copy, plus the sticker card in the product slot.
struct ContentView: View {

    @State private var stickerError: String?

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
        ) {
            stickersCard
        }
        .alert("Stickers", isPresented: .init(get: { stickerError != nil },
                                              set: { if !$0 { stickerError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(stickerError ?? "")
        }
    }

    // MARK: - Stickers

    private var stickersCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Eagle stickers")
                .font(.title3.weight(.semibold))
            Text("Add the Avar sticker pack to your favorite messenger. In iMessage the stickers appear automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                ForEach(["salam", "loveyou", "lezginka", "khinkal", "avarflag"], id: \.self) {
                    StickerThumb(name: $0)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                MessengerButton(title: "WhatsApp", systemImage: "phone.fill", tint: .green) {
                    share { try StickerSharing.addToWhatsApp() }
                }
                MessengerButton(title: "Telegram", systemImage: "paperplane.fill", tint: .blue) {
                    share { try StickerSharing.addToTelegram() }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func share(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            stickerError = error.localizedDescription
        }
    }
}

// MARK: - Sticker thumbnail

private struct StickerThumb: View {
    let name: String

    var body: some View {
        if let url = Bundle.main.url(forResource: name, withExtension: "webp"),
           let image = UIImage(contentsOfFile: url.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
        }
    }
}

// MARK: - Messenger button

private struct MessengerButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
    }
}

#Preview {
    ContentView()
}
