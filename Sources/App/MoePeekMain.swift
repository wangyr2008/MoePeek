import AppKit

/// App entry point. Replaces the SwiftUI `App`/`MenuBarExtra` lifecycle (macOS 13+) with a
/// plain AppKit bootstrap so the app runs on macOS 12+. The menu bar presence is owned by
/// `MenuBarManager`; everything else stays in `AppDelegate`.
@main
final class MoePeekMain {
    static func main() {
        // Under Swift 6 strict concurrency the bootstrap must prove main-thread isolation.
        MainActor.assumeIsolated {
            let app = NSApplication.shared
            let delegate = AppDelegate()
            app.delegate = delegate
            // LSUIElement keeps the Dock icon hidden in Info.plist, but set the policy
            // explicitly so a fresh launch (without saved state) never shows a Dock icon.
            app.setActivationPolicy(.accessory)
            app.run()
        }
    }
}
