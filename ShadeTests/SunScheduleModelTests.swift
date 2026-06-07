import XCTest
@testable import Shade_

@MainActor
final class SunScheduleModelTests: XCTestCase {
    private func t(_ h: Int, _ m: Int) -> ShadeClockTime { ShadeClockTime(hour: h, minute: m)! }

    func testScheduleDefaultsToManualSourceNoLocationZeroOffset() {
        let s = ShadeSchedule(isEnabled: false, startTime: t(20, 0), endTime: t(8, 0))
        XCTAssertEqual(s.source, .manualTimes)
        XCTAssertNil(s.sunLocation)
        XCTAssertEqual(s.sunOffsetMinutes, 0)
    }

    func testOffsetIsClampedInInit() {
        let lo = ShadeSchedule(isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
                               source: .sunsetToSunrise, sunLocation: nil, sunOffsetMinutes: -500)
        let hi = ShadeSchedule(isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
                               source: .sunsetToSunrise, sunLocation: nil, sunOffsetMinutes: 500)
        XCTAssertEqual(lo.sunOffsetMinutes, -120)
        XCTAssertEqual(hi.sunOffsetMinutes, 120)
    }

    func testScheduleLocationRoundTripsThroughCodable() throws {
        let loc = ScheduleLocation(label: "Bristol, UK", latitude: 51.45, longitude: -2.59)
        let data = try JSONEncoder().encode(loc)
        let decoded = try JSONDecoder().decode(ScheduleLocation.self, from: data)
        XCTAssertEqual(decoded, loc)
    }

    func testSunScheduleFieldsPersistAcrossLaunches() {
        let userDefaults = UserDefaults(suiteName: "shade.suntest.\(UUID().uuidString)")!
        let first = AppState(userDefaults: userDefaults)
        first.schedule = ShadeSchedule(
            isEnabled: true, startTime: t(20, 0), endTime: t(8, 0),
            source: .sunsetToSunrise,
            sunLocation: ScheduleLocation(label: "Bristol, UK", latitude: 51.45, longitude: -2.59),
            sunOffsetMinutes: -30
        )

        let second = AppState(userDefaults: userDefaults)

        XCTAssertEqual(second.schedule.source, .sunsetToSunrise)
        XCTAssertEqual(second.schedule.sunLocation?.label, "Bristol, UK")
        XCTAssertEqual(second.schedule.sunOffsetMinutes, -30)
    }

    func testLegacyScheduleWithoutSunKeysLoadsAsManual() {
        let userDefaults = UserDefaults(suiteName: "shade.suntest.\(UUID().uuidString)")!
        userDefaults.set(true, forKey: AppState.PersistenceKey.scheduleEnabled)
        userDefaults.set("20:00", forKey: AppState.PersistenceKey.scheduleStartTime)
        userDefaults.set("08:00", forKey: AppState.PersistenceKey.scheduleEndTime)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.schedule.source, .manualTimes)
        XCTAssertNil(state.schedule.sunLocation)
        XCTAssertEqual(state.schedule.sunOffsetMinutes, 0)
    }
}
