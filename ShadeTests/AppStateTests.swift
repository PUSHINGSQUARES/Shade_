import XCTest
@testable import Shade_

@MainActor
final class AppStateTests: XCTestCase {
    func testDefaultsUseOverlayFallback() {
        let state = AppState(userDefaults: makeUserDefaults())

        XCTAssertFalse(state.isTransformEnabled)
        XCTAssertEqual(state.mode, .overlayFallback)
        XCTAssertEqual(state.intensity, 0.35, accuracy: 0.001)
        XCTAssertEqual(state.blueReduction, 0.45, accuracy: 0.001)
        XCTAssertEqual(state.dim, 0.10, accuracy: 0.001)
        XCTAssertTrue(state.contrastProtect)
        XCTAssertTrue(state.showPerformanceHUD)
    }

    func testPersistedSettingsLoadIntoFreshState() {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)
        firstState.intensity = 0.72
        firstState.blueReduction = 0.18
        firstState.dim = 0.44
        firstState.contrastProtect = false
        firstState.showPerformanceHUD = false

        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertFalse(secondState.isTransformEnabled)
        XCTAssertEqual(secondState.intensity, 0.72, accuracy: 0.001)
        XCTAssertEqual(secondState.blueReduction, 0.18, accuracy: 0.001)
        XCTAssertEqual(secondState.dim, 0.44, accuracy: 0.001)
        XCTAssertFalse(secondState.contrastProtect)
        XCTAssertFalse(secondState.showPerformanceHUD)
    }

    func testInvalidStoredSettingsAreSanitized() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(Double.nan, forKey: AppState.PersistenceKey.intensity)
        userDefaults.set(-0.25, forKey: AppState.PersistenceKey.blueReduction)
        userDefaults.set(2.0, forKey: AppState.PersistenceKey.dim)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.intensity, 0.35, accuracy: 0.001)
        XCTAssertEqual(state.blueReduction, 0, accuracy: 0.001)
        XCTAssertEqual(state.dim, 0.8, accuracy: 0.001)
    }

    func testAssignedSettingsAreSanitizedBeforePersistence() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults)

        state.intensity = Double.infinity
        state.blueReduction = 1.25
        state.dim = -0.5

        let reloadedState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.intensity, 0.35, accuracy: 0.001)
        XCTAssertEqual(state.blueReduction, 1, accuracy: 0.001)
        XCTAssertEqual(state.dim, 0, accuracy: 0.001)
        XCTAssertEqual(reloadedState.intensity, 0.35, accuracy: 0.001)
        XCTAssertEqual(reloadedState.blueReduction, 1, accuracy: 0.001)
        XCTAssertEqual(reloadedState.dim, 0, accuracy: 0.001)
    }

    func testTransformEnabledDoesNotPersistAcrossLaunches() {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)
        firstState.isTransformEnabled = true

        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertFalse(secondState.isTransformEnabled)
    }

    func testDefaultScheduleIsManualOvernightAndDisabled() throws {
        let state = AppState(userDefaults: makeUserDefaults())

        XCTAssertFalse(state.schedule.isEnabled)
        XCTAssertEqual(state.schedule.startTime, try XCTUnwrap(ShadeClockTime(storageString: "20:00")))
        XCTAssertEqual(state.schedule.endTime, try XCTUnwrap(ShadeClockTime(storageString: "08:00")))
    }

    func testScheduleSettingsPersistAcrossLaunchesWithoutPersistingEnabledIntent() throws {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)
        firstState.schedule = ShadeSchedule(
            isEnabled: true,
            startTime: try XCTUnwrap(ShadeClockTime(storageString: "21:15")),
            endTime: try XCTUnwrap(ShadeClockTime(storageString: "07:45"))
        )
        firstState.isTransformEnabled = true

        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertTrue(secondState.schedule.isEnabled)
        XCTAssertEqual(secondState.schedule.startTime, try XCTUnwrap(ShadeClockTime(storageString: "21:15")))
        XCTAssertEqual(secondState.schedule.endTime, try XCTUnwrap(ShadeClockTime(storageString: "07:45")))
        XCTAssertFalse(secondState.isTransformEnabled)
    }

    func testApplyingDisabledScheduleNeverAutoEnablesShade() throws {
        let state = AppState(userDefaults: makeUserDefaults())
        state.schedule = ShadeSchedule(
            isEnabled: false,
            startTime: try XCTUnwrap(ShadeClockTime(storageString: "09:00")),
            endTime: try XCTUnwrap(ShadeClockTime(storageString: "17:00"))
        )

        state.applySchedule(at: makeDate(hour: 12, minute: 0))

        XCTAssertFalse(state.isTransformEnabled)
    }

    func testApplyingEnabledScheduleOnlyMutatesEnabledIntent() throws {
        let state = AppState(userDefaults: makeUserDefaults())
        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        state.schedule = ShadeSchedule(
            isEnabled: true,
            startTime: try XCTUnwrap(ShadeClockTime(storageString: "09:00")),
            endTime: try XCTUnwrap(ShadeClockTime(storageString: "17:00"))
        )
        let passthroughApps = state.passthroughApps

        state.applySchedule(at: makeDate(hour: 12, minute: 0))

        XCTAssertTrue(state.isTransformEnabled)
        XCTAssertEqual(state.passthroughApps, passthroughApps)
    }

    func testDisableTurnsTransformOffAndClearsError() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.isTransformEnabled = true
        state.lastError = "Capture failed"

        state.disableTransform()

        XCTAssertFalse(state.isTransformEnabled)
        XCTAssertNil(state.lastError)
    }

    func testResetReadingDefaultsRestoresPersistedControlDefaults() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults)
        state.intensity = 0.82
        state.blueReduction = 0.16
        state.dim = 0.62
        state.contrastProtect = false

        state.resetReadingDefaults()
        let reloadedState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.intensity, 0.35, accuracy: 0.001)
        XCTAssertEqual(state.blueReduction, 0.45, accuracy: 0.001)
        XCTAssertEqual(state.dim, 0.10, accuracy: 0.001)
        XCTAssertTrue(state.contrastProtect)
        XCTAssertEqual(reloadedState.intensity, 0.35, accuracy: 0.001)
        XCTAssertEqual(reloadedState.blueReduction, 0.45, accuracy: 0.001)
        XCTAssertEqual(reloadedState.dim, 0.10, accuracy: 0.001)
        XCTAssertTrue(reloadedState.contrastProtect)
    }

    func testModePersistsAcrossLaunches() {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)
        firstState.mode = .overlayFallback

        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(secondState.mode, .overlayFallback)
    }

    func testStoredReadingTransformFallsBackToOverlayMode() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(AppState.Mode.readingTransform.rawValue, forKey: AppState.PersistenceKey.mode)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.mode, .overlayFallback)
        XCTAssertEqual(userDefaults.string(forKey: AppState.PersistenceKey.mode), AppState.Mode.overlayFallback.rawValue)
    }

    func testStoredReadingTransformCanLoadOnlyWhenDevModeIsEnabled() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(AppState.Mode.readingTransform.rawValue, forKey: AppState.PersistenceKey.mode)

        let state = AppState(userDefaults: userDefaults, readingTransformDevMode: true)

        XCTAssertTrue(state.isReadingTransformDevModeEnabled)
        XCTAssertEqual(state.mode, .readingTransform)
        XCTAssertEqual(userDefaults.string(forKey: AppState.PersistenceKey.mode), AppState.Mode.readingTransform.rawValue)
    }

    func testEnvironmentCanEnableReadingTransformDevMode() {
        let key = AppState.Defaults.readingTransformDevModeEnvironmentKey
        let previousValue = getenv(key).map { String(cString: $0) }
        setenv(key, "1", 1)
        defer {
            if let previousValue {
                setenv(key, previousValue, 1)
            } else {
                unsetenv(key)
            }
        }

        let userDefaults = makeUserDefaults()
        userDefaults.set(AppState.Mode.readingTransform.rawValue, forKey: AppState.PersistenceKey.mode)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertTrue(state.isReadingTransformDevModeEnabled)
        XCTAssertEqual(state.mode, .readingTransform)
    }

    func testAssigningReadingTransformFallsBackWithoutDevMode() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults)

        state.mode = .readingTransform

        XCTAssertFalse(state.isReadingTransformDevModeEnabled)
        XCTAssertEqual(state.mode, .overlayFallback)
        XCTAssertEqual(userDefaults.string(forKey: AppState.PersistenceKey.mode), AppState.Mode.overlayFallback.rawValue)
    }

    func testAssigningReadingTransformPersistsWithDevMode() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults, readingTransformDevMode: true)

        state.mode = .readingTransform

        XCTAssertEqual(state.mode, .readingTransform)
        XCTAssertEqual(userDefaults.string(forKey: AppState.PersistenceKey.mode), AppState.Mode.readingTransform.rawValue)
    }

    func testOverlaySettingsPersistAcrossLaunches() {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)
        firstState.overlayHue = 0.18
        firstState.overlayOpacity = 0.42
        firstState.overlayDim = 0.37

        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(secondState.overlayHue, 0.18, accuracy: 0.001)
        XCTAssertEqual(secondState.overlayOpacity, 0.42, accuracy: 0.001)
        XCTAssertEqual(secondState.overlayDim, 0.37, accuracy: 0.001)
    }

    func testInvalidStoredOverlaySettingsAreSanitized() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(Double.nan, forKey: AppState.PersistenceKey.overlayHue)
        userDefaults.set(2.0, forKey: AppState.PersistenceKey.overlayOpacity)
        userDefaults.set(-0.25, forKey: AppState.PersistenceKey.overlayDim)
        userDefaults.set(OverlayPreset.custom.rawValue, forKey: AppState.PersistenceKey.overlayPreset)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.overlayHue, AppState.Defaults.overlayHue, accuracy: 0.001)
        XCTAssertEqual(state.overlayOpacity, 0.8, accuracy: 0.001)
        XCTAssertEqual(state.overlayDim, 0, accuracy: 0.001)
    }

    func testAssignedOverlaySettingsAreSanitizedBeforePersistence() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults)

        state.overlayHue = -0.5
        state.overlayOpacity = Double.infinity
        state.overlayDim = 1.4

        let reloadedState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.overlayHue, 0, accuracy: 0.001)
        XCTAssertEqual(state.overlayOpacity, AppState.Defaults.overlayOpacity, accuracy: 0.001)
        XCTAssertEqual(state.overlayDim, 0.8, accuracy: 0.001)
        XCTAssertEqual(reloadedState.overlayHue, 0, accuracy: 0.001)
        XCTAssertEqual(reloadedState.overlayOpacity, AppState.Defaults.overlayOpacity, accuracy: 0.001)
        XCTAssertEqual(reloadedState.overlayDim, 0.8, accuracy: 0.001)
    }

    func testPassthroughAppsPersistAcrossLaunches() {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)

        firstState.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        firstState.addPassthroughApp(label: "Safari", bundleIdentifier: "com.apple.Safari")

        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(secondState.passthroughApps.map(\.label), ["Finder", "Safari"])
        XCTAssertEqual(
            secondState.passthroughApps.map(\.bundleIdentifier),
            ["com.apple.finder", "com.apple.Safari"]
        )
    }

    func testPassthroughAppsIgnoreBlankValues() {
        let state = AppState(userDefaults: makeUserDefaults())

        state.addPassthroughApp(label: "", bundleIdentifier: "com.apple.finder")
        state.addPassthroughApp(label: "Finder", bundleIdentifier: "")
        state.addPassthroughApp(label: "   ", bundleIdentifier: "   ")

        XCTAssertTrue(state.passthroughApps.isEmpty)
    }

    func testRemovingPassthroughAppPersists() throws {
        let userDefaults = makeUserDefaults()
        let firstState = AppState(userDefaults: userDefaults)
        firstState.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")
        firstState.addPassthroughApp(label: "Safari", bundleIdentifier: "com.apple.Safari")
        let finderApp = try XCTUnwrap(firstState.passthroughApps.first { $0.label == "Finder" })

        firstState.removePassthroughApp(id: finderApp.id)
        let secondState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(secondState.passthroughApps.map(\.label), ["Safari"])
    }

    func testAddingPassthroughAppDoesNotMutateEnabledIntent() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.isTransformEnabled = true

        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")

        XCTAssertTrue(state.isTransformEnabled)
    }

    func testOverlayVisibilityDependsOnlyOnEnabledIntent() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.isTransformEnabled = true
        state.addPassthroughApp(label: "Finder", bundleIdentifier: "com.apple.finder")

        XCTAssertTrue(state.shouldShowOverlayFallback)

        state.isTransformEnabled = false
        XCTAssertFalse(state.shouldShowOverlayFallback)
    }

    func testResetOverlayDefaultsRestoresBalancedPresetOnly() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults)
        state.intensity = 0.82
        state.blueReduction = 0.16
        state.dim = 0.62
        state.contrastProtect = false
        state.setPreset(.deepCut)

        state.resetOverlayDefaults()
        let reloadedState = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.intensity, 0.82, accuracy: 0.001)
        XCTAssertEqual(state.blueReduction, 0.16, accuracy: 0.001)
        XCTAssertEqual(state.dim, 0.62, accuracy: 0.001)
        XCTAssertFalse(state.contrastProtect)
        XCTAssertEqual(state.overlayPreset, .balanced)
        XCTAssertEqual(state.overlayKelvin, 2500, accuracy: 0.001)
        XCTAssertEqual(state.overlayOpacity, 0.22, accuracy: 0.001)
        XCTAssertEqual(state.overlayDim, 0.28, accuracy: 0.001)
        XCTAssertEqual(reloadedState.overlayPreset, .balanced)
        XCTAssertEqual(reloadedState.overlayKelvin, 2500, accuracy: 0.001)
    }

    func testFreshInstallDefaultsToBalancedPreset() {
        let state = AppState(userDefaults: makeUserDefaults())

        XCTAssertEqual(state.overlayPreset, .balanced)
        XCTAssertFalse(state.overlayUseCustomColour)
        XCTAssertEqual(state.overlayKelvin, 2500, accuracy: 0.001)
        XCTAssertEqual(state.overlayBlueCut, 0.6, accuracy: 0.001)
        XCTAssertEqual(state.overlayOpacity, 0.22, accuracy: 0.001)
        XCTAssertEqual(state.overlayDim, 0.28, accuracy: 0.001)
    }

    func testSetPresetAppliesAllValues() {
        let state = AppState(userDefaults: makeUserDefaults())

        state.setPreset(.deepCut)

        XCTAssertEqual(state.overlayPreset, .deepCut)
        XCTAssertEqual(state.overlayKelvin, 2000, accuracy: 0.001)
        XCTAssertEqual(state.overlayBlueCut, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.overlayOpacity, 0.30, accuracy: 0.001)
        XCTAssertEqual(state.overlayDim, 0.15, accuracy: 0.001)
        XCTAssertFalse(state.overlayUseCustomColour)
    }

    func testReadingPresetEnablesCustomColour() {
        let state = AppState(userDefaults: makeUserDefaults())

        state.setPreset(.blue)

        XCTAssertEqual(state.overlayPreset, .blue)
        XCTAssertTrue(state.overlayUseCustomColour)
        XCTAssertEqual(state.overlayHue, 0.60, accuracy: 0.001)
    }

    func testEditingSliderDeselectsPreset() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.setPreset(.gentle)

        state.overlayKelvin = 4200

        XCTAssertEqual(state.overlayPreset, .custom)
        XCTAssertEqual(state.overlayKelvin, 4200, accuracy: 0.001)
    }

    func testPresetPersistsAcrossLaunches() {
        let userDefaults = makeUserDefaults()
        let first = AppState(userDefaults: userDefaults)
        first.setPreset(.deepCut)

        let second = AppState(userDefaults: userDefaults)

        XCTAssertEqual(second.overlayPreset, .deepCut)
        XCTAssertEqual(second.overlayKelvin, 2000, accuracy: 0.001)
    }

    func testStaleHueWithoutPresetKeepsHueAndDefaultsToBalanced() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(0.42, forKey: AppState.PersistenceKey.overlayHue)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.overlayPreset, .balanced)
        XCTAssertFalse(state.overlayUseCustomColour)
        XCTAssertEqual(state.overlayHue, 0.42, accuracy: 0.001, "Pre-existing hue is retained as the custom-colour seed")
    }

    func testOverlayKelvinClampsToRange() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.overlayKelvin = 100
        XCTAssertEqual(state.overlayKelvin, 1900, accuracy: 0.001)
        state.overlayKelvin = 99999
        XCTAssertEqual(state.overlayKelvin, 6500, accuracy: 0.001)
    }

    func testInitialisesOnMainActor() {
        let state = AppState(userDefaults: makeUserDefaults())

        XCTAssertFalse(state.isTransformEnabled)
        XCTAssertTrue(Thread.isMainThread)
    }

    func testParametersReflectCurrentControls() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.intensity = 0.2
        state.blueReduction = 0.7
        state.dim = 0.3
        state.contrastProtect = false

        XCTAssertEqual(state.parameters.intensity, 0.2, accuracy: 0.001)
        XCTAssertEqual(state.parameters.blueReduction, 0.7, accuracy: 0.001)
        XCTAssertEqual(state.parameters.dim, 0.3, accuracy: 0.001)
        XCTAssertFalse(state.parameters.contrastProtect)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "com.pushingsquares.shade.tests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
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
