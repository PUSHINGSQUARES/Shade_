import XCTest
@testable import Shade_

final class ShadeClockTimeMathTests: XCTestCase {
    func testInitFromDateUsesGivenTimeZone() {
        // 2026-06-21 20:30:00 UTC
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 21; c.hour = 20; c.minute = 30
        c.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: c)!

        let utc = ShadeClockTime(date: date, timeZone: TimeZone(identifier: "UTC")!)
        XCTAssertEqual(utc, ShadeClockTime(hour: 20, minute: 30))

        let bst = ShadeClockTime(date: date, timeZone: TimeZone(identifier: "Europe/London")!)
        XCTAssertEqual(bst, ShadeClockTime(hour: 21, minute: 30)) // BST = UTC+1
    }

    func testAddingMinutesWrapsWithinDay() {
        XCTAssertEqual(ShadeClockTime(hour: 23, minute: 50)!.adding(minutes: 20),
                       ShadeClockTime(hour: 0, minute: 10)!)
        XCTAssertEqual(ShadeClockTime(hour: 0, minute: 10)!.adding(minutes: -20),
                       ShadeClockTime(hour: 23, minute: 50)!)
        XCTAssertEqual(ShadeClockTime(hour: 21, minute: 9)!.adding(minutes: -30),
                       ShadeClockTime(hour: 20, minute: 39)!)
    }
}
