import XCTest
@testable import Shade_

@MainActor
final class MenuBarViewTests: XCTestCase {
    func testOverlayFallbackPresentationIsPrimaryDefault() {
        let presentation = MenuBarModePresentation(mode: .overlayFallback, isEnabled: false)

        XCTAssertEqual(presentation.title, "Overlay Fallback")
        XCTAssertEqual(presentation.status, "Off")
        XCTAssertFalse(presentation.showsReadingControls)
        XCTAssertTrue(presentation.showsOverlayControls)
        XCTAssertTrue(presentation.showsPerformanceDiagnostics)
    }

    func testOverlayFallbackPresentationShowsPerformanceDiagnostics() {
        let presentation = MenuBarModePresentation(mode: .overlayFallback, isEnabled: true)

        XCTAssertEqual(presentation.title, "Overlay Fallback")
        XCTAssertEqual(presentation.status, "On")
        XCTAssertFalse(presentation.showsReadingControls)
        XCTAssertTrue(presentation.showsOverlayControls)
        XCTAssertTrue(presentation.showsPerformanceDiagnostics)
    }

    func testOverlayModeShowsPerformanceDiagnostics() {
        let presentation = MenuBarModePresentation(mode: .overlayFallback, isEnabled: true)
        XCTAssertTrue(presentation.showsPerformanceDiagnostics)
    }

    func testReadingTransformPresentationIsUnsafeDevMode() {
        let presentation = MenuBarModePresentation(mode: .readingTransform, isEnabled: false)

        XCTAssertEqual(presentation.title, "Reading Transform Dev Mode")
        XCTAssertEqual(presentation.status, "Unsafe")
        XCTAssertTrue(presentation.showsReadingControls)
        XCTAssertFalse(presentation.showsOverlayControls)
        XCTAssertTrue(presentation.showsPerformanceDiagnostics)
        XCTAssertTrue(presentation.isUnsafe)
        XCTAssertTrue(presentation.showsUnsafeWarning)
    }

    func testNormalModePickerOptionsExposeOnlyOverlayFallback() {
        XCTAssertEqual(
            MenuBarModePresentation.availableModes(readingTransformDevMode: false),
            [.overlayFallback]
        )
    }

    func testDevModePickerOptionsExposeUnsafeReadingTransform() {
        XCTAssertEqual(
            MenuBarModePresentation.availableModes(readingTransformDevMode: true),
            [.overlayFallback, .readingTransform]
        )
    }

    func testPassthroughEntryUsesProductCopy() {
        let presentation = PassthroughPresentation(appCount: 2)

        XCTAssertEqual(presentation.buttonTitle, "Passthrough...")
        XCTAssertEqual(presentation.summary, "2 passthrough apps stay clear while Shade_ stays on.")
    }

    func testScheduleEntryUsesManualLocalCopyWhenDisabled() throws {
        let presentation = SchedulePresentation(
            schedule: ShadeSchedule(
                isEnabled: false,
                startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")),
                endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00"))
            )
        )

        XCTAssertEqual(presentation.buttonTitle, "Schedule...")
        XCTAssertEqual(presentation.summary, "Manual local schedule is off.")
        XCTAssertEqual(
            presentation.detail,
            "Uses this Mac's local time. Sunrise, sunset, and city lookup are not in this phase."
        )
    }

    func testPassthroughTrailingStatus() {
        XCTAssertEqual(PassthroughPresentation(appCount: 0).trailingStatus, "Off")
        XCTAssertEqual(PassthroughPresentation(appCount: 1).trailingStatus, "1 app")
        XCTAssertEqual(PassthroughPresentation(appCount: 3).trailingStatus, "3 apps")
    }

    func testScheduleTrailingStatus() throws {
        let off = SchedulePresentation(schedule: ShadeSchedule(isEnabled: false, startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")), endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00"))))
        XCTAssertEqual(off.trailingStatus, "Off")
        let on = SchedulePresentation(schedule: ShadeSchedule(isEnabled: true, startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")), endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00"))))
        XCTAssertEqual(on.trailingStatus, "20:00–08:00")
    }

    func testScheduleEntryShowsEnabledTimeRange() throws {
        let presentation = SchedulePresentation(
            schedule: ShadeSchedule(
                isEnabled: true,
                startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")),
                endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00"))
            )
        )

        XCTAssertEqual(presentation.summary, "Manual local schedule: 20:00 to 08:00.")
    }

    func testScheduleSunSummaryWhenDisabled() throws {
        let presentation = SchedulePresentation(
            schedule: ShadeSchedule(
                isEnabled: false,
                startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")),
                endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00")),
                source: .sunsetToSunrise
            )
        )
        XCTAssertEqual(presentation.summary, "Sunset to sunrise schedule is off.")
    }

    func testScheduleSunSummaryWhenEnabledNoLocation() throws {
        let presentation = SchedulePresentation(
            schedule: ShadeSchedule(
                isEnabled: true,
                startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")),
                endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00")),
                source: .sunsetToSunrise,
                sunLocation: nil
            )
        )
        XCTAssertEqual(presentation.summary, "Sunset to sunrise: no location set.")
    }

    func testScheduleSunSummaryWhenEnabledWithLocation() throws {
        let presentation = SchedulePresentation(
            schedule: ShadeSchedule(
                isEnabled: true,
                startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")),
                endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00")),
                source: .sunsetToSunrise,
                sunLocation: ScheduleLocation(label: "London", latitude: 51.5, longitude: -0.1)
            )
        )
        XCTAssertEqual(presentation.summary, "Sunset to sunrise: London.")
    }

    func testScheduleSunSummaryWhenEnabledWithLocationAndOffset() throws {
        let presentation = SchedulePresentation(
            schedule: ShadeSchedule(
                isEnabled: true,
                startTime: try XCTUnwrap(ShadeClockTime(storageString: "20:00")),
                endTime: try XCTUnwrap(ShadeClockTime(storageString: "08:00")),
                source: .sunsetToSunrise,
                sunLocation: ScheduleLocation(label: "London", latitude: 51.5, longitude: -0.1),
                sunOffsetMinutes: 15
            )
        )
        XCTAssertEqual(presentation.summary, "Sunset to sunrise: London, +15 min offset.")
    }
}
