import XCTest
import ServiceManagement
@testable import Shade_

@MainActor
final class LoginItemControllerTests: XCTestCase {
    func testMapTranslatesEverySystemStatus() {
        XCTAssertEqual(LoginItemController.map(.enabled), .enabled)
        XCTAssertEqual(LoginItemController.map(.requiresApproval), .requiresApproval)
        XCTAssertEqual(LoginItemController.map(.notRegistered), .notEnabled)
        XCTAssertEqual(LoginItemController.map(.notFound), .notFound)
    }

    func testSetEnabledTrueRegistersOnceAndReturnsEnabled() {
        let fake = FakeLoginItemService()
        let controller = LoginItemController(service: fake)

        let result = controller.setEnabled(true)

        XCTAssertEqual(result, .enabled)
        XCTAssertEqual(fake.registerCount, 1)
        XCTAssertEqual(fake.unregisterCount, 0)
    }

    func testSetEnabledFalseUnregistersOnceAndReturnsNotEnabled() {
        let fake = FakeLoginItemService()
        fake.status = .enabled
        let controller = LoginItemController(service: fake)

        let result = controller.setEnabled(false)

        XCTAssertEqual(result, .notEnabled)
        XCTAssertEqual(fake.unregisterCount, 1)
    }

    func testRefreshStatusReflectsServiceStatus() {
        let fake = FakeLoginItemService()
        fake.status = .requiresApproval
        let controller = LoginItemController(service: fake)

        XCTAssertEqual(controller.refreshStatus(), .requiresApproval)
    }

    func testRegisterThrowReturnsFailedWithMessage() {
        let fake = FakeLoginItemService()
        fake.registerError = NSError(
            domain: "test", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "boom"]
        )
        let controller = LoginItemController(service: fake)

        let result = controller.setEnabled(true)

        XCTAssertEqual(result, .failed("boom"))
        XCTAssertEqual(fake.registerCount, 1)
    }

    func testUnregisterThrowReturnsFailedWithMessage() {
        let fake = FakeLoginItemService()
        fake.status = .enabled
        fake.unregisterError = NSError(
            domain: "test", code: 2,
            userInfo: [NSLocalizedDescriptionKey: "nope"]
        )
        let controller = LoginItemController(service: fake)

        let result = controller.setEnabled(false)

        XCTAssertEqual(result, .failed("nope"))
    }

    func testPresentationTextForEachStatus() {
        XCTAssertEqual(LoginItemStatusPresentation.text(.enabled), "Enabled")
        XCTAssertEqual(LoginItemStatusPresentation.text(.notEnabled), "Not enabled")
        XCTAssertEqual(
            LoginItemStatusPresentation.text(.requiresApproval),
            "Needs your approval in System Settings \u{2192} General \u{2192} Login Items"
        )
        XCTAssertEqual(
            LoginItemStatusPresentation.text(.notFound),
            "Not found \u{2014} a reinstall may be required"
        )
        XCTAssertEqual(
            LoginItemStatusPresentation.text(.failed("x")),
            "Registration failed \u{2014} x"
        )
    }

    func testPresentationIsErrorAndIsOn() {
        XCTAssertTrue(LoginItemStatusPresentation.isError(.failed("x")))
        XCTAssertFalse(LoginItemStatusPresentation.isError(.enabled))
        XCTAssertTrue(LoginItemStatusPresentation.isOn(.enabled))
        XCTAssertFalse(LoginItemStatusPresentation.isOn(.requiresApproval))
        XCTAssertFalse(LoginItemStatusPresentation.isOn(.notEnabled))
    }

    func testNotFoundIsAnError() {
        // .notFound means the login-item service entry is missing — user must reinstall.
        // The Settings view renders isError=true in red, so this must return true.
        XCTAssertTrue(LoginItemStatusPresentation.isError(.notFound))
    }

    // MARK: - displayedToggleValue

    func testDisplayedToggleValueNoPendingReflectsStatus() {
        XCTAssertFalse(LoginItemStatusPresentation.displayedToggleValue(pendingEnable: nil, status: .notEnabled))
        XCTAssertTrue(LoginItemStatusPresentation.displayedToggleValue(pendingEnable: nil, status: .enabled))
    }

    func testDisplayedToggleValuePendingOverridesStatus() {
        // Pending true while still notEnabled — toggle must show the pending intent.
        XCTAssertTrue(LoginItemStatusPresentation.displayedToggleValue(pendingEnable: true, status: .notEnabled))
        // Pending false while still enabled — toggle must show the pending intent.
        XCTAssertFalse(LoginItemStatusPresentation.displayedToggleValue(pendingEnable: false, status: .enabled))
    }
}

final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status = .notRegistered
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}
