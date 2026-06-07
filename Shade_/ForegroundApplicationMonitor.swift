import AppKit

struct RunningApplicationSnapshot {
    let localizedName: String?
    let bundleIdentifier: String?
    let activationPolicy: NSApplication.ActivationPolicy
    let icon: NSImage?

    init(
        localizedName: String?,
        bundleIdentifier: String?,
        activationPolicy: NSApplication.ActivationPolicy,
        icon: NSImage?
    ) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.activationPolicy = activationPolicy
        self.icon = icon
    }

    init(application: NSRunningApplication) {
        self.init(
            localizedName: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            activationPolicy: application.activationPolicy,
            icon: application.icon
        )
    }
}

@MainActor
final class ForegroundApplicationMonitor {
    private let workspace: NSWorkspace
    private var observer: NSObjectProtocol?

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func start(onChange: @escaping @MainActor (String?) -> Void) {
        stop()
        onChange(workspace.frontmostApplication?.bundleIdentifier)

        observer = workspace.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notification in
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleIdentifier = application?.bundleIdentifier

            Task { @MainActor in
                onChange(bundleIdentifier)
            }
        }
    }

    func stop() {
        if let observer {
            workspace.notificationCenter.removeObserver(observer)
        }

        observer = nil
    }
}
