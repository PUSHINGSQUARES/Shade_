import Foundation

struct SolarEvents: Equatable {
    let sunrise: Date
    let sunset: Date
}

typealias SolarEventsProvider = (Double, Double, Date, TimeZone) -> SolarEvents?

enum SolarCalculator {
    /// Sunrise/sunset (UTC instants) for the civil date of `date` in `timeZone`, at the
    /// given coordinates. Returns nil for polar day/night (no event). Based on the
    /// standard NOAA / "sunrise equation" formulation.
    static func events(
        _ latitude: Double,
        _ longitude: Double,
        _ date: Date,
        _ timeZone: TimeZone
    ) -> SolarEvents? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = c.year, let month = c.month, let day = c.day else { return nil }

        let jdn = julianDayNumber(year: year, month: month, day: day)
        let n = Double(jdn) - 2451545.0 + 0.0008
        // Mean solar time. The longitude term must make eastern longitudes reach solar
        // noon earlier (in UTC) and western ones later; transit = jdn - longitude/360.
        let lw = longitude
        let jStar = n - lw / 360.0

        let m = 357.5291 + 0.98560028 * jStar
        let center = 1.9148 * sind(m) + 0.0200 * sind(2 * m) + 0.0003 * sind(3 * m)
        let lambda = m + center + 180.0 + 102.9372
        let jTransit = 2451545.0 + jStar + 0.0053 * sind(m) - 0.0069 * sind(2 * lambda)

        let sinDecl = sind(lambda) * sind(23.4397)
        let cosDecl = (1.0 - sinDecl * sinDecl).squareRoot()
        let denom = cosd(latitude) * cosDecl
        guard denom != 0 else { return nil }

        let cosHourAngle = (sind(-0.833) - sind(latitude) * sinDecl) / denom
        guard cosHourAngle >= -1.0, cosHourAngle <= 1.0 else { return nil }

        let hourAngle = rad2deg(acos(cosHourAngle))
        let jSet = jTransit + hourAngle / 360.0
        let jRise = jTransit - hourAngle / 360.0

        return SolarEvents(sunrise: dateFromJulian(jRise), sunset: dateFromJulian(jSet))
    }

    private static func julianDayNumber(year: Int, month: Int, day: Int) -> Int {
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045
    }

    private static func dateFromJulian(_ julian: Double) -> Date {
        Date(timeIntervalSince1970: (julian - 2440587.5) * 86400.0)
    }

    private static func deg2rad(_ d: Double) -> Double { d * .pi / 180.0 }
    private static func rad2deg(_ r: Double) -> Double { r * 180.0 / .pi }
    private static func sind(_ d: Double) -> Double { sin(deg2rad(d)) }
    private static func cosd(_ d: Double) -> Double { cos(deg2rad(d)) }
}
