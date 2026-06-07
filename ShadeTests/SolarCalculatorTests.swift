import XCTest
@testable import Shade_

final class SolarCalculatorTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testEquatorEquinoxDayLengthIsAboutTwelveHours() throws {
        let events = try XCTUnwrap(
            SolarCalculator.events(0.0, 0.0, date(2026, 3, 20), TimeZone(identifier: "UTC")!)
        )
        XCTAssertLessThan(events.sunrise, events.sunset)
        let dayLength = events.sunset.timeIntervalSince(events.sunrise)
        XCTAssertEqual(dayLength, 12 * 3600, accuracy: 20 * 60) // ~12h +/- 20 min
    }

    func testLondonSolsticeIsALongDay() throws {
        let events = try XCTUnwrap(
            SolarCalculator.events(51.5074, -0.1278, date(2026, 6, 21), TimeZone(identifier: "UTC")!)
        )
        let dayLength = events.sunset.timeIntervalSince(events.sunrise)
        XCTAssertGreaterThan(dayLength, 16 * 3600) // London solstice > 16h daylight
    }

    private func utc(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = min
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    // Regression: longitude sign. A western-hemisphere city must match NOAA. With the
    // sign inverted, NYC sunrise came out ~00:53 UTC (local night) instead of ~10:44 UTC.
    func testNewYorkEquinoxMatchesNOAA() throws {
        let events = try XCTUnwrap(
            SolarCalculator.events(40.7128, -74.0060, date(2026, 9, 23), TimeZone(identifier: "UTC")!)
        )
        // NOAA: sunrise 06:44 EDT (10:44 UTC), sunset 18:54 EDT (22:54 UTC).
        XCTAssertEqual(events.sunrise.timeIntervalSince(utc(2026, 9, 23, 10, 44)), 0, accuracy: 4 * 60)
        XCTAssertEqual(events.sunset.timeIntervalSince(utc(2026, 9, 23, 22, 54)), 0, accuracy: 4 * 60)
    }

    // Tightened: London solstice to within a few minutes of NOAA, not just ">16h".
    func testLondonSolsticeMatchesNOAA() throws {
        let events = try XCTUnwrap(
            SolarCalculator.events(51.5074, -0.1278, date(2026, 6, 21), TimeZone(identifier: "UTC")!)
        )
        // NOAA: sunrise 04:43 BST (03:43 UTC), sunset 21:21 BST (20:21 UTC).
        XCTAssertEqual(events.sunrise.timeIntervalSince(utc(2026, 6, 21, 3, 43)), 0, accuracy: 4 * 60)
        XCTAssertEqual(events.sunset.timeIntervalSince(utc(2026, 6, 21, 20, 21)), 0, accuracy: 4 * 60)
    }

    // Regression: eastern hemisphere. In Sydney's own timezone the winter sunrise must be
    // a morning hour. With the sign inverted it landed at ~03:10 AEST instead of ~07:00.
    func testSydneyWinterSunriseIsMorningLocalTime() throws {
        let syd = TimeZone(identifier: "Australia/Sydney")!
        let events = try XCTUnwrap(
            SolarCalculator.events(-33.8688, 151.2093, date(2026, 6, 21), syd)
        )
        let sunriseLocal = ShadeClockTime(date: events.sunrise, timeZone: syd)
        let sunsetLocal = ShadeClockTime(date: events.sunset, timeZone: syd)
        XCTAssertTrue((6...8).contains(sunriseLocal.hour), "sunrise hour \(sunriseLocal.hour)")
        XCTAssertTrue((16...18).contains(sunsetLocal.hour), "sunset hour \(sunsetLocal.hour)")
    }

    func testPolarSummerReturnsNil() {
        XCTAssertNil(SolarCalculator.events(78.0, 15.0, date(2026, 6, 21), TimeZone(identifier: "UTC")!))
    }

    func testPolarWinterReturnsNil() {
        XCTAssertNil(SolarCalculator.events(78.0, 15.0, date(2026, 12, 21), TimeZone(identifier: "UTC")!))
    }
}
