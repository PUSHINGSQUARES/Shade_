import XCTest
@testable import Shade_

final class KeyboardShortcutControllerTests: XCTestCase {
    func testStartWiresRegistrarCallbackToDisableAction() throws {
        let registrar = MockHotKeyRegistrar()
        let controller = KeyboardShortcutController(registrar: registrar)
        var disableCount = 0
        controller.onDisable = {
            disableCount += 1
        }

        try controller.start()
        registrar.fire()

        XCTAssertEqual(disableCount, 1)
    }

    func testStartSurfacesRegistrarFailure() {
        let expectedError = MockHotKeyRegistrarError.registrationFailed
        let registrar = MockHotKeyRegistrar(error: expectedError)
        let controller = KeyboardShortcutController(registrar: registrar)

        XCTAssertThrowsError(try controller.start()) { error in
            XCTAssertEqual(error as? MockHotKeyRegistrarError, expectedError)
        }
    }
}

private enum MockHotKeyRegistrarError: Error, Equatable {
    case registrationFailed
}

private final class MockHotKeyRegistrar: HotKeyRegistering {
    private let error: Error?
    private var onFire: (() -> Void)?

    init(error: Error? = nil) {
        self.error = error
    }

    func register(onFire: @escaping () -> Void) throws {
        if let error {
            throw error
        }
        self.onFire = onFire
    }

    func unregister() {
        onFire = nil
    }

    func fire() {
        onFire?()
    }
}
