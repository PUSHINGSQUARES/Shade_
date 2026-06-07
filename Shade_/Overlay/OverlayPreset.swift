import Foundation

enum OverlayPreset: String, CaseIterable {
    case gentle, balanced, deepCut, blue, cream, green, rose, grey, custom

    struct Values: Equatable {
        var useCustomColour: Bool
        var kelvin: Double
        var blueCut: Double
        var hue: Double
        var saturation: Double
        var strength: Double
        var dim: Double
    }

    var values: Values? {
        switch self {
        case .gentle:
            return Values(useCustomColour: false, kelvin: 3400, blueCut: 0.0, hue: 0, saturation: 0, strength: 0.15, dim: 0.35)
        case .balanced:
            return Values(useCustomColour: false, kelvin: 2500, blueCut: 0.6, hue: 0, saturation: 0, strength: 0.22, dim: 0.28)
        case .deepCut:
            return Values(useCustomColour: false, kelvin: 2000, blueCut: 0.9, hue: 0, saturation: 0, strength: 0.30, dim: 0.15)
        case .blue:
            return Values(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.60, saturation: 0.35, strength: 0.20, dim: 0.10)
        case .cream:
            return Values(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.12, saturation: 0.45, strength: 0.20, dim: 0.05)
        case .green:
            return Values(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.33, saturation: 0.30, strength: 0.18, dim: 0.08)
        case .rose:
            return Values(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.95, saturation: 0.30, strength: 0.18, dim: 0.08)
        case .grey:
            return Values(useCustomColour: true, kelvin: 2500, blueCut: 0, hue: 0.0, saturation: 0.0, strength: 0.15, dim: 0.15)
        case .custom:
            return nil
        }
    }
}
