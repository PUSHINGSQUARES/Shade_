import Foundation

struct FrameTiming {
    private struct Sample {
        let presentationTime: TimeInterval
        let latencyMilliseconds: Double
    }

    private var samples: [Sample] = []

    var framesPerSecond: Double {
        Double(samples.count)
    }

    var averageLatencyMilliseconds: Double {
        guard !samples.isEmpty else { return 0 }
        let total = samples.reduce(0) { $0 + $1.latencyMilliseconds }
        return total / Double(samples.count)
    }

    mutating func recordFrame(presentationTime: TimeInterval, latencyMilliseconds: Double) {
        samples.append(Sample(presentationTime: presentationTime, latencyMilliseconds: latencyMilliseconds))
        let cutoff = presentationTime - 1.0
        samples.removeAll { $0.presentationTime < cutoff }
    }
}
