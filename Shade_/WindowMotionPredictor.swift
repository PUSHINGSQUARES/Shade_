import Foundation

struct WindowIdentity: Hashable {
    let bundleIdentifier: String
    let windowIndex: Int
}

struct TrackedWindow {
    let identity: WindowIdentity
    var position: CGPoint
    var size: CGSize
    var velocity: CGPoint
    var speed: CGFloat
    var timestamp: Double
}

struct PredictedRect {
    let frame: NSRect
    let margin: CGFloat
}

struct MotionPredictionConfig {
    var leadTimeSeconds: Double
    var restMargin: CGFloat
    var motionMargin: CGFloat

    static let `default` = MotionPredictionConfig(
        leadTimeSeconds: 0.016,
        restMargin: 3.0,
        motionMargin: 12.0
    )
}

@MainActor
final class WindowMotionPredictor {
    private var tracked: [WindowIdentity: TrackedWindow] = [:]
    private static let velocityDecay: CGFloat = 0.7
    private static let speedThreshold: CGFloat = 2.0

    func update(
        windows: [PassthroughWindowSnapshot],
        rules: [PassthroughApp],
        timestamp: Double,
        config: MotionPredictionConfig
    ) -> [PredictedRect] {
        let matched = windows.filter { window in
            rules.contains { $0.matches(window: window) }
        }

        var usedIdentities = Set<WindowIdentity>()
        var results: [PredictedRect] = []

        let windowsByBundle = Dictionary(grouping: matched) { $0.bundleIdentifier ?? "" }

        for (bundleID, bundleWindows) in windowsByBundle {
            guard !bundleID.isEmpty else { continue }

            let sorted = bundleWindows.sorted { a, b in
                a.frame.origin.x < b.frame.origin.x || (a.frame.origin.x == b.frame.origin.x && a.frame.origin.y < b.frame.origin.y)
            }

            for (index, window) in sorted.enumerated() {
                let identity = matchIdentity(
                    bundleID: bundleID,
                    position: window.frame.origin,
                    size: window.frame.size,
                    candidateIndex: index,
                    usedIdentities: usedIdentities
                )
                usedIdentities.insert(identity)

                let currentPos = window.frame.origin
                let currentSize = window.frame.size

                if let prev = tracked[identity] {
                    let dt = timestamp - prev.timestamp
                    guard dt > 0 else {
                        results.append(predict(window: prev, config: config))
                        continue
                    }

                    let rawVx = (currentPos.x - prev.position.x) / dt
                    let rawVy = (currentPos.y - prev.position.y) / dt
                    let decay = Self.velocityDecay
                    let vx = rawVx * (1 - decay) + prev.velocity.x * decay
                    let vy = rawVy * (1 - decay) + prev.velocity.y * decay
                    let speed = sqrt(vx * vx + vy * vy)

                    var updated = TrackedWindow(
                        identity: identity,
                        position: currentPos,
                        size: currentSize,
                        velocity: CGPoint(x: vx, y: vy),
                        speed: speed,
                        timestamp: timestamp
                    )

                    if speed < Self.speedThreshold {
                        updated.velocity = .zero
                        updated.speed = 0
                    }

                    tracked[identity] = updated
                    results.append(predict(window: updated, config: config))
                } else {
                    let newTracked = TrackedWindow(
                        identity: identity,
                        position: currentPos,
                        size: currentSize,
                        velocity: .zero,
                        speed: 0,
                        timestamp: timestamp
                    )
                    tracked[identity] = newTracked
                    results.append(predict(window: newTracked, config: config))
                }
            }
        }

        let staleKeys = tracked.keys.filter { !usedIdentities.contains($0) }
        for key in staleKeys { tracked.removeValue(forKey: key) }

        return results
    }

    func reset() {
        tracked.removeAll()
    }

    private func matchIdentity(
        bundleID: String,
        position: CGPoint,
        size: CGSize,
        candidateIndex: Int,
        usedIdentities: Set<WindowIdentity>
    ) -> WindowIdentity {
        var bestIdentity: WindowIdentity?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for (identity, prev) in tracked where identity.bundleIdentifier == bundleID {
            guard !usedIdentities.contains(identity) else { continue }
            let dx = position.x - prev.position.x
            let dy = position.y - prev.position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < bestDistance {
                bestDistance = dist
                bestIdentity = identity
            }
        }

        if let best = bestIdentity, bestDistance < 500 {
            return best
        }

        var index = candidateIndex
        while usedIdentities.contains(WindowIdentity(bundleIdentifier: bundleID, windowIndex: index)) {
            index += 1
        }
        return WindowIdentity(bundleIdentifier: bundleID, windowIndex: index)
    }

    private func predict(window: TrackedWindow, config: MotionPredictionConfig) -> PredictedRect {
        let leadTime = config.leadTimeSeconds
        let predictedX = window.position.x + window.velocity.x * leadTime
        let predictedY = window.position.y + window.velocity.y * leadTime

        let maxSpeed: CGFloat = 3000
        let t = min(window.speed / maxSpeed, 1.0)
        let margin = config.restMargin + (config.motionMargin - config.restMargin) * t

        let currentRect = NSRect(origin: window.position, size: window.size)
        let predictedRect = NSRect(x: predictedX, y: predictedY, width: window.size.width, height: window.size.height)
        let unionRect = currentRect.union(predictedRect)

        return PredictedRect(
            frame: unionRect,
            margin: margin
        )
    }
}
