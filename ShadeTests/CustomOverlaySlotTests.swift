import XCTest
@testable import Shade_

@MainActor
final class CustomOverlaySlotTests: XCTestCase {
    func testSlotRoundTripsThroughCodable() throws {
        let inputs = OverlayTintInputs(
            useCustomColour: true, kelvin: 2300, blueCut: 0.4,
            hue: 0.6, saturation: 0.35, strength: 0.2, dim: 0.1
        )
        let filled = CustomOverlaySlot(name: "Sunset", inputs: inputs)
        let empty = CustomOverlaySlot(name: "Custom 2", inputs: nil)

        let data = try JSONEncoder().encode([filled, empty])
        let decoded = try JSONDecoder().decode([CustomOverlaySlot].self, from: data)

        XCTAssertEqual(decoded, [filled, empty])
        XCTAssertNil(decoded[1].inputs)
    }

    func testDefaultSlotsAreThreeEmptyNamedCustom() {
        let state = AppState(userDefaults: makeUserDefaults())

        XCTAssertEqual(state.customSlots.count, 3)
        XCTAssertEqual(state.customSlots.map(\.name), ["Custom 1", "Custom 2", "Custom 3"])
        XCTAssertTrue(state.customSlots.allSatisfy { $0.inputs == nil })
        XCTAssertNil(state.selectedCustomSlotIndex)
    }

    func testSaveCustomSlotCapturesCurrentInputsAndSelects() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.overlayUseCustomColour = true
        state.overlayHue = 0.6
        state.overlaySaturation = 0.35
        state.overlayOpacity = 0.2
        state.overlayDim = 0.1

        state.saveCustomSlot(index: 0)

