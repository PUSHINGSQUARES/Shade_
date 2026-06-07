import Foundation

struct ReadingTransformParameters: Equatable {
    var intensity: Float
    var blueReduction: Float
    var dim: Float
    var contrastProtect: Bool

    var clamped: ReadingTransformParameters {
        ReadingTransformParameters(
            intensity: Self.clamp(intensity, lower: 0, upper: 1),
            blueReduction: Self.clamp(blueReduction, lower: 0, upper: 1),
            dim: Self.clamp(dim, lower: 0, upper: 0.8),
            contrastProtect: contrastProtect
        )
    }

    private static func clamp(_ value: Float, lower: Float, upper: Float) -> Float {
        guard value.isFinite else {
            return 0
        }

        return min(max(value, lower), upper)
    }
}

struct RGBPixel: Equatable {
    var red: Float
    var green: Float
    var blue: Float

    var luminance: Float {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
