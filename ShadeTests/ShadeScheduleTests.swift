import XCTest
@testable import Shade_

final class ShadeScheduleTests: XCTestCase {
    func testClockTimeParsesAndFormatsTwentyFourHourValues() throws {
        let time = try XCTUnwrap(ShadeClockTime(storageString: "20:05"))

        XCTAssertEqual(time.hour, 20)
        XCTAssertEqual(time.minute, 5)
        XCTAssertEqual(time.storageString, "20:05")
    }

    func testClockTimeRejectsInvalidValues() {
        XCTAssertNil(ShadeClockTime(storageString: "24:00"))
        XCTAssertNil(ShadeClockTime(storageString: "08:60"))
        XCTAssertNil(ShadeClockTime(storageString: "8:00"))
        XCTAssertNil(ShadeClockTime(storageString: "08:0"))
        XCTAssertNil(ShadeClockTime(storageString: "evening"))
    }

    func testSameDayScheduleIsActiveInsideRange() throws {
        let schedule = try makeSchedule(start: "09:00", end: "17:00")

        XCTAssertTrue(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 12, minute: 30)))
        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 18, minute: 0)))
    }

    func testOvernightScheduleIsActiveBeforeAndAfterMidnight() throws {
        let schedule = try makeSchedule(start: "20:00", end: "08:00")

        XCTAssertTrue(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 22, minute: 0)))
        XCTAssertTrue(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 6, minute: 30)))
        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 12, minute: 0)))
    }

    func testScheduleIsActiveAtStartAndInactiveAtEnd() throws {
        let schedule = try makeSchedule(start: "20:00", end: "08:00")

        XCTAssertTrue(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 20, minute: 0)))
        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 8, minute: 0)))
    }

    func testDisabledScheduleNeverRequestsEnabledOutput() throws {
        let schedule = try makeSchedule(isEnabled: false, start: "09:00", end: "17:00")

        XCTAssertFalse(ShadeScheduleEvaluator.shouldEnable(schedule: schedule, at: makeDate(hour: 12, minute: 0)))
    }

    @MainActor
    func testTickerSkipsApplyWhenScheduleIsDisabled() throws {
        var appliedDates: [Date] = []
        let ticker = ShadeScheduleTicker(
            scheduleProvider: {
                try! self.makeSchedule(isEnabled: false, start: "09:00", end: "17:00")
            },
            apply: { appliedDates.append($0) },
            dateProvider: { self.makeDate(hour: 12, minute: 0) }
        )

        ticker.fireNow()

        XCTAssertTrue(appliedDates.isEmpty)
    }

    @MainActor
    func testTickerAppliesWhenScheduleIsEnabled() throws {
        let expectedDate = makeDate(hour: 12, minute: 0)
        var appliedDates: [Date] = []
        let ticker = ShadeScheduleTicker(
            scheduleProvider: {
                try! self.makeSchedule(isEnabled: true, start: "09:00", end: "17:00")
            },
            apply: { appliedDates.append($0) },
            dateProvider: { expectedDate }
        )

        ticker.fireNow()

        XCTAssertEqual(appliedDates, [expectedDate])
    }

    private func makeSchedule(isEnabled: Bool = true, start: String, end: String) throws -> ShadeSchedule {
        ShadeSchedule(
            isEnabled: isEnabled,
            startTime: try XCTUnwrap(ShadeClockTime(storageString: start)),
            endTime: try XCTUnwrap(ShadeClockTime(storageString: end))
        )
    }

    private func makeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 25
        components.hour = hour
        components.minute = minute
        return components.date!
    }
}
