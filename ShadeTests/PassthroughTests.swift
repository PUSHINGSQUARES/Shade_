import AppKit
import XCTest
@testable import Shade_

@MainActor
final class PassthroughTests: XCTestCase {
    func testAppLevelRuleMatchesWindowsByBundleIdentifierInternally() {
        let rule = PassthroughApp(
            label: "Finder",
            scope: .application,
            bundleIdentifier: "com.apple.finder"
        )
        let matchingWindow = PassthroughWindowSnapshot(
            frame: NSRect(x: 100, y: 100, width: 320, height: 240),
            bundleIdentifier: "com.apple.finder",
            localizedAppName: "Finder",
            windowTitle: "Desktop"
        )
        let otherWindow = PassthroughWindowSnapshot(
            frame: NSRect(x: 100, y: 100, width: 320, height: 240),
            bundleIdentifier: "com.apple.TextEdit",
            localizedAppName: "TextEdit",
            windowTitle: "Document"
        )

        XCTAssertTrue(rule.matches(window: matchingWindow))
        XCTAssertFalse(rule.matches(window: otherWindow))
    }

    func testRuleModelKeepsFutureFieldsWithoutChangingAppScopeMatching() {
        let rule = PassthroughApp(
            label: "DaVinci Resolve",
            scope: .application,
            bundleIdentifier: "com.blackmagic-design.DaVinciResolve",
            executablePath: "/Applications/DaVinci Resolve.app",
            signingTeamIdentifier: "9ZGFBWLSYP",
            selectedWindowFingerprint: "timeline-window"
        )
        let window = PassthroughWindowSnapshot(
            frame: NSRect(x: 0, y: 0, width: 1280, height: 720),
            bundleIdentifier: "com.blackmagic-design.DaVinciResolve",
            localizedAppName: "DaVinci Resolve",
            windowTitle: "Timeline"
        )

        XCTAssertEqual(rule.scope, .application)
        XCTAssertEqual(rule.executablePath, "/Applications/DaVinci Resolve.app")
        XCTAssertEqual(rule.signingTeamIdentifier, "9ZGFBWLSYP")
        XCTAssertEqual(rule.selectedWindowFingerprint, "timeline-window")
        XCTAssertTrue(rule.matches(window: window))
    }

    func testCatalogPresentationUsesFriendlyLabelsOnly() throws {
        let catalog = PassthroughCatalog(
            applicationSnapshots: {
                [
                    RunningApplicationSnapshot(
                        localizedName: "Finder",
                        bundleIdentifier: "com.apple.finder",
                        activationPolicy: .regular,
                        icon: nil
                    ),
                    RunningApplicationSnapshot(
                        localizedName: "Menu Helper",
                        bundleIdentifier: "com.example.helper",
                        activationPolicy: .accessory,
                        icon: nil
                    )
                ]
            },
            currentBundleIdentifier: { "com.pushingsquares.shade" }
        )

        let candidates = catalog.candidates(passthroughApps: [])
        let presentation = try XCTUnwrap(candidates.first?.presentation)
        let presentationStrings = Mirror(reflecting: presentation)
            .children
            .compactMap { $0.value as? String }

        XCTAssertEqual(candidates.map(\.label), ["Finder"])
        XCTAssertEqual(presentation.label, "Finder")
        XCTAssertFalse(presentationStrings.contains("com.apple.finder"))
        XCTAssertFalse(presentationStrings.contains { $0.contains("pid") })
        XCTAssertFalse(presentationStrings.contains { $0.contains("/") })
    }

    func testCatalogMarksExistingRulesAsProtected() {
        let catalog = PassthroughCatalog(
            applicationSnapshots: {
                [
                    RunningApplicationSnapshot(
                        localizedName: "Finder",
                        bundleIdentifier: "com.apple.finder",
                        activationPolicy: .regular,
                        icon: nil
                    )
                ]
            },
            currentBundleIdentifier: { "com.pushingsquares.shade" }
        )
        let rule = PassthroughApp(
            label: "Finder",
            scope: .application,
            bundleIdentifier: "com.apple.finder"
        )

        let candidates = catalog.candidates(passthroughApps: [rule])

        XCTAssertEqual(candidates.first?.presentation.isPassthrough, true)
    }

    func testMaskConvertsProtectedWindowFramesToDisplayLocalRects() {
        let display = OverlayDisplay(frame: NSRect(x: 100, y: 100, width: 500, height: 400))
        let rule = PassthroughApp(
            label: "Finder",
            scope: .application,
            bundleIdentifier: "com.apple.finder"
        )
        let windows = [
            PassthroughWindowSnapshot(
                frame: NSRect(x: 150, y: 160, width: 200, height: 120),
                bundleIdentifier: "com.apple.finder",
                localizedAppName: "Finder",
                windowTitle: "Desktop"
            )
        ]

        let rects = PassthroughMask.clearRects(for: display, windows: windows, rules: [rule])

        XCTAssertEqual(rects, [NSRect(x: 46, y: 56, width: 208, height: 128)])
    }

