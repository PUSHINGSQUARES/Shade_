import AppKit

// MARK: - OverlayDisplay

struct OverlayDisplay: Equatable {
    let frame: NSRect
    let screen: NSScreen?

    init(screen: NSScreen) {
        self.frame = screen.frame
        self.screen = screen
    }

    init(frame: NSRect) {
        self.frame = frame
        self.screen = nil
    }
}

struct OverlayFallbackAppearance: Equatable {
    let tintRed: Double
    let tintGreen: Double
    let tintBlue: Double
    let opacity: Double
    let dim: Double
    let clearRects: [NSRect]
    let clearDisplayRects: [PassthroughDisplayRects]

    var tintColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(tintRed),
            green: CGFloat(tintGreen),
            blue: CGFloat(tintBlue),
            alpha: CGFloat(opacity)
        )
    }

    var dimColor: NSColor {
        NSColor.black.withAlphaComponent(CGFloat(dim))
    }

    init(
        tintRed: Double,
        tintGreen: Double,
        tintBlue: Double,
        opacity: Double,
        dim: Double,
        clearRects: [NSRect] = [],
        clearDisplayRects: [PassthroughDisplayRects] = []
    ) {
        self.tintRed = tintRed
        self.tintGreen = tintGreen
        self.tintBlue = tintBlue
        self.opacity = opacity
        self.dim = dim
        self.clearRects = clearRects
        self.clearDisplayRects = clearDisplayRects
    }

    @MainActor
    init(state: AppState, clearDisplayRects: [PassthroughDisplayRects] = []) {
        let tint = OverlayTintResolver.resolve(state.overlayTintInputs)
        self.init(
            tintRed: tint.red,
            tintGreen: tint.green,
            tintBlue: tint.blue,
            opacity: tint.strength,
            dim: tint.dim,
            clearRects: clearDisplayRects.flatMap(\.clearRects),
            clearDisplayRects: clearDisplayRects
        )
    }

    func clearRects(for display: OverlayDisplay) -> [NSRect] {
        if let displayRects = clearDisplayRects.first(where: { $0.displayFrame == display.frame }) {
            return displayRects.clearRects
        }

        return clearRects
    }
}

@MainActor
protocol OverlayFallbackControlling: AnyObject {
    var isShowing: Bool { get }

    func show(appearance: OverlayFallbackAppearance)
    func hide()
    func update(appearance: OverlayFallbackAppearance)
}

@MainActor
final class OverlayFallbackWindow {
    let window: NSWindow
    private let display: OverlayDisplay
    private let tintView: NSView
    private let dimView: NSView
    var tintMaskLayer: CAShapeLayer? {
        tintView.layer?.mask as? CAShapeLayer
    }
    var dimMaskLayer: CAShapeLayer? {
        dimView.layer?.mask as? CAShapeLayer
    }

    init(display: OverlayDisplay, appearance: OverlayFallbackAppearance) {
        self.display = display
        let contentFrame = NSRect(origin: .zero, size: display.frame.size)
        let rootView = NSView(frame: contentFrame)
        rootView.autoresizingMask = [.width, .height]

        tintView = NSView(frame: contentFrame)
        tintView.autoresizingMask = [.width, .height]

        dimView = NSView(frame: contentFrame)
        dimView.autoresizingMask = [.width, .height]

        rootView.addSubview(tintView)
        rootView.addSubview(dimView)

        // `display.frame` is in global screen coordinates. Passing a non-nil
        // `screen:` makes NSWindow treat the origin as screen-relative, which
        // double-offsets every non-primary display and flings its overlay
        // off-screen (so only the primary display gets tinted). Pass nil so the
        // global frame is honored; the frame alone places the window on the
        // correct physical display.
        window = NSWindow(
            contentRect: display.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: nil
        )
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.contentView = rootView

        update(appearance: appearance)
    }

    func show() {
        window.orderFrontRegardless()
    }

    func hide() {
        window.orderOut(nil)
    }

    func update(appearance: OverlayFallbackAppearance) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintView.wantsLayer = true
        tintView.layer?.backgroundColor = appearance.tintColor.cgColor
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = appearance.dimColor.cgColor
        updateMask(clearRects: appearance.clearRects(for: display))
        CATransaction.commit()
        // Force the render server to commit immediately so the cutout tracks
        // without waiting for a UI event to wake the run loop.
        CATransaction.flush()
    }

    private func updateMask(clearRects: [NSRect]) {
        guard !clearRects.isEmpty else {
            tintMaskLayer.map { _ in tintView.layer?.mask = nil }
            dimMaskLayer.map { _ in dimView.layer?.mask = nil }
            return
        }

        let bounds = tintView.bounds
        let path = CGMutablePath()
        path.addRect(bounds)
        for rect in clearRects where !rect.isNull && !rect.isEmpty {
            path.addRect(rect)
        }

        applyMask(path: path, bounds: bounds, to: tintView)
        applyMask(path: path, bounds: bounds, to: dimView)
    }

    private func applyMask(path: CGPath, bounds: CGRect, to view: NSView) {
        if let existing = view.layer?.mask as? CAShapeLayer {
            existing.frame = bounds
            existing.path = path
        } else {
            let maskLayer = CAShapeLayer()
            maskLayer.frame = bounds
            maskLayer.path = path
            maskLayer.fillRule = .evenOdd
            maskLayer.fillColor = NSColor.black.cgColor
            view.layer?.mask = maskLayer
        }
    }
}

@MainActor
final class OverlayFallbackController: OverlayFallbackControlling {
    typealias ScreenProvider = () -> [OverlayDisplay]

    private let screenProvider: ScreenProvider
    private(set) var windows: [OverlayFallbackWindow] = []

    var isShowing: Bool {
        !windows.isEmpty
    }

    var windowCount: Int {
        windows.count
    }

    init(screenProvider: @escaping ScreenProvider = { NSScreen.screens.map(OverlayDisplay.init(screen:)) }) {
        self.screenProvider = screenProvider
    }

    func show(appearance: OverlayFallbackAppearance) {
        hide()
        windows = screenProvider().map {
            OverlayFallbackWindow(display: $0, appearance: appearance)
        }
        windows.forEach { $0.show() }
    }

    func hide() {
        windows.forEach { $0.hide() }
        windows.removeAll()
    }

    func update(appearance: OverlayFallbackAppearance) {
        windows.forEach { $0.update(appearance: appearance) }
    }
}
