import Combine
import Foundation

@MainActor
final class PanelSettings: ObservableObject {
    @Published var style: PanelStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: storageKey)
        }
    }

    private let storageKey = "panelStyle"

    init() {
        let rawValue = UserDefaults.standard.string(forKey: storageKey)
        style = rawValue.flatMap(PanelStyle.init(rawValue:)) ?? .clearGlass
    }
}