        XCTAssertEqual(state.customSlots[0].inputs, state.overlayTintInputs)
        XCTAssertEqual(state.customSlots[0].name, "Custom 1")
        XCTAssertEqual(state.selectedCustomSlotIndex, 0)
    }

    func testRenameCustomSlotUpdatesNameAndFallsBackWhenEmpty() {
        let userDefaults = makeUserDefaults()
        let state = AppState(userDefaults: userDefaults)

        state.renameCustomSlot(index: 2, name: "  Night  ")
        XCTAssertEqual(state.customSlots[2].name, "Night")

        state.renameCustomSlot(index: 2, name: "   ")
        XCTAssertEqual(state.customSlots[2].name, "Custom 3")

        let reloaded = AppState(userDefaults: userDefaults)
        XCTAssertEqual(reloaded.customSlots[2].name, "Custom 3")
    }

    func testSlotsAndSelectionPersistAcrossLaunches() {
        let userDefaults = makeUserDefaults()
        let first = AppState(userDefaults: userDefaults)
        first.overlayUseCustomColour = true
        first.overlayHue = 0.6
        first.saveCustomSlot(index: 1)
        first.renameCustomSlot(index: 1, name: "Sunset")

        let second = AppState(userDefaults: userDefaults)

        XCTAssertEqual(second.customSlots[1].name, "Sunset")
        XCTAssertEqual(second.customSlots[1].inputs, first.customSlots[1].inputs)
        XCTAssertNil(second.customSlots[0].inputs)
        XCTAssertEqual(second.selectedCustomSlotIndex, 1)
    }

    func testApplyCustomSlotRestoresInputsAndSelects() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.overlayUseCustomColour = true
        state.overlayHue = 0.6
        state.overlaySaturation = 0.35
        state.overlayOpacity = 0.2
        state.overlayDim = 0.1
        state.saveCustomSlot(index: 0)
        let saved = state.overlayTintInputs

        state.setPreset(.gentle)
        state.applyCustomSlot(index: 0)

        XCTAssertEqual(state.overlayTintInputs, saved)
        XCTAssertEqual(state.overlayPreset, .custom)
        XCTAssertEqual(state.selectedCustomSlotIndex, 0)
    }

    func testApplyEmptySlotIsNoOp() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.setPreset(.balanced)
        let before = state.overlayTintInputs

        state.applyCustomSlot(index: 2)

        XCTAssertEqual(state.overlayTintInputs, before)
        XCTAssertNil(state.selectedCustomSlotIndex)
    }

    func testEditingSliderAfterApplyClearsSelection() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.overlayUseCustomColour = true
        state.overlayHue = 0.6
        state.saveCustomSlot(index: 0)
        state.applyCustomSlot(index: 0)
        XCTAssertEqual(state.selectedCustomSlotIndex, 0)

        state.overlayDim = 0.3

        XCTAssertNil(state.selectedCustomSlotIndex)
        XCTAssertEqual(state.overlayPreset, .custom)
    }

    func testTappingBuiltInPresetClearsSelection() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.saveCustomSlot(index: 0)
        state.applyCustomSlot(index: 0)
        XCTAssertEqual(state.selectedCustomSlotIndex, 0)

        state.setPreset(.balanced)

        XCTAssertNil(state.selectedCustomSlotIndex)
        XCTAssertEqual(state.overlayPreset, .balanced)
    }

    func testSaveOverFilledSlotReplacesInputsKeepsName() {
        let state = AppState(userDefaults: makeUserDefaults())
        state.overlayUseCustomColour = true
        state.overlayHue = 0.6
        state.saveCustomSlot(index: 0)
        state.renameCustomSlot(index: 0, name: "Sunset")

        state.overlayHue = 0.2
        state.saveCustomSlot(index: 0)

        XCTAssertEqual(state.customSlots[0].name, "Sunset")
        XCTAssertEqual(state.customSlots[0].inputs, state.overlayTintInputs)
        XCTAssertEqual(state.customSlots[0].inputs!.hue, 0.2, accuracy: 0.001)
    }

    func testMalformedStoredSlotsLoadAsThreeEmptyDefaults() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(Data("not-json".utf8), forKey: AppState.PersistenceKey.customSlots)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.customSlots.map(\.name), ["Custom 1", "Custom 2", "Custom 3"])
        XCTAssertTrue(state.customSlots.allSatisfy { $0.inputs == nil })
    }

    func testWrongLengthStoredSlotsLoadAsDefaults() throws {
        let userDefaults = makeUserDefaults()
        let oneSlot = [CustomOverlaySlot(name: "Only", inputs: nil)]
        userDefaults.set(try JSONEncoder().encode(oneSlot), forKey: AppState.PersistenceKey.customSlots)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertEqual(state.customSlots.count, 3)
        XCTAssertEqual(state.customSlots.map(\.name), ["Custom 1", "Custom 2", "Custom 3"])
    }

    func testOutOfRangeStoredSelectionLoadsAsNil() {
        let userDefaults = makeUserDefaults()
        let first = AppState(userDefaults: userDefaults)
        first.saveCustomSlot(index: 0)
        userDefaults.set(99, forKey: AppState.PersistenceKey.selectedCustomSlotIndex)

        let second = AppState(userDefaults: userDefaults)

        XCTAssertNil(second.selectedCustomSlotIndex)
    }

    func testSelectionPointingAtEmptySlotLoadsAsNil() {
        let userDefaults = makeUserDefaults()
        userDefaults.set(2, forKey: AppState.PersistenceKey.selectedCustomSlotIndex)

        let state = AppState(userDefaults: userDefaults)

        XCTAssertNil(state.selectedCustomSlotIndex)
    }

    func testSaveCustomSlotSetsPresetToCustom() {
        let state = AppState(userDefaults: makeUserDefaults())
        // Explicitly land on a named preset without touching any sliders,
        // so markCustom() is NOT called between setPreset and saveCustomSlot.
        state.setPreset(.gentle)
        XCTAssertEqual(state.overlayPreset, .gentle)

        state.saveCustomSlot(index: 0)

        XCTAssertEqual(state.overlayPreset, .custom,
            "saveCustomSlot must set overlayPreset to .custom to stay consistent with applyCustomSlot")
        XCTAssertEqual(state.selectedCustomSlotIndex, 0)
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "com.pushingsquares.shade.tests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}
