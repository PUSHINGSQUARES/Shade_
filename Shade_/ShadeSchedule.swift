import Foundation

struct ShadeClockTime: Codable, Equatable, Comparable {
    let hour: Int
    let minute: Int

    var storageString: String {
        String(format: "%02d:%02d", hour, minute)
    }

    private var minutesAfterMidnight: Int {
        hour * 60 + minute
    }

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        self.hour = hour
        self.minute = minute
    }

    init?(storageString: String) {
        guard storageString.count == 5,
              storageString[storageString.index(storageString.startIndex, offsetBy: 2)] == ":" else {
            return nil
        }

        let parts = storageString.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              parts[0].count == 2,
              parts[1].count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }

        self.init(hour: hour, minute: minute)
    }

    init(date: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.hour = components.hour ?? 0
        self.minute = components.minute ?? 0
    }

    func adding(minutes: Int) -> ShadeClockTime {
        let total = ((hour * 60 + minute) + minutes) % (24 * 60)
        let normalized = (total + 24 * 60) % (24 * 60)
        return ShadeClockTime(hour: normalized / 60, minute: normalized % 60)!
    }

    static func < (lhs: ShadeClockTime, rhs: ShadeClockTime) -> Bool {
        lhs.minutesAfterMidnight < rhs.minutesAfterMidnight
    }
}

enum ScheduleSource: String, Codable {
    case manualTimes
    case sunsetToSunrise
}

struct ScheduleLocation: Codable, Equatable {
    var label: String
    var latitude: Double
    var longitude: Double
}

struct ShadeSchedule: Codable, Equatable {
    var isEnabled: Bool
    var startTime: ShadeClockTime
    var endTime: ShadeClockTime
    var source: ScheduleSource
    var sunLocation: ScheduleLocation?
    var sunOffsetMinutes: Int

    init(
        isEnabled: Bool,
        startTime: ShadeClockTime,
        endTime: ShadeClockTime,
        source: ScheduleSource = .manualTimes,
        sunLocation: ScheduleLocation? = nil,
        sunOffsetMinutes: Int = 0
    ) {
        self.isEnabled = isEnabled
        self.startTime = startTime
        self.endTime = endTime
        self.source = source
        self.sunLocation = sunLocation
        self.sunOffsetMinutes = max(-120, min(120, sunOffsetMinutes))
    }
}

enum ShadeScheduleEvaluator {
    static func shouldEnable(
        schedule: ShadeSchedule,
        at date: Date,
        calendar: Calendar = .current,
        solar: SolarEventsProvider = SolarCalculator.events
    ) -> Bool {
        guard schedule.isEnabled,
              let times = ShadeScheduleResolver.effectiveTimes(
                schedule: schedule, at: date, calendar: calendar, solar: solar
              ),
              times.start != times.end,
              let currentTime = ShadeClockTime(
                hour: calendar.component(.hour, from: date),
                minute: calendar.component(.minute, from: date)
              ) else {
            return false
        }

        return isWithin(currentTime, start: times.start, end: times.end)
    }

    private static func isWithin(
        _ now: ShadeClockTime,
        start: ShadeClockTime,
        end: ShadeClockTime
    ) -> Bool {
        if start < end {
            return now >= start && now < end
        }

        return now >= start || now < end
    }
}

@MainActor
final class ShadeScheduleTicker {
    typealias ScheduleProvider = () -> ShadeSchedule
    typealias ApplySchedule = (Date) -> Void
    typealias DateProvider = () -> Date

    private let interval: TimeInterval
    private let scheduleProvider: ScheduleProvider
    private let applySchedule: ApplySchedule
    private let dateProvider: DateProvider
    private var timer: Timer?

    init(
        interval: TimeInterval = 60,
        scheduleProvider: @escaping ScheduleProvider,
        apply: @escaping ApplySchedule,
        dateProvider: @escaping DateProvider = Date.init
    ) {
        self.interval = interval
        self.scheduleProvider = scheduleProvider
        self.applySchedule = apply
        self.dateProvider = dateProvider
    }

    var isRunning: Bool {
        timer != nil
    }

    func start() {
        stop()
        fireNow()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fireNow()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func fireNow() {
        guard scheduleProvider().isEnabled else {
            return
        }

        applySchedule(dateProvider())
    }
}
