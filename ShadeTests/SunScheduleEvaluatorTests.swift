import XCTest
@testable import Shade_

final class SunScheduleEvaluatorTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private lazy var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian); c.timeZone = utc; return c
    }()
    private func at(_ h: Int, _ m: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 6; c.day = 21; c.hour = h; c.minute = m; c.timeZone = utc
        return calendar.date(from: c)!
    }
    // Sunrise 05:04, sunset 21:09 UTC.
    private let stub: SolarEventsProvider = { _, _, _, tz in
        let cal = Calendar(identifier: .gregorian)
        var rc = DateComponents(); rc.year = 2026; rc.month = 6; rc.day = 21; rc.hour = 5; rc.minute = 4
        rc.timeZone = TimeZone(identifier: "UTC")
        var sc = DateComponents(); sc.year = 2026; sc.month = 6; sc.day = 21; sc.hour = 21; sc.minute = 9
        sc.timeZone = TimeZone(identifier: "UTC")
        return SolarEvents(sunrise: cal.date(from: rc)!, sunset: cal.date(from: sc)!)
    }

    private func sunSchedule() -> ShadeSchedule {
        ShadeSchedule(
            isEnabled: true,
            startTime: ShadeClockTime(hour: 20, minute: 0)!,
            endTime: ShadeClockTime(hour: 8, minute: 0)!,
            source: .sunsetToSunrise,
            sunLocation: ScheduleLocation(label: "X", latitude: 51, longitude: 0)
        )
    }

    func testOnAfterSunsetAndBeforeSunrise() {
        XCTAssertTrue(ShadeScheduleEvaluator.shouldEnable(schedule: sunSchedule(), at: at(23, 0), calendar: calendar, solar: stub))
        XCTAssertTrue(ShadeScheduleEvaluator.shouldEnable(schedule: sunSchedule(), at: at(2, 0), calendar: calendar, solar: stub))
    }

    func testOffDuringDaylight() {
        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: sunSchedule(), at: at(12, 0), calendar: calendar, solar: stub))
    }

    func testDisabledScheduleIsOff() {
        var s = sunSchedule(); s.isEnabled = false
        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: s, at: at(23, 0), calendar: calendar, solar: stub))
    }

    func testSunWithoutLocationIsOff() {
        var s = sunSchedule(); s.sunLocation = nil
        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: s, at: at(23, 0), calendar: calendar, solar: stub))
    }
}
