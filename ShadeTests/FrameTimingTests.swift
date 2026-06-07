import XCTest
@testable import Shade_

final class FrameTimingTests: XCTestCase {
    func testReportsFramesPerSecondAfterOneSecondWindow() {
        var timing = FrameTiming()

        timing.recordFrame(presentationTime: 0.0, latencyMilliseconds: 10)
        timing.recordFrame(presentationTime: 0.5, latencyMilliseconds: 14)
        timing.recordFrame(presentationTime: 1.0, latencyMilliseconds: 16)

        XCTAssertEqual(timing.framesPerSecond, 3.0, accuracy: 0.001)
        XCTAssertEqual(timing.averageLatencyMilliseconds, 13.333, accuracy: 0.01)
    }

    func testDropsFramesOlderThanOneSecondWindow() {
        var timing = FrameTiming()

        timing.recordFrame(presentationTime: 0.0, latencyMilliseconds: 20)
        timing.recordFrame(presentationTime: 1.2, latencyMilliseconds: 10)
        timing.recordFrame(presentationTime: 1.4, latencyMilliseconds: 10)

        XCTAssertEqual(timing.framesPerSecond, 2.0, accuracy: 0.001)
        XCTAssertEqual(timing.averageLatencyMilliseconds, 10.0, accuracy: 0.001)
    }
}
