import ServiceManagement

enum LoginItemStatus: Equatable {
    case enabled
    case notEnabled
    case requiresApproval
    case notFound
    case failed(String)
}

@MainActor
final class LoginItemController {
    private let service: LoginItemService

    init(service: LoginItemService = SMAppServiceLoginItemService()) {
        self.service = service
    }

    func refreshStatus() -> LoginItemStatus {
        Self.map(service.status)
    }

    func setEnabled(_ enabled: Bool) -> LoginItemStatus {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            return .failed(error.localizedDescription)
        }
        return Self.map(service.status)
    }

    static func map(_ status: SMAppService.Status) -> LoginItemStatus {
        switch status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .notEnabled
        case .notFound: return .notFound
        @unknown default: return .notEnabled
        }
    }
}

enum LoginItemStatusPresentation {
    static func text(_ status: LoginItemStatus) -> String {
        switch status {
        case .enabled:
            return "Enabled"
        case .notEnabled:
            return "Not enabled"
        case .requiresApproval:
            return "Needs your approval in System Settings \u{2192} General \u{2192} Login Items"
        case .notFound:
            return "Not found \u{2014} a reinstall may be required"
        case .failed(let message):
            return "Registration failed \u{2014} \(message)"
        }
    }

    static func isError(_ status: LoginItemStatus) -> Bool {
        switch status {
        case .failed, .notFound: return true
        default: return false
        }
    }

    static func isOn(_ status: LoginItemStatus) -> Bool {
        status == .enabled
    }

    // Returns the value the Settings toggle should display: the pending intent while a
    // confirmation alert is open, or the committed status once it resolves.
    static func displayedToggleValue(pendingEnable: Bool?, status: LoginItemStatus) -> Bool {
        pendingEnable ?? isOn(status)
    }
}
