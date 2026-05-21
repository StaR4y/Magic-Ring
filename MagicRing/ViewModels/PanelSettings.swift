import Combine
import Foundation

@MainActor
final class PanelSettings: ObservableObject {
    @Published var style: PanelStyle {
        didSet {
            UserDefaults.standard.set(style.rawValue, forKey: styleStorageKey)
        }
    }

    @Published var isEnglishEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnglishEnabled, forKey: englishStorageKey)
        }
    }

    private let styleStorageKey = "panelStyle"
    private let englishStorageKey = "panelUsesEnglish"

    init() {
        let styleRawValue = UserDefaults.standard.string(forKey: styleStorageKey)

        style = styleRawValue.flatMap(PanelStyle.init(rawValue:)) ?? .clearGlass
        isEnglishEnabled = UserDefaults.standard.bool(forKey: englishStorageKey)
    }
}
