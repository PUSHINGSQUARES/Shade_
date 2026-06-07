import Foundation
import CoreVideo

// MARK: - Tick source protocol

protocol TrackerTickSource {
    func start(callback: @escaping @Sendable () -> Void)
    func stop()
}

// MARK: - DisplayLinkTickSource

final class DisplayLinkTickSource: TrackerTickSource {
    private var displayLink: CVDisplayLink?
    private var callbackBox: DisplayLinkCallbackBox?

    func start(callback: @escaping @Sendable () -> Void) {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        displayLink = link
        let box = DisplayLinkCallbackBox(callback: callback)
        callbackBox = box
        CVDisplayLinkSetOutputCallback(link, { _, _, _, _, _, userInfo -> CVReturn in
            guard let userInfo else { return kCVReturnSuccess }
            let box = Unmanaged<DisplayLinkCallbackBox>.fromOpaque(userInfo).takeUnretainedValue()
            box.callback()
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(box).toOpaque())
        CVDisplayLinkStart(link)
    }

    func stop() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
        callbackBox = nil
    }
}

private final class DisplayLinkCallbackBox {
    let callback: @Sendable () -> Void
    init(callback: @escaping @Sendable () -> Void) { self.callback = callback }
}

// MARK: - ManualTickSource (for tests)

// ManualTickSource is designed to be called exclusively on the main actor (test context).
// It stores the callback in a nonisolated(unsafe) container so start/stop satisfy the
// protocol without isolation requirements. Call start/stop/fire only from @MainActor.
final class ManualTickSource: TrackerTickSource {
    nonisolated(unsafe) private var callback: (@Sendable () -> Void)?

    func start(callback: @escaping @Sendable () -> Void) {
        self.callback = callback
    }

    func stop() {
        callback = nil
    }

    // Call only from @MainActor (test context)
    func fire() {
        callback?()
    }
}

// MARK: - TimerTickSource (backward-compatibility convenience)

private final class TimerTickSource: TrackerTickSource {
    private let interval: TimeInterval
    private var timer: Timer?

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func start(callback: @escaping @Sendable () -> Void) {
        guard timer == nil else { return }
        let t = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in callback() }
        }
        // .common modes so the timer keeps firing during menu tracking and other run-loop modes.
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - PassthroughTracker

@MainActor
final class PassthroughTracker {
    static let defaultInterval: TimeInterval = 0.04 // ~25 Hz

    private let tickSource: TrackerTickSource
    private let onTick: @MainActor () -> Void
    private var running = false
    // Prevents macOS App Nap from suspending the tracking timer while the menu-bar
    // app is idle (the cause of the cutout freezing until a UI event woke the app).
    private var activityToken: NSObjectProtocol?

    // Convenience init — timer-based, preserved for backward compatibility
    init(interval: TimeInterval = PassthroughTracker.defaultInterval, onTick: @escaping @MainActor () -> Void) {
        self.tickSource = TimerTickSource(interval: interval)
        self.onTick = onTick
    }

    // Designated init — injectable tick source
    init(tickSource: TrackerTickSource, onTick: @escaping @MainActor () -> Void) {
        self.tickSource = tickSource
        self.onTick = onTick
    }

    var isRunning: Bool { running }

    func start() {
        guard !running else { return }
        running = true
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .latencyCritical],
            reason: "Tracking protected window position"
        )
        tickSource.start { [weak self] in
            guard let self else { return }
            if Thread.isMainThread {
                MainActor.assumeIsolated { self.fireNow() }
            } else {
                // Background (CVDisplayLink) thread — hop to main every frame.
                // Per-tick work is cheap (implicit animation disabled, mask layers
                // reused, PID lookups cached), so an unthrottled per-frame update
                // tracks the window live without pileup.
                DispatchQueue.main.async { [weak self] in self?.fireNow() }
            }
        }
    }

    func stop() {
        running = false
        tickSource.stop()
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    func fireNow() {
        guard running else { return }
        onTick()
    }
}
