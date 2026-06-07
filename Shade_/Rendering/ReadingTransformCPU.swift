import Foundation

enum ReadingTransformCPU {
    static func apply(_ input: RGBPixel, parameters rawParameters: ReadingTransformParameters) -> RGBPixel {
        let parameters = rawParameters.clamped
        let strain = max(input.blue - ((input.red + input.green) * 0.5), 0)
        let reduction = strain * parameters.blueReduction * parameters.intensity

        var transformed = RGBPixel(
            red: input.red + reduction * 0.18,
            green: input.green - reduction * 0.04,
            blue: input.blue - reduction
        )

        if parameters.contrastProtect {
            transformed = preserveLuminance(original: input, transformed: transformed)
        }

        let dimMultiplier = 1 - parameters.dim
        return RGBPixel(
            red: clamp(transformed.red * dimMultiplier),
            green: clamp(transformed.green * dimMultiplier),
            blue: clamp(transformed.blue * dimMultiplier)
        )
    }

    private static func preserveLuminance(original: RGBPixel, transformed: RGBPixel) -> RGBPixel {
        let safeTransformed = RGBPixel(
            red: clamp(transformed.red),
            green: clamp(transformed.green),
            blue: clamp(transformed.blue)
        )
        let originalLuminance = max(original.luminance, 0.0001)
        let transformedLuminance = max(safeTransformed.luminance, 0.0001)
        let scale = originalLuminance / transformedLuminance

        return RGBPixel(
            red: clamp(safeTransformed.red * scale),
            green: clamp(safeTransformed.green * scale),
            blue: clamp(safeTransformed.blue * scale)
        )
    }

    private static func clamp(_ value: Float) -> Float {
        min(max(value, 0), 1)
    }
}
