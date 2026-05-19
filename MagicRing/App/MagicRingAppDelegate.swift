import AppKit

final class MagicRingAppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        Task { @MainActor in
            let controller = StatusBarController()
            controller.start()
            statusBarController = controller
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in
            statusBarController?.stop()
            statusBarController = nil
        }
    }
}
