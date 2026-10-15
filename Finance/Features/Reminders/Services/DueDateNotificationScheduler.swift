//
//  DueDateNotificationScheduler.swift
//  Finance
//

import CoreData
import Foundation
import UserNotifications

private struct DueReminderEntry: Sendable {
    let dueDate: Date
    let remainingAmount: Double
    let category: String
    let person: String
    let reason: String
}

private struct DueReminderPlan: Sendable {
    let identifier: String
    let fireDate: Date
    let dueDateKey: String
    let title: String
    let body: String
}

actor DueDateNotificationScheduler {
    static let shared = DueDateNotificationScheduler()

    static let identifierPrefix = "even.due."
    static let legacyIdentifier = "weeklyNotification"

    private let notificationCenter = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await notificationCenter.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await notificationCenter.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    func reschedule(requestAuthorization: Bool = false) async {
        await removeLegacyNotification()
        await removePendingDueDateNotifications()

        guard ReminderPreferences.notificationsEnabled else { return }

        let isAuthorized: Bool
        if requestAuthorization {
            isAuthorized = await requestAuthorizationIfNeeded()
        } else {
            let settings = await notificationCenter.notificationSettings()
            isAuthorized = Self.canSchedule(for: settings.authorizationStatus)
        }

        guard isAuthorized else { return }

        let entries = await fetchReminderEntries()
        let plans = makePlans(from: entries)

        // Keep headroom for other local notifications and prioritize the next reminders.
        for plan in plans.sorted(by: { $0.fireDate < $1.fireDate }).prefix(60) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            content.threadIdentifier = "\(Self.identifierPrefix)\(plan.dueDateKey)"
            content.userInfo = ["dueDate": plan.dueDateKey]

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: plan.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: plan.identifier,
                content: content,
                trigger: trigger
            )

            do {
                try await notificationCenter.add(request)
            } catch {
                print("Fälligkeitserinnerung konnte nicht geplant werden: \(error.localizedDescription)")
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationCenter.notificationSettings().authorizationStatus
    }

    private static func canSchedule(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func fetchReminderEntries() async -> [DueReminderEntry] {
        let container = PersistenceController.shared.container

        return await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                let request: NSFetchRequest<Item> = Item.fetchRequest()
                request.predicate = NSPredicate(format: "isArchived != YES AND dueDate != nil")

                do {
                    let entries = try context.fetch(request).compactMap { item -> DueReminderEntry? in
                        let remainingAmount = item.openAmount
                        guard let dueDate = item.dueDate, remainingAmount > 0.005 else { return nil }

                        let person = (item.person ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let reason = (item.descriptionText ?? "")
                            .trimmingCharacters(in: .whitespacesAndNewlines)

                        return DueReminderEntry(
                            dueDate: dueDate,
                            remainingAmount: remainingAmount,
                            category: item.category ?? "",
                            person: person.isEmpty ? "Unbekannt" : person,
                            reason: reason
                        )
                    }
                    continuation.resume(returning: entries)
                } catch {
                    print("Fälligkeitseinträge konnten nicht geladen werden: \(error.localizedDescription)")
                    continuation.resume(returning: [])
                }
            }
        }
    }

    private func makePlans(from entries: [DueReminderEntry], now: Date = Date()) -> [DueReminderPlan] {
        let calendar = Calendar.current
        let groupedEntries = Dictionary(grouping: entries) {
            calendar.startOfDay(for: $0.dueDate)
        }

        let hour = ReminderPreferences.timeMinutes / 60
        let minute = ReminderPreferences.timeMinutes % 60

        return groupedEntries.flatMap { dueDay, entriesForDay in
            ReminderPreferences.frequency.dayOffsets.compactMap { dayOffset in
                guard
                    let reminderDay = calendar.date(byAdding: .day, value: -dayOffset, to: dueDay),
                    let fireDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: reminderDay),
                    fireDate > now
                else {
                    return nil
                }

                let dueDateKey = Self.dateKey(for: dueDay, calendar: calendar)
                let identifier = "\(Self.identifierPrefix)\(dueDateKey).days-\(dayOffset)"
                let content = notificationContent(for: entriesForDay, dayOffset: dayOffset)

                return DueReminderPlan(
                    identifier: identifier,
                    fireDate: fireDate,
                    dueDateKey: dueDateKey,
                    title: content.title,
                    body: content.body
                )
            }
        }
    }

    private func notificationContent(
        for entries: [DueReminderEntry],
        dayOffset: Int
    ) -> (title: String, body: String) {
        let title: String
        switch dayOffset {
        case 0:
            title = "Heute fällig"
        case 1:
            title = "Morgen fällig"
        case 7:
            title = "In einer Woche fällig"
        case 14:
            title = "In zwei Wochen fällig"
        default:
            title = "In \(dayOffset) Tagen fällig"
        }

        guard let entry = entries.first, entries.count == 1 else {
            let total = entries.reduce(0) { $0 + $1.remainingAmount }
            return (
                title,
                "\(entries.count) offene Einträge über insgesamt \(currency(total)) werden fällig."
            )
        }

        let amountAndPerson: String
        if entry.category == "schulde ich" {
            amountAndPerson = "Du schuldest \(currency(entry.remainingAmount)) an \(entry.person)."
        } else {
            amountAndPerson = "Du bekommst \(currency(entry.remainingAmount)) von \(entry.person)."
        }

        guard !entry.reason.isEmpty else {
            return (title, amountAndPerson)
        }
        return (title, "\(amountAndPerson) Grund: \(entry.reason)")
    }

    private func removePendingDueDateNotifications() async {
        let requests = await pendingNotificationRequests()
        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(Self.identifierPrefix) }

        guard !identifiers.isEmpty else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func removeLegacyNotification() async {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [Self.legacyIdentifier])

        let delivered = await deliveredNotifications()
        let identifiers = delivered
            .map { $0.request.identifier }
            .filter { $0 == Self.legacyIdentifier }

        guard !identifiers.isEmpty else { return }
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func deliveredNotifications() async -> [UNNotification] {
        await withCheckedContinuation { continuation in
            notificationCenter.getDeliveredNotifications { notifications in
                continuation.resume(returning: notifications)
            }
        }
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private func currency(_ amount: Double) -> String {
        amount.formatted(
            .currency(code: "EUR")
                .precision(.fractionLength(2))
        )
    }
}
