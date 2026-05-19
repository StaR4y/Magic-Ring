import SwiftUI

@main
struct MagicRingApp: App {
    @NSApplicationDelegateAdaptor(MagicRingAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
