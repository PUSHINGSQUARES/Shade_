import AppKit
import CoreGraphics

enum PassthroughScope: String, Codable, Equatable {
    case application
}

struct PassthroughApp: Identifiable, Codable, Equatable {
    let id: UUID
    let label: String
    let scope: PassthroughScope
    let bundleIdentifier: String
    let executablePath: String?
    let signingTeamIdentifier: String?
    let selectedWindowFingerprint: String?

    init(
        id: UUID = UUID(),
        label: String,
        scope: PassthroughScope,
        bundleIdentifier: String,
        executablePath: String? = nil,
        signingTeamIdentifier: String? = nil,
        selectedWindowFingerprint: String? = nil
    ) {
        self.id = id
        self.label = label
        self.scope = scope
        self.bundleIdentifier = bundleIdentifier
        self.executablePath = executablePath
        self.signingTeamIdentifier = signingTeamIdentifier
        self.selectedWindowFingerprint = selectedWindowFingerprint
    }

    func matches(window: PassthroughWindowSnapshot) -> Bool {
        switch scope {
        case .application:
            return bundleIdentifier == window.bundleIdentifier
        }
    }
}

struct PassthroughWindowSnapshot: Equatable {
    let frame: NSRect
    let bundleIdentifier: String?
    let localizedAppName: String?
    let windowTitle: String?

    @MainActor private static var pidCache: [pid_t: (bundleIdentifier: String?, localizedName: String?)] = [:]
    @MainActor private static var pidCacheGeneration: Int = 0

    @MainActor
    static func currentVisibleWindows() -> [PassthroughWindowSnapshot] {
        guard let windowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        pidCacheGeneration += 1
        if pidCacheGeneration > 300 {
            pidCache.removeAll(keepingCapacity: true)
            pidCacheGeneration = 0
        }

        return windowInfo.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any] else {
                return nil
            }

            var cgFrame = CGRect.zero
            guard CGRectMakeWithDictionaryRepresentation(boundsDictionary as CFDictionary, &cgFrame),
                  !cgFrame.isNull,
                  !cgFrame.isEmpty else {
                return nil
            }

            let appKitFrame = NSRect(
                x: cgFrame.origin.x,
                y: primaryHeight - cgFrame.origin.y - cgFrame.height,
                width: cgFrame.width,
                height: cgFrame.height
            )

            let pid = info[kCGWindowOwnerPID as String] as? pid_t
            let cached = pid.flatMap { pidCache[$0] }
            let bundleID: String?
            let appName: String?
            if let cached {
                bundleID = cached.bundleIdentifier
                appName = cached.localizedName
            } else if let pid {
                let application = NSRunningApplication(processIdentifier: pid)
                bundleID = application?.bundleIdentifier
                appName = application?.localizedName
                pidCache[pid] = (bundleID, appName)
            } else {
                bundleID = nil
                appName = nil
            }

            return PassthroughWindowSnapshot(
                frame: appKitFrame,
                bundleIdentifier: bundleID,
                localizedAppName: appName ?? info[kCGWindowOwnerName as String] as? String,
                windowTitle: info[kCGWindowName as String] as? String
            )
        }
    }
}

struct PassthroughCandidatePresentation: Identifiable {
    let id: String
    let label: String
    let icon: NSImage?
    let isPassthrough: Bool
}

struct PassthroughCandidate: Identifiable {
    var id: String { bundleIdentifier }

    let label: String
    let bundleIdentifier: String
    let icon: NSImage?
    let isPassthrough: Bool

    var presentation: PassthroughCandidatePresentation {
        PassthroughCandidatePresentation(
            id: label,
            label: label,
            icon: icon,
            isPassthrough: isPassthrough
        )
    }
}

@MainActor
struct PassthroughCatalog {
    private let applicationSnapshots: () -> [RunningApplicationSnapshot]
    private let currentBundleIdentifier: () -> String?

    init(
        applicationSnapshots: @escaping () -> [RunningApplicationSnapshot] = {
            NSWorkspace.shared.runningApplications.map(RunningApplicationSnapshot.init(application:))
        },
        currentBundleIdentifier: @escaping () -> String? = {
            Bundle.main.bundleIdentifier
        }
    ) {
        self.applicationSnapshots = applicationSnapshots
        self.currentBundleIdentifier = currentBundleIdentifier
    }

