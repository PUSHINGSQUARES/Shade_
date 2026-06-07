import Foundation

enum ShadeScheduleResolver {
    static func effectiveTimes(
        schedule: ShadeSchedule,
        at date: Date,
        calendar: Calendar = .current,
        solar: SolarEventsProvider = SolarCalculator.events
    ) -> (start: ShadeClockTime, end: ShadeClockTime)? {
        switch schedule.source {
        case .manualTimes:
            return (schedule.startTime, schedule.endTime)
        case .sunsetToSunrise:
            guard let location = schedule.sunLocation,
                  let events = solar(location.latitude, location.longitude, date, calendar.timeZone) else {
                return nil
            }
            let sunset = ShadeClockTime(date: events.sunset, timeZone: calendar.timeZone)
            let sunrise = ShadeClockTime(date: events.sunrise, timeZone: calendar.timeZone)
            let offset = schedule.sunOffsetMinutes
            return (sunset.adding(minutes: offset), sunrise.adding(minutes: offset))
        }
    }
}
