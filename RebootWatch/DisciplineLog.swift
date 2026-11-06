import Foundation

/// The whole record: when tracking began and which days were reset.
/// Everything shown on screen is worked out from this, so the numbers can't drift apart.
/// Every day counts as clean unless it was reset, including days the app wasn't opened.
struct DisciplineLog: Codable, Equatable {
    enum DayStatus: Equatable { case untracked, clean, reset, future }

    var firstDay: Date
    var resetDays: [Date] = []
    // Totals carried over from version 1.0, which kept counters but no day-by-day history.
    var earlierCleanDays = 0
    var earlierResets = 0

    static let milestones = [3, 7, 14, 30, 60, 90, 180, 365]

    init(firstDay: Date, resetDays: [Date] = [], earlierCleanDays: Int = 0, earlierResets: Int = 0) {
        self.firstDay = firstDay
        self.resetDays = resetDays
        self.earlierCleanDays = earlierCleanDays
        self.earlierResets = earlierResets
    }

    static func days(from: Date, to: Date, _ calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: from), to: calendar.startOfDay(for: to)).day ?? 0
    }

    private func resets(upTo today: Date, _ calendar: Calendar) -> [Date] {
        let end = calendar.startOfDay(for: today)
        return resetDays.filter { $0 <= end }.sorted()
    }

    func isReset(_ day: Date, _ calendar: Calendar) -> Bool {
        resetDays.contains(calendar.startOfDay(for: day))
    }

    /// Clean days in a row, ending today. 0 on the day of a reset, 1 the day after.
    func streak(today: Date, _ calendar: Calendar = .current) -> Int {
        if let last = resets(upTo: today, calendar).last {
            return max(0, DisciplineLog.days(from: last, to: today, calendar))
        }
        return max(0, DisciplineLog.days(from: firstDay, to: today, calendar) + 1)
    }

    func cleanDays(today: Date, _ calendar: Calendar = .current) -> Int {
        let tracked = max(0, DisciplineLog.days(from: firstDay, to: today, calendar) + 1)
        return earlierCleanDays + max(0, tracked - resets(upTo: today, calendar).filter { $0 >= firstDay }.count)
    }

    func resetCount() -> Int { earlierResets + resetDays.count }

    /// Longest run of clean days since tracking began.
    func bestStreak(today: Date, _ calendar: Calendar = .current) -> Int {
        var best = 0
        var runStart = firstDay
        for reset in resets(upTo: today, calendar) {
            best = max(best, DisciplineLog.days(from: runStart, to: reset, calendar))
            runStart = calendar.date(byAdding: .day, value: 1, to: reset) ?? reset
        }
        return max(best, DisciplineLog.days(from: runStart, to: today, calendar) + 1)
    }

    func status(of day: Date, today: Date, _ calendar: Calendar = .current) -> DayStatus {
        let d = calendar.startOfDay(for: day)
        if d > calendar.startOfDay(for: today) { return .future }
        if isReset(d, calendar) { return .reset }
        return d < calendar.startOfDay(for: firstDay) ? .untracked : .clean
    }

    /// The milestone being worked towards, and how far along it the streak is (0...1).
    static func progress(streak: Int) -> (next: Int, fraction: Double) {
        let next = milestones.first { $0 > streak } ?? (streak / 365 + 1) * 365
        let previous = milestones.last { $0 <= streak } ?? 0
        let from = streak >= 365 ? streak / 365 * 365 : previous
        return (next, Double(streak - from) / Double(next - from))
    }

    mutating func reset(today: Date, _ calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: today)
        if !resetDays.contains(day) {
            resetDays.append(day)
            resetDays.sort()
        }
    }

    /// Takes back a reset made by mistake. Only today's reset can be undone.
    mutating func undoReset(today: Date, _ calendar: Calendar = .current) {
        let day = calendar.startOfDay(for: today)
        resetDays.removeAll { $0 == day }
    }

    /// Builds the log from version 1.0's counters, keeping the total and reset count it showed.
    /// `streakStart` and `lastReset` are timestamps; 0 means never set.
    static func migrated(streakStart: Double, lastReset: Double, oldCleanDays: Int, oldResets: Int,
                         today: Date, _ calendar: Calendar = .current) -> DisciplineLog {
        let todayStart = calendar.startOfDay(for: today)
        var log: DisciplineLog
        if lastReset > 0 {
            let day = calendar.startOfDay(for: Date(timeIntervalSince1970: lastReset))
            log = DisciplineLog(firstDay: min(day, todayStart), resetDays: [min(day, todayStart)])
        } else if streakStart > 0 {
            log = DisciplineLog(firstDay: min(calendar.startOfDay(for: Date(timeIntervalSince1970: streakStart)), todayStart))
        } else {
            log = DisciplineLog(firstDay: todayStart)
        }
        log.earlierCleanDays = max(0, oldCleanDays - log.cleanDays(today: today, calendar))
        log.earlierResets = max(0, oldResets - log.resetDays.count)
        return log
    }
}
