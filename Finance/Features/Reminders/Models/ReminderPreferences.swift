//
//  ReminderPreferences.swift
//  Finance
//

import Foundation

enum ReminderFrequency: Int, CaseIterable, Identifiable {
    case once = 1
    case threeTimes = 3
    case fiveTimes = 5

    var id: Int { rawValue }

    var dayOffsets: [Int] {
        switch self {
        case .once:
            return [0]
        case .threeTimes:
            return [7, 3, 0]
        case .fiveTimes:
            return [14, 7, 3, 1, 0]
        }
    }

    var explanation: String {
        switch self {
        case .once:
            return "Am Fälligkeitstag"
        case .threeTimes:
            return "7 Tage vorher, 3 Tage vorher und am Fälligkeitstag"
        case .fiveTimes:
            return "14, 7, 3 und 1 Tag vorher sowie am Fälligkeitstag"
        }
    }
}

enum ReminderPreferences {
    static let notificationsEnabledKey = "reminders.notificationsEnabled"
    static let frequencyKey = "reminders.frequency"
    static let timeMinutesKey = "reminders.timeMinutes"

    static let defaultTimeMinutes = 18 * 60
    private static let migrationKey = "reminders.sharedDefaultsMigrated"

    static var storage: UserDefaults {
        EvenSharedStore.sharedDefaults
    }

    static func registerDefaults() {
        storage.register(defaults: [
            notificationsEnabledKey: true,
            frequencyKey: ReminderFrequency.threeTimes.rawValue,
            timeMinutesKey: defaultTimeMinutes
        ])

        guard !storage.bool(forKey: migrationKey) else { return }

        let legacyDefaults = UserDefaults.standard
        for key in [notificationsEnabledKey, frequencyKey, timeMinutesKey] {
            if let value = legacyDefaults.object(forKey: key) {
                storage.set(value, forKey: key)
            }
        }
        storage.set(true, forKey: migrationKey)
    }

    static var notificationsEnabled: Bool {
        storage.bool(forKey: notificationsEnabledKey)
    }

    static var frequency: ReminderFrequency {
        ReminderFrequency(rawValue: storage.integer(forKey: frequencyKey)) ?? .threeTimes
    }

    static var timeMinutes: Int {
        let storedValue = storage.integer(forKey: timeMinutesKey)
        return min(max(storedValue, 0), (24 * 60) - 1)
    }
}
