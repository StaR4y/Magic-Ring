import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    private static let cacheKey = "LaunchAtLoginManager.cachedEnabled"

    private static var cachedEnabled: Bool = UserDefaults.standard.bool(forKey: cacheKey)

    static var isEnabled: Bool {
        cachedEnabled
    }

    static func setEnabled(_ enabled: Bool) async throws {
        let previousValue = cachedEnabled
        updateCache(enabled)

        do {
            try await Task.detached(priority: .userInitiated) {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }.value
        } catch {
            updateCache(previousValue)
            throw error
        }
    }

    private static func updateCache(_ value: Bool) {
        cachedEnabled = value
        UserDefaults.standard.set(value, forKey: cacheKey)
    }
}
