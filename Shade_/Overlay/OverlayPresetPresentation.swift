import Foundation

enum OverlayPresetPresentation {
    static let warmthPresets: [OverlayPreset] = [.gentle, .balanced, .deepCut]
    static let readingPresets: [OverlayPreset] = [.blue, .cream, .green, .rose, .grey]

    static func title(_ preset: OverlayPreset) -> String {
        switch preset {
        case .gentle: return "Gentle"
        case .balanced: return "Balanced"
        case .deepCut: return "Deep Cut"
        case .blue: return "Blue"
        case .cream: return "Cream"
        case .green: return "Green"
        case .rose: return "Rose"
        case .grey: return "Grey"
        case .custom: return "Custom"
        }
    }
}
