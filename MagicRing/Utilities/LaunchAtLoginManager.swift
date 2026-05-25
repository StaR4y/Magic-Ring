import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` with a cached enabled flag so the main thread
/// never has to query `SMAppService.mainApp.status` synchronously. That call
/// can occasionally block the menu bar when the system is under load, which
/// would freeze the right-click settings menu.
@MainActor
enum LaunchAtLoginManager {
    /// Last known enabled flag. Read from `UserDefaults` so the value survives
    /// relaunches and is available before the first asynchronous refresh.
    private static let cacheKey = "LaunchAtLoginManager.cachedEnabled"

    private static var cachedEnabled: Bool = UserDefaults.standard.bool(forKey: cacheKey)
    private static var refreshTask: Task<Void, Never>?

    /// Returns the cached flag synchronously. Safe to call from menu
    /// construction without risking a main-thread stall.
    static var isEnabled: Bool {
        cachedEnabled
    }

    /// Refreshes the cached value off the main actor. Call once at app
    /// startup and any time the underlying state may have changed externally.
    static func refresh() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task.detached(priority: .utility) {
            let actual = SMAppService.mainApp.status == .enabled
            await MainActor.run {
                updateCache(actual)
                refreshTask = nil
            }
        }
    }

    /// Toggles the launch-at-login state. Network/IPC work happens off the
    /// main actor; the cache is updated when the call completes.
    static func setEnabled(_ enabled: Bool) async throws {
        try await Task.detached(priority: .userInitiated) {
            let service = SMAppService.mainApp
            let isCurrentlyEnabled = service.status == .enabled

            if enabled, !isCurrentlyEnabled {
                try service.register()
            } else if !enabled, isCurrentlyEnabled {
                try service.unregister()
            }
        }.value

        updateCache(enabled)
        refresh()
    }

    private static func updateCache(_ value: Bool) {
        cachedEnabled = value
        UserDefaults.standard.set(value, forKey: cacheKey)
    }
}
