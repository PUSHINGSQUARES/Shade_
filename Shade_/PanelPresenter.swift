import AppKit
import SwiftUI

// Presents auxiliary panels (Passthrough, Schedule) as standalone windows rather
// than sheets on the menu-bar popover. The popover uses `.menuBarExtraStyle(.window)`
// and dismisses on focus loss, which tore down any sheet the moment the user clicked
// toward another window to pick it. A real NSWindow has its own lifecycle and stays
// open while the user interacts elsewhere.
@MainActor
final class PanelPresenter {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(
        id: String,
        title: String,
        size: NSSize,
        @ViewBuilder content: () -> Content
    ) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(contentViewController: NSHostingController(rootView: content()))
        window.title = title
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.setContentSize(size)
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close(id: String) {
        windows[id]?.close()
    }
}
