import Foundation

struct OverlayTintInputs: Codable, Equatable {
    var useCustomColour: Bool
    var kelvin: Double
    var blueCut: Double
    var hue: Double
    var saturation: Double
    var strength: Double
    var dim: Double
}

struct ResolvedOverlayTint: Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var strength: Double
    var dim: Double
}

enum OverlayTintResolver {
    static func resolve(_ inputs: OverlayTintInputs) -> ResolvedOverlayTint {
        let rgb: (r: Double, g: Double, b: Double)
        if inputs.useCustomColour {
            rgb = hsbToRGB(hue: inputs.hue, saturation: inputs.saturation, brightness: 1.0)
        } else {
            var warm = Blackbody.rgb(kelvin: inputs.kelvin)
            warm.b *= (1 - clamp01(inputs.blueCut))
            rgb = warm
        }
        return ResolvedOverlayTint(
            red: clamp01(rgb.r),
            green: clamp01(rgb.g),
            blue: clamp01(rgb.b),
            strength: clamp01(inputs.strength),
            dim: clamp01(inputs.dim)
        )
    }

    static func hsbToRGB(hue: Double, saturation: Double, brightness: Double) -> (r: Double, g: Double, b: Double) {
        let h = ((hue.truncatingRemainder(dividingBy: 1.0)) + 1.0).truncatingRemainder(dividingBy: 1.0) * 6
        let s = clamp01(saturation)
        let v = clamp01(brightness)
        let c = v * s
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r1, g1, b1): (Double, Double, Double)
        switch Int(h) {
        case 0: (r1, g1, b1) = (c, x, 0)
        case 1: (r1, g1, b1) = (x, c, 0)
        case 2: (r1, g1, b1) = (0, c, x)
        case 3: (r1, g1, b1) = (0, x, c)
        case 4: (r1, g1, b1) = (x, 0, c)
        default: (r1, g1, b1) = (c, 0, x)
        }
        return (r1 + m, g1 + m, b1 + m)
    }

    private static func clamp01(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        return min(max(v, 0), 1)
    }
}