    func candidates(passthroughApps: [PassthroughApp]) -> [PassthroughCandidate] {
        var candidatesByBundleIdentifier: [String: PassthroughCandidate] = [:]
        let currentBundleIdentifier = currentBundleIdentifier()
        let passthroughBundleIdentifiers = Set(passthroughApps.map(\.bundleIdentifier))

        for snapshot in applicationSnapshots() where snapshot.activationPolicy == .regular {
            guard let bundleIdentifier = sanitized(snapshot.bundleIdentifier),
                  bundleIdentifier != currentBundleIdentifier,
                  let label = sanitized(snapshot.localizedName) else {
                continue
            }

            let candidate = PassthroughCandidate(
                label: label,
                bundleIdentifier: bundleIdentifier,
                icon: snapshot.icon,
                isPassthrough: passthroughBundleIdentifiers.contains(bundleIdentifier)
            )

            let existingCandidate = candidatesByBundleIdentifier[bundleIdentifier]
            if existingCandidate == nil || label < existingCandidate!.label {
                candidatesByBundleIdentifier[bundleIdentifier] = candidate
            }
        }

        return candidatesByBundleIdentifier.values.sorted {
            $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
        }
    }

    private func sanitized(_ value: String?) -> String? {
        let sanitizedValue = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sanitizedValue, !sanitizedValue.isEmpty else {
            return nil
        }

        return sanitizedValue
    }
}

struct PassthroughDisplayRects: Equatable {
    let displayFrame: NSRect
    let clearRects: [NSRect]
}

enum PassthroughMask {
    static let overCoverMargin: CGFloat = 4.0

    static func clearRects(
        for display: OverlayDisplay,
        windows: [PassthroughWindowSnapshot],
        rules: [PassthroughApp]
    ) -> [NSRect] {
        guard !rules.isEmpty else {
            return []
        }

        return windows.compactMap { window in
            guard rules.contains(where: { $0.matches(window: window) }) else {
                return nil
            }
            return outsetRect(window.frame, on: display, margin: overCoverMargin)
        }
    }

    static func clearRectsFromPredictions(
        for display: OverlayDisplay,
        predictions: [PredictedRect]
    ) -> [NSRect] {
        predictions.compactMap { predicted in
            outsetRect(predicted.frame, on: display, margin: predicted.margin)
        }
    }

    static func clearRectsByDisplay(
        displays: [OverlayDisplay],
        windows: [PassthroughWindowSnapshot],
        rules: [PassthroughApp]
    ) -> [PassthroughDisplayRects] {
        displays.map { display in
            PassthroughDisplayRects(
                displayFrame: display.frame,
                clearRects: clearRects(for: display, windows: windows, rules: rules)
            )
        }
    }

    static func clearRectsByDisplayFromPredictions(
        displays: [OverlayDisplay],
        predictions: [PredictedRect]
    ) -> [PassthroughDisplayRects] {
        displays.map { display in
            PassthroughDisplayRects(
                displayFrame: display.frame,
                clearRects: clearRectsFromPredictions(for: display, predictions: predictions)
            )
        }
    }

    private static func outsetRect(_ frame: NSRect, on display: OverlayDisplay, margin: CGFloat) -> NSRect? {
        let intersection = display.frame.intersection(frame)
        guard !intersection.isNull, !intersection.isEmpty else {
            return nil
        }

        let localRect = NSRect(
            x: intersection.minX - display.frame.minX,
            y: intersection.minY - display.frame.minY,
            width: intersection.width,
            height: intersection.height
        )

        let m = margin
        let outsetX = localRect.minX - m
        let outsetY = localRect.minY - m
        let outsetW = localRect.width + 2 * m
        let outsetH = localRect.height + 2 * m

        let displayWidth = display.frame.width
        let displayHeight = display.frame.height
        let clampedX = max(outsetX, 0)
        let clampedY = max(outsetY, 0)
        let clampedMaxX = min(outsetX + outsetW, displayWidth)
        let clampedMaxY = min(outsetY + outsetH, displayHeight)

        return NSRect(
            x: clampedX,
            y: clampedY,
            width: clampedMaxX - clampedX,
            height: clampedMaxY - clampedY
        )
    }
}
