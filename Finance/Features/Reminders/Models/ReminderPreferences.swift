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

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            notificationsEnabledKey: true,
            frequencyKey: ReminderFrequency.threeTimes.rawValue,
            timeMinutesKey: defaultTimeMinutes
        ])
    }

    static var notificationsEnabled: Bool {
        UserDefaults.standard.bool(forKey: notificationsEnabledKey)
    }

    static var frequency: ReminderFrequency {
        ReminderFrequency(rawValue: UserDefaults.standard.integer(forKey: frequencyKey)) ?? .threeTimes
    }

    static var timeMinutes: Int {
        let storedValue = UserDefaults.standard.integer(forKey: timeMinutesKey)
        return min(max(storedValue, 0), (24 * 60) - 1)
    }
}
