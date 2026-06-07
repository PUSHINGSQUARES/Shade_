import AppKit
import QuartzCore

@MainActor
final class ShadeCoordinator {
    typealias PassthroughWindowSnapshotProvider = () -> [PassthroughWindowSnapshot]
    typealias OverlayDisplayProvider = () -> [OverlayDisplay]

    private let state: AppState
    private let overlayController: OverlayFallbackControlling
    private let passthroughWindowSnapshots: PassthroughWindowSnapshotProvider
    private let overlayDisplays: OverlayDisplayProvider
    // 60Hz main-run-loop timer: CVDisplayLink callbacks did not fire continuously in this
    // menu-bar (accessory) app, so the cutout only updated on UI events. A scheduled Timer
    // ticks reliably on the main run loop; velocity prediction keeps it smooth.
    private lazy var passthroughTracker = PassthroughTracker(interval: 1.0 / 60.0) { [weak self] in
        self?.passthroughTrackerTick()
    }
    private let motionPredictor = WindowMotionPredictor()
    private var lastAppliedClearRects: [PassthroughDisplayRects] = []

    init(
        state: AppState,
        overlayController: OverlayFallbackControlling = OverlayFallbackController(),
        passthroughWindowSnapshots: @escaping PassthroughWindowSnapshotProvider = {
            PassthroughWindowSnapshot.currentVisibleWindows()
        },
        overlayDisplays: @escaping OverlayDisplayProvider = {
            NSScreen.screens.map(OverlayDisplay.init(screen:))
        }
    ) {
        self.state = state
        self.overlayController = overlayController
        self.passthroughWindowSnapshots = passthroughWindowSnapshots
        self.overlayDisplays = overlayDisplays
    }

    var isTrackingPassthrough: Bool { passthroughTracker.isRunning }

    func setEnabled(_ isEnabled: Bool) {
        if state.isTransformEnabled != isEnabled {
            state.isTransformEnabled = isEnabled
        }

        if isEnabled {
            startCurrentMode()
        } else {
            passthroughTracker.stop()
            overlayController.hide()
            lastAppliedClearRects = []
            motionPredictor.reset()
        }
    }

    func modeDidChange() {
        guard state.isTransformEnabled else { return }
        passthroughTracker.stop()
        overlayController.hide()
        lastAppliedClearRects = []
        motionPredictor.reset()
        startCurrentMode()
    }

    func overlaySettingsDidChange() {
        guard state.mode == .overlayFallback else { return }

        updateOverlayFallbackVisibility()
    }

    func foregroundAppDidChange() {
        guard state.mode == .overlayFallback else { return }

        updateOverlayFallbackVisibility()
    }

    private func startCurrentMode() {
        switch state.mode {
        case .readingTransform:
            guard state.isReadingTransformDevModeEnabled else {
                state.mode = .overlayFallback
                state.lastError = "Reading Transform is locked to unsafe Dev Mode. Overlay Fallback started instead."
                updateOverlayFallbackVisibility()
                return
            }
            // Phase A: inert — capture path retired; reserved for Phase B 3D-LUT engine.
            overlayController.hide()
            state.framesPerSecond = 0
            state.frameLatencyMilliseconds = 0
        case .overlayFallback:
            updateOverlayFallbackVisibility()
            state.lastError = nil
            state.framesPerSecond = 0
            state.frameLatencyMilliseconds = 0
        }
    }

    func suspendPassthroughTracking() { passthroughTracker.stop() }
    func resumePassthroughTracking() { updatePassthroughTracking() }

    func passthroughTrackerTick() {
        guard state.mode == .overlayFallback, state.shouldShowOverlayFallback else { return }

        let tickStart = CACurrentMediaTime()
        let rects = currentPredictedClearRects(timestamp: tickStart)

        guard rects != lastAppliedClearRects else { return }
        lastAppliedClearRects = rects

        overlayController.update(appearance: OverlayFallbackAppearance(state: state, clearDisplayRects: rects))

        let latencyMs = (CACurrentMediaTime() - tickStart) * 1000.0
        state.holeTrackingLatencyMilliseconds = latencyMs
        state.holeTrackingTrailing = latencyMs > 16.0
    }

    private func updateOverlayFallbackVisibility() {
        guard state.mode == .overlayFallback,
              state.shouldShowOverlayFallback else {
            overlayController.hide()
            lastAppliedClearRects = []
            motionPredictor.reset()
            passthroughTracker.stop()
            return
        }

        let rects = currentPredictedClearRects(timestamp: CACurrentMediaTime())
        lastAppliedClearRects = rects
        let appearance = OverlayFallbackAppearance(state: state, clearDisplayRects: rects)
        if overlayController.isShowing {
            overlayController.update(appearance: appearance)
        } else {
            overlayController.show(appearance: appearance)
        }
        updatePassthroughTracking()
    }

    private func updatePassthroughTracking() {
        let shouldTrack = state.mode == .overlayFallback
            && state.shouldShowOverlayFallback
            && !state.passthroughApps.isEmpty
        if shouldTrack {
            passthroughTracker.start()
        } else {
            passthroughTracker.stop()
        }
    }

    private func currentPassthroughClearRects() -> [PassthroughDisplayRects] {
        let apps = state.passthroughApps
        guard !apps.isEmpty else { return [] }

        return PassthroughMask.clearRectsByDisplay(
            displays: overlayDisplays(),
            windows: passthroughWindowSnapshots(),
            rules: apps
        )
    }

    private func currentPredictedClearRects(timestamp: Double) -> [PassthroughDisplayRects] {
        let apps = state.passthroughApps
        guard !apps.isEmpty else { return [] }

        let windows = passthroughWindowSnapshots()
        let predictions = motionPredictor.update(
            windows: windows,
            rules: apps,
            timestamp: timestamp,
            config: state.motionPredictionConfig
        )

        return PassthroughMask.clearRectsByDisplayFromPredictions(
            displays: overlayDisplays(),
            predictions: predictions
        )
    }
}