    func testMaskClipsPartiallyOverlappingWindowsAndIgnoresUnmatchedApps() {
        let display = OverlayDisplay(frame: NSRect(x: 100, y: 100, width: 500, height: 400))
        let rule = PassthroughApp(
            label: "Finder",
            scope: .application,
            bundleIdentifier: "com.apple.finder"
        )
        let windows = [
            PassthroughWindowSnapshot(
                frame: NSRect(x: 50, y: 50, width: 120, height: 120),
                bundleIdentifier: "com.apple.finder",
                localizedAppName: "Finder",
                windowTitle: "Desktop"
            ),
            PassthroughWindowSnapshot(
                frame: NSRect(x: 150, y: 160, width: 200, height: 120),
                bundleIdentifier: "com.apple.TextEdit",
                localizedAppName: "TextEdit",
                windowTitle: "Document"
            )
        ]

        let rects = PassthroughMask.clearRects(for: display, windows: windows, rules: [rule])

        XCTAssertEqual(rects, [NSRect(x: 0, y: 0, width: 74, height: 74)])
    }

    func testFullscreenPassthroughWindowClearsEntireDisplay() {
        let display = OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 1440, height: 900))
        let app = PassthroughApp(label: "Player", scope: .application, bundleIdentifier: "com.example.player")
        let windows = [
            PassthroughWindowSnapshot(
                frame: NSRect(x: 0, y: 0, width: 1440, height: 900),
                bundleIdentifier: "com.example.player",
                localizedAppName: "Player",
                windowTitle: "Movie"
            )
        ]

        let rects = PassthroughMask.clearRects(for: display, windows: windows, rules: [app])

        XCTAssertEqual(rects, [NSRect(x: 0, y: 0, width: 1440, height: 900)])
    }

    func testMaskOutsetsEachClearRectByOverCoverMargin() {
        let display = OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        let rule = PassthroughApp(label: "Finder", scope: .application, bundleIdentifier: "com.apple.finder")
        let windows = [
            PassthroughWindowSnapshot(
                frame: NSRect(x: 100, y: 100, width: 100, height: 100),
                bundleIdentifier: "com.apple.finder",
                localizedAppName: "Finder",
                windowTitle: "Desktop"
            )
        ]

        let rects = PassthroughMask.clearRects(for: display, windows: windows, rules: [rule])
        let margin = PassthroughMask.overCoverMargin

        // Window at (100,100) size 100x100 on display at origin → display-local (100,100,100,100)
        // After outset by margin on all sides: (100-margin, 100-margin, 100+2*margin, 100+2*margin)
        XCTAssertEqual(rects.count, 1)
        let rect = rects[0]
        XCTAssertEqual(rect.origin.x, 100 - margin, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 100 - margin, accuracy: 0.001)
        XCTAssertEqual(rect.width, 100 + 2 * margin, accuracy: 0.001)
        XCTAssertEqual(rect.height, 100 + 2 * margin, accuracy: 0.001)
    }

    func testMaskProducesCorrectRectsWithRealisticAppKitCoordinates() {
        // Simulate a 1440×900 primary display (AppKit: origin bottom-left)
        // and a window whose CG frame was (200, 100, 400, 300) — already
        // converted to AppKit coords: (200, 900-100-300=500, 400, 300)
        let display = OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 1440, height: 900))
        let rule = PassthroughApp(label: "Safari", scope: .application, bundleIdentifier: "com.apple.Safari")
        let appKitWindow = PassthroughWindowSnapshot(
            frame: NSRect(x: 200, y: 500, width: 400, height: 300),
            bundleIdentifier: "com.apple.Safari",
            localizedAppName: "Safari",
            windowTitle: "Tab"
        )

        let rects = PassthroughMask.clearRects(for: display, windows: [appKitWindow], rules: [rule])
        XCTAssertEqual(rects.count, 1)
        let rect = rects[0]
        let m = PassthroughMask.overCoverMargin

        // Display-local coords match since display is at (0,0)
        XCTAssertEqual(rect.origin.x, 200 - m, accuracy: 0.001)
        XCTAssertEqual(rect.origin.y, 500 - m, accuracy: 0.001)
        XCTAssertEqual(rect.width, 400 + 2 * m, accuracy: 0.001)
        XCTAssertEqual(rect.height, 300 + 2 * m, accuracy: 0.001)
    }

    func testMaskOutsetClampsToDisplayBounds() {
        let display = OverlayDisplay(frame: NSRect(x: 0, y: 0, width: 640, height: 480))
        let rule = PassthroughApp(label: "Finder", scope: .application, bundleIdentifier: "com.apple.finder")
        // Window at (0,0) — outset would go negative without clamping
        let windows = [
            PassthroughWindowSnapshot(
                frame: NSRect(x: 0, y: 0, width: 50, height: 50),
                bundleIdentifier: "com.apple.finder",
                localizedAppName: "Finder",
                windowTitle: "Desktop"
            )
        ]

        let rects = PassthroughMask.clearRects(for: display, windows: windows, rules: [rule])
        let rect = rects[0]
        XCTAssertGreaterThanOrEqual(rect.origin.x, 0)
        XCTAssertGreaterThanOrEqual(rect.origin.y, 0)
    }
}
