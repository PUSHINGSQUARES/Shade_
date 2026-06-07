import SwiftUI

@main
struct ShadeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appState = AppState()
    @State private var coordinator: ShadeCoordinator?
    @State private var panelPresenter = PanelPresenter()
    @State private var foregroundApplicationMonitor = ForegroundApplicationMonitor()
    @State private var scheduleTicker: ShadeScheduleTicker?
    private let shortcutController = KeyboardShortcutController()

    var body: some Scene {
        MenuBarExtra("Shade_", systemImage: appState.isTransformEnabled ? "sun.max.fill" : "sun.max") {
            MenuBarView(state: appState, presenter: panelPresenter)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .background {
                shortcutController.stop()
                foregroundApplicationMonitor.stop()
                stopScheduleTicker()
                coordinator?.suspendPassthroughTracking()
            } else {
                startShortcutController()
                startForegroundApplicationMonitor()
                startScheduleTicker()
                coordinator?.resumePassthroughTracking()
            }
        }
        .onChange(of: appState.isTransformEnabled) { _, newValue in
            ensureCoordinator().setEnabled(newValue)
        }
        .onChange(of: appState.mode) { _, _ in
            ensureCoordinator().modeDidChange()
        }
        .onChange(of: appState.overlayHue) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlayOpacity) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlayDim) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlayKelvin) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlayBlueCut) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlaySaturation) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlayUseCustomColour) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.overlayPreset) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.passthroughApps) { _, _ in
            ensureCoordinator().overlaySettingsDidChange()
        }
        .onChange(of: appState.schedule) { _, _ in
            ensureScheduleTicker().fireNow()
        }
    }

    @MainActor
    private func startShortcutController() {
        shortcutController.onDisable = {
            Task { @MainActor in
                appState.disableTransform()
                coordinator?.setEnabled(false)
            }
        }

        do {
            try shortcutController.start()
        } catch {
            appState.lastError = "Keyboard shortcut unavailable: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func startForegroundApplicationMonitor() {
        foregroundApplicationMonitor.start { _ in
            coordinator?.foregroundAppDidChange()
        }
    }

    @MainActor
    private func startScheduleTicker() {
        ensureScheduleTicker().start()
    }

    @MainActor
    private func stopScheduleTicker() {
        scheduleTicker?.stop()
    }

    @MainActor
    private func ensureCoordinator() -> ShadeCoordinator {
        if let coordinator {
            return coordinator
        }

        let coordinator = ShadeCoordinator(state: appState)
        self.coordinator = coordinator
        return coordinator
    }

    @MainActor
    private func ensureScheduleTicker() -> ShadeScheduleTicker {
        if let scheduleTicker {
            return scheduleTicker
        }

        let ticker = ShadeScheduleTicker(
            scheduleProvider: {
                appState.schedule
            },
            apply: { date in
                appState.applySchedule(at: date)
            }
        )
        scheduleTicker = ticker
        return ticker
    }
}
