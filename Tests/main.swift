// Logic tests for DisciplineLog. Plain swiftc, no Xcode needed:
//   swiftc RebootWatch/DisciplineLog.swift Tests/main.swift -o /tmp/logtests && /tmp/logtests
import Foundation

var failures = 0

func expect<T: Equatable>(_ actual: T, _ expected: T, _ name: String, line: Int = #line) {
    if actual != expected {
        failures += 1
        print("FAIL line \(line) \(name): got \(actual), expected \(expected)")
    }
}

var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "America/New_York")!   // has daylight saving changes

func day(_ offset: Int) -> Date {
    let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!   // clocks change on March 8
    return calendar.date(byAdding: .day, value: offset, to: start)!
}

// First day counts, later days fill in without opening the app
var log = DisciplineLog(firstDay: day(0))
expect(log.streak(today: day(0), calendar), 1, "first day")
expect(log.streak(today: day(29), calendar), 30, "across daylight saving")
expect(log.cleanDays(today: day(29), calendar), 30, "clean across daylight saving")
expect(log.bestStreak(today: day(29), calendar), 30, "best without resets")

// A reset zeroes today; tomorrow is day 1; the total only loses that one day
log.reset(today: day(10), calendar)
expect(log.streak(today: day(10), calendar), 0, "reset day")
expect(log.streak(today: day(11), calendar), 1, "day after reset")
expect(log.cleanDays(today: day(10), calendar), 10, "total on reset day")
expect(log.cleanDays(today: day(12), calendar), 12, "total keeps earlier days")
expect(log.bestStreak(today: day(12), calendar), 10, "best keeps earlier run")
expect(log.resetCount(), 1, "reset count")

// Same-day repeats count once, and undo restores everything
log.reset(today: day(10).addingTimeInterval(3600), calendar)
expect(log.resetCount(), 1, "second reset same day")
log.undoReset(today: day(10), calendar)
expect(log.resetCount(), 0, "undo")
expect(log.streak(today: day(10), calendar), 11, "streak after undo")

// A longer later run becomes the best
log.reset(today: day(2), calendar)
expect(log.bestStreak(today: day(20), calendar), 18, "best is the later run")
expect(log.bestStreak(today: day(2), calendar), 2, "best on the reset day")

// Calendar statuses
expect(log.status(of: day(-1), today: day(5), calendar), .untracked, "before tracking")
expect(log.status(of: day(1), today: day(5), calendar), .clean, "clean day")
expect(log.status(of: day(2), today: day(5), calendar), .reset, "reset day status")
expect(log.status(of: day(6), today: day(5), calendar), .future, "future")
// A clock set backwards never shows a negative streak
expect(DisciplineLog(firstDay: day(5)).streak(today: day(1), calendar), 0, "clock moved back")

// Milestones
expect(DisciplineLog.progress(streak: 0).next, 3, "first milestone")
expect(DisciplineLog.progress(streak: 7).next, 14, "exactly on a milestone moves on")
expect(DisciplineLog.progress(streak: 10).fraction, 3.0 / 7.0, "progress")
expect(DisciplineLog.progress(streak: 400).next, 730, "past a year")

// Version 1.0 data: nothing shown before is lost
let oldStart = day(0).timeIntervalSince1970 + 3600
var m = DisciplineLog.migrated(streakStart: oldStart, lastReset: 0, oldCleanDays: 50, oldResets: 0, today: day(9), calendar)
expect(m.streak(today: day(9), calendar), 10, "migrated streak, no reset")
expect(m.cleanDays(today: day(9), calendar), 50, "migrated total kept")
expect(m.cleanDays(today: day(10), calendar), 51, "migrated total keeps growing")
m = DisciplineLog.migrated(streakStart: oldStart, lastReset: oldStart, oldCleanDays: 40, oldResets: 3, today: day(4), calendar)
expect(m.streak(today: day(4), calendar), 4, "migrated streak after a reset")
expect(m.cleanDays(today: day(4), calendar), 40, "migrated total with reset")
expect(m.resetCount(), 3, "migrated reset count")
m = DisciplineLog.migrated(streakStart: 0, lastReset: 0, oldCleanDays: 0, oldResets: 0, today: day(3), calendar)
expect(m.streak(today: day(3), calendar), 1, "fresh install")
// Old total lower than the days since it began (app unopened for a while): use the real days
m = DisciplineLog.migrated(streakStart: oldStart, lastReset: 0, oldCleanDays: 2, oldResets: 0, today: day(9), calendar)
expect(m.cleanDays(today: day(9), calendar), 10, "unopened days still count")

// Saved data round-trips
let saved = try! JSONEncoder().encode(log)
expect(try! JSONDecoder().decode(DisciplineLog.self, from: saved), log, "round trip")

print(failures == 0 ? "All logic tests passed." : "\(failures) logic test(s) failed.")
exit(failures == 0 ? 0 : 1)
