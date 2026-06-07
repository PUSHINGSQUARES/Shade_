import XCTest
@testable import Shade_

final class ShadeScheduleResolverTests: XCTestCase {
    private func t(_ h: Int, _ m: Int) -> ShadeClockTime { ShadeClockTime(hour: h, minute: m)! }
    private let utc = TimeZone(identifier: "UTC")!
    private lazy var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = utc; return c
    }()
    private func date(_ y: Int, _ mo: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = mo; c.day = d; c.hour = 12; c.timeZone = utc
        return calendar.date(from: c)!
    }

    // Solar stub: sunrise 05:04, sunset 21:09 UTC on the test date.
    private func stub(sunriseH: Int, sunriseM: Int, sunsetH: Int, sunsetM: Int) -> SolarEventsProvider {
        { _, _, d, _ in
            var rc = DateComponents(); rc.year = 2026; rc.month = 6; rc.day = 21
            rc.hour = sunriseH; rc.minute = sunriseM; rc.timeZone = self.utc
            var sc = DateComponents(); sc.year = 2026; sc.month = 6; sc.day = 21
            sc.hour = sunsetH; sc.minute = sunsetM; sc.timeZone = self.utc
            let cal = Calendar(identifier: .gregorian)
            return SolarEvents(sunrise: cal.date(from: rc)!, sunset: cal.date(from: sc)!)
        }
    }

    func testManualSourcePassesTimesThrough() {
        let s = ShadeSchedule(isEnabled: true, startTime: t(20, 0), endTime: t(8, 0))
        let result = ShadeScheduleResolver.effectiveTimes(schedule: s, at: date(2026, 6, 21), calendar: calendar)
        XCTAssertEqual(result?.start, t(20, 0))
        XCTAssertEqual(result?.end, t(8, 0))
    }

    func testSunSourceComputesFromLocation() {
        let s = ShadeSchedule(
            isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
            source: .sunsetToSunrise,
            sunLocation: ScheduleLocation(label: "X", latitude: 51, longitude: 0),
            sunOffsetMinutes: 0
        )
        let result = ShadeScheduleResolver.effectiveTimes(
            schedule: s, at: date(2026, 6, 21), calendar: calendar,
            solar: stub(sunriseH: 5, sunriseM: 4, sunsetH: 21, sunsetM: 9)
        )
        XCTAssertEqual(result?.start, t(21, 9))  // sunset -> start
        XCTAssertEqual(result?.end, t(5, 4))     // sunrise -> end
    }

    func testSunSourceAppliesOffsetToBothEdges() {
        let s = ShadeSchedule(
            isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
            source: .sunsetToSunrise,
            sunLocation: ScheduleLocation(label: "X", latitude: 51, longitude: 0),
            sunOffsetMinutes: -30
        )
        let result = ShadeScheduleResolver.effectiveTimes(
            schedule: s, at: date(2026, 6, 21), calendar: calendar,
            solar: stub(sunriseH: 5, sunriseM: 4, sunsetH: 21, sunsetM: 9)
        )
        XCTAssertEqual(result?.start, t(20, 39)) // sunset - 30
        XCTAssertEqual(result?.end, t(4, 34))    // sunrise - 30
    }

    func testSunSourceWithoutLocationReturnsNil() {
        let s = ShadeSchedule(isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
                              source: .sunsetToSunrise, sunLocation: nil)
        XCTAssertNil(ShadeScheduleResolver.effectiveTimes(schedule: s, at: date(2026, 6, 21), calendar: calendar))
    }

    func testSunSourcePolarNilReturnsNil() {
        let s = ShadeSchedule(
            isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
            source: .sunsetToSunrise,
            sunLocation: ScheduleLocation(label: "Polar", latitude: 78, longitude: 15)
        )
        let result = ShadeScheduleResolver.effectiveTimes(
            schedule: s, at: date(2026, 6, 21), calendar: calendar,
            solar: { _, _, _, _ in nil }
        )
        XCTAssertNil(result)
    }
}
