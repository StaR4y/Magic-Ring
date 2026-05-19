import SwiftUI

enum PanelStyle: String, CaseIterable, Identifiable {
    case transparent
    case clearGlass
    case graphite
    case mist

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .transparent:
            return "Transparent"
        case .clearGlass:
            return "Clear Glass"
        case .graphite:
            return "Graphite"
        case .mist:
            return "Mist"
        }
    }

    var appearance: PanelAppearance {
        switch self {
        case .transparent:
            return PanelAppearance(
                overlayStart: Color.clear,
                overlayEnd: Color.clear,
                cardOpacity: 0.028,
                borderOpacity: 0.12,
                shadowOpacity: 0.08
            )
        case .clearGlass:
            return PanelAppearance(
                overlayStart: Color.white.opacity(0.08),
                overlayEnd: Color.black.opacity(0.14),
                cardOpacity: 0.055,
                borderOpacity: 0.20,
                shadowOpacity: 0.16
            )
        case .graphite:
            return PanelAppearance(
                overlayStart: Color.white.opacity(0.10),
                overlayEnd: Color.black.opacity(0.28),
                cardOpacity: 0.075,
                borderOpacity: 0.22,
                shadowOpacity: 0.20
            )
        case .mist:
            return PanelAppearance(
                overlayStart: Color.white.opacity(0.18),
                overlayEnd: Color.white.opacity(0.03),
                cardOpacity: 0.10,
                borderOpacity: 0.28,
                shadowOpacity: 0.12
            )
        }
    }
}

struct PanelAppearance {
    let overlayStart: Color
    let overlayEnd: Color
    let cardOpacity: Double
    let borderOpacity: Double
    let shadowOpacity: Double
}
