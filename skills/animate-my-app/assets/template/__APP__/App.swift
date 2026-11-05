import SwiftUI
import CoreText

@main
struct __APP__App: App {
    init() {
        Self.registerFonts()
        _ = SceneBridge.shared       // start the scene's web process now, in parallel with launch
        Self.listenForReplay()
    }

    /// Registers every font file bundled with the app (drop .ttf/.otf anywhere in the app folder).
    /// Use the font's PostScript name in `.font(.custom(...))`.
    static func registerFonts() {
        for ext in ["ttf", "otf", "ttc"] {
            for url in Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [] {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }

    /// `xcrun simctl spawn booted notifyutil -p com.animatemyapp.replay` (or any tool posting that Darwin notification) replays the intro in place.
    static func listenForReplay() {
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in
            DispatchQueue.main.async { NotificationCenter.default.post(name: .replayRequested, object: nil) }
        }, "com.animatemyapp.replay" as CFString, nil, .deliverImmediately)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

extension Notification.Name {
    static let replayRequested = Notification.Name("com.animatemyapp.replay")
}
