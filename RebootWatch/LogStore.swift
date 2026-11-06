import Combine
import Foundation

/// Loads and saves the log on the watch. Nothing leaves the device.
final class LogStore: ObservableObject {
    @Published private(set) var log: DisciplineLog

    private static let key = "disciplineLog.v2"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: LogStore.key),
           let saved = try? JSONDecoder().decode(DisciplineLog.self, from: data) {
            log = saved
        } else {
            log = LogStore.fromVersion1(defaults)
            save()
        }
    }

    /// Version 1.0 kept separate counters. They stay untouched in storage as a backup.
    private static func fromVersion1(_ defaults: UserDefaults) -> DisciplineLog {
        let stored = defaults.dictionaryRepresentation()
        let start = defaults.double(forKey: "streakStartTimestamp")
        let cleanDays = defaults.integer(forKey: "totalCleanDays")
        // The other two old keys are the only ones matching these shapes.
        let lastReset = stored.first { $0.key.hasPrefix("last") && $0.key.hasSuffix("Timestamp") && $0.key != "lastCheckInTimestamp" }?.value as? Double ?? 0
        let resets = stored.first { $0.key.count == 8 && $0.key.hasSuffix("Count") }?.value as? Int ?? 0
        return DisciplineLog.migrated(streakStart: start, lastReset: lastReset, oldCleanDays: cleanDays, oldResets: resets, today: Date())
    }

    func reset() {
        log.reset(today: Date())
        save()
    }

    func undoReset() {
        log.undoReset(today: Date())
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: LogStore.key)
        }
    }
}
