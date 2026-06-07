import Foundation

enum Blackbody {
    // Normalised sRGB approximations on the blackbody locus, max channel == 1.
    private static let table: [(k: Double, r: Double, g: Double, b: Double)] = [
        (1900, 1.0, 0.497, 0.131),
        (2000, 1.0, 0.522, 0.166),
        (2300, 1.0, 0.585, 0.260),
        (2500, 1.0, 0.622, 0.318),
        (2700, 1.0, 0.657, 0.376),
        (3000, 1.0, 0.706, 0.456),
        (3400, 1.0, 0.762, 0.557),
        (4000, 1.0, 0.834, 0.689),
        (5000, 1.0, 0.927, 0.869),
        (6500, 1.0, 1.0, 1.0),
    ]

    static func rgb(kelvin: Double) -> (r: Double, g: Double, b: Double) {
        let first = table.first!
        let last = table.last!
        if !kelvin.isFinite || kelvin <= first.k { return (first.r, first.g, first.b) }
        if kelvin >= last.k { return (last.r, last.g, last.b) }
        for i in 1..<table.count {
            let hi = table[i]
            if kelvin <= hi.k {
                let lo = table[i - 1]
                let t = (kelvin - lo.k) / (hi.k - lo.k)
                return (
                    lo.r + (hi.r - lo.r) * t,
                    lo.g + (hi.g - lo.g) * t,
                    lo.b + (hi.b - lo.b) * t
                )
            }
        }
        return (last.r, last.g, last.b)
    }
}
