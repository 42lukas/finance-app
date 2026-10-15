//
//  EvenOverviewWidget.swift
//  EvenWidget
//

import AppIntents
import CoreData
import SwiftUI
import UIKit
import UserNotifications
import WidgetKit

private enum EvenWidgetConstants {
    static let kind = "EvenOverviewWidget"
}

private enum WidgetPalette {
    static let background = dynamic(
        light: UIColor(red: 247 / 255, green: 238 / 255, blue: 214 / 255, alpha: 1),
        dark: UIColor(red: 7 / 255, green: 24 / 255, blue: 38 / 255, alpha: 1)
    )
    static let navy = dynamic(
        light: UIColor(red: 16 / 255, green: 43 / 255, blue: 67 / 255, alpha: 1),
        dark: UIColor(red: 169 / 255, green: 192 / 255, blue: 208 / 255, alpha: 1)
    )
    static let emerald = dynamic(
        light: UIColor(red: 8 / 255, green: 168 / 255, blue: 120 / 255, alpha: 1),
        dark: UIColor(red: 45 / 255, green: 214 / 255, blue: 163 / 255, alpha: 1)
    )
    static let ochre = dynamic(
        light: UIColor(red: 190 / 255, green: 132 / 255, blue: 32 / 255, alpha: 1),
        dark: UIColor(red: 224 / 255, green: 182 / 255, blue: 93 / 255, alpha: 1)
    )

    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

private struct WidgetDebt: Identifiable, Sendable {
    let id: UUID
    let person: String
    let reason: String
    let remainingAmount: Double
    let category: String
    let dueDate: Date

    var isOwedByMe: Bool { category == "schulde ich" }
}

private struct WidgetSnapshot: Sendable {
    let debtTotal: Double
    let receivableTotal: Double
    let dueItems: [WidgetDebt]
    let activeCount: Int
    let storeReady: Bool

    var balance: Double { receivableTotal - debtTotal }

    static let waiting = WidgetSnapshot(
        debtTotal: 0,
        receivableTotal: 0,
        dueItems: [],
        activeCount: 0,
        storeReady: false
    )

    static let sample = WidgetSnapshot(
        debtTotal: 250,
        receivableTotal: 375,
        dueItems: [
            WidgetDebt(
                id: UUID(),
                person: "Mama",
                reason: "Brillen",
                remainingAmount: 42.50,
                category: "schulde ich",
                dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            ),
            WidgetDebt(
                id: UUID(),
                person: "Max",
                reason: "Tickets",
                remainingAmount: 30,
                category: "bekomme ich",
                dueDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()) ?? Date()
            )
        ],
        activeCount: 4,
        storeReady: true
    )
}

private actor WidgetStore {
    static let shared = WidgetStore()

    private var loadedContainer: NSPersistentContainer?

    func snapshot() async -> WidgetSnapshot {
        guard EvenSharedStore.isReady else { return .waiting }

        do {
            let container = try await container()
            let context = container.newBackgroundContext()
            return try await context.perform {
                let request: NSFetchRequest<Item> = Item.fetchRequest()
                request.predicate = NSPredicate(format: "isArchived != YES")
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)]

                let items = try context.fetch(request).filter { $0.openAmount > 0.005 }
                let debtTotal = items
                    .filter { $0.category == "schulde ich" }
                    .reduce(0) { $0 + $1.openAmount }
                let receivableTotal = items
                    .filter { $0.category == "bekomme ich" }
                    .reduce(0) { $0 + $1.openAmount }

                let dueItems = items.compactMap { item -> WidgetDebt? in
                    guard let id = item.id, let dueDate = item.dueDate else { return nil }
                    let person = (item.person ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let reason = (item.descriptionText ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    return WidgetDebt(
                        id: id,
                        person: person.isEmpty ? "Ohne Person" : person,
                        reason: reason,
                        remainingAmount: item.openAmount,
                        category: item.category ?? "",
                        dueDate: dueDate
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.dueDate != rhs.dueDate {
                        return lhs.dueDate < rhs.dueDate
                    }
                    return lhs.person.localizedCaseInsensitiveCompare(rhs.person) == .orderedAscending
                }

                return WidgetSnapshot(
                    debtTotal: debtTotal,
                    receivableTotal: receivableTotal,
                    dueItems: dueItems,
                    activeCount: items.count,
                    storeReady: true
                )
            }
        } catch {
            return .waiting
        }
    }

    func complete(itemID: UUID) async throws {
        guard EvenSharedStore.isReady else { return }

        let container = try await container()
        let context = container.newBackgroundContext()
        context.transactionAuthor = "EvenWidget"

        try await context.perform {
            let request: NSFetchRequest<Item> = Item.fetchRequest()
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", itemID as CVarArg)

            guard let item = try context.fetch(request).first else { return }
            let remainingAmount = item.openAmount
            var completionPaymentID: UUID?

            if remainingAmount > 0.005 {
                var payments = item.decodedPartialPayments
                let completionPayment = PartialPayment(
                    amount: remainingAmount,
                    note: "Über Widget erledigt"
                )
                payments.append(completionPayment)
                completionPaymentID = completionPayment.id
                item.partialPaymentsData = try JSONEncoder().encode(payments)
                item.paidAmount = max(item.amount, 0)
            }

            DebtArchiveService.archive(
                item,
                source: .widgetCompletion,
                completionPaymentID: completionPaymentID
            )
            if context.hasChanges {
                try context.save()
            }
        }

        await rescheduleDueDateNotifications()
    }

    private func container() async throws -> NSPersistentContainer {
        if let loadedContainer {
            return loadedContainer
        }

        guard let storeURL = EvenSharedStore.storeURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        let container = NSPersistentContainer(name: "Finance")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        container.persistentStoreDescriptions = [description]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            container.loadPersistentStores { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        loadedContainer = container
        return container
    }

    private func rescheduleDueDateNotifications() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending
            .map(\.identifier)
            .filter { $0.hasPrefix("even.due.") }

        if !identifiers.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        let defaults = EvenSharedStore.sharedDefaults
        let notificationsEnabled = defaults.object(forKey: "reminders.notificationsEnabled") as? Bool ?? true
        guard notificationsEnabled else { return }

        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }

        do {
            let snapshot = await snapshot()
            let offsets: [Int]
            let frequency = defaults.object(forKey: "reminders.frequency") as? Int ?? 3
            switch frequency {
            case 1: offsets = [0]
            case 5: offsets = [14, 7, 3, 1, 0]
            default: offsets = [7, 3, 0]
            }

            let storedMinutes = defaults.object(forKey: "reminders.timeMinutes") as? Int ?? (18 * 60)
            let minutes = min(max(storedMinutes, 0), 1439)
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: snapshot.dueItems) {
                calendar.startOfDay(for: $0.dueDate)
            }

            var requests: [(Date, UNNotificationRequest)] = []
            for (dueDay, items) in grouped {
                for offset in offsets {
                    guard
                        let reminderDay = calendar.date(byAdding: .day, value: -offset, to: dueDay),
                        let fireDate = calendar.date(
                            bySettingHour: minutes / 60,
                            minute: minutes % 60,
                            second: 0,
                            of: reminderDay
                        ),
                        fireDate > Date()
                    else { continue }

                    let content = UNMutableNotificationContent()
                    content.title = "Even-Erinnerung"
                    content.body = "\(reminderTitle(for: offset)): \(reminderBody(for: items))"
                    content.sound = .default
                    content.categoryIdentifier = "even.due.reminder"

                    let dueKey = dateKey(for: dueDay, calendar: calendar)
                    content.threadIdentifier = "even.due.\(dueKey)"
                    content.userInfo = ["dueDate": dueKey]

                    let components = calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: fireDate
                    )
                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let request = UNNotificationRequest(
                        identifier: "even.due.\(dueKey).days-\(offset)",
                        content: content,
                        trigger: trigger
                    )
                    requests.append((fireDate, request))
                }
            }

            for (_, request) in requests.sorted(by: { $0.0 < $1.0 }).prefix(60) {
                try await center.add(request)
            }
        } catch {
            // The widget action is already complete; the app reschedules again on next activation.
        }
    }

    private func reminderTitle(for offset: Int) -> String {
        switch offset {
        case 0: return "Heute fällig"
        case 1: return "Morgen fällig"
        case 7: return "In einer Woche fällig"
        case 14: return "In zwei Wochen fällig"
        default: return "In \(offset) Tagen fällig"
        }
    }

    private func reminderBody(for items: [WidgetDebt]) -> String {
        guard let item = items.first, items.count == 1 else {
            let total = items.reduce(0) { $0 + $1.remainingAmount }
            return "\(items.count) offene Einträge über insgesamt \(currency(total)) werden fällig."
        }

        let statement = item.isOwedByMe
            ? "Du schuldest \(currency(item.remainingAmount)) an \(item.person)."
            : "Du bekommst \(currency(item.remainingAmount)) von \(item.person)."
        return item.reason.isEmpty ? statement : "\(statement) Grund: \(item.reason)"
    }

    private func dateKey(for date: Date, calendar: Calendar) -> String {
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

private struct EvenTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct EvenTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> EvenTimelineEntry {
        EvenTimelineEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (EvenTimelineEntry) -> Void) {
        guard !context.isPreview else {
            completion(placeholder(in: context))
            return
        }

        Task {
            let snapshot = await WidgetStore.shared.snapshot()
            completion(EvenTimelineEntry(date: Date(), snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<EvenTimelineEntry>) -> Void) {
        Task {
            let snapshot = await WidgetStore.shared.snapshot()
            let entry = EvenTimelineEntry(date: Date(), snapshot: snapshot)
            let calendar = Calendar.current
            let nextMidnight = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: Date())
            ) ?? Date().addingTimeInterval(3600)

            completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
        }
    }
}

struct CompleteDebtIntent: AppIntent {
    static var title: LocalizedStringResource = "Eintrag erledigen"
    static var description = IntentDescription("Bezahlt den offenen Restbetrag und archiviert den Eintrag.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Eintrag")
    var itemID: String

    init() {
        itemID = ""
    }

    init(itemID: UUID) {
        self.itemID = itemID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: itemID) else { return .result() }
        try await WidgetStore.shared.complete(itemID: id)
        WidgetCenter.shared.reloadTimelines(ofKind: EvenWidgetConstants.kind)
        return .result()
    }
}

struct EvenOverviewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: EvenWidgetConstants.kind,
            provider: EvenTimelineProvider()
        ) { entry in
            EvenWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.background
                }
        }
        .configurationDisplayName("Even Überblick")
        .description("Zeigt deinen Saldo, die nächste Fälligkeit und offene Einträge.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct EvenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: EvenTimelineEntry

    var body: some View {
        if !entry.snapshot.storeReady {
            waitingView
        } else {
            switch family {
            case .systemSmall:
                smallView
            default:
                mediumView
            }
        }
    }

    private var waitingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Even", systemImage: "equal.circle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(WidgetPalette.emerald)
                .widgetAccentable()

            Spacer()

            Text("Even einmal öffnen")
                .font(.headline)
                .foregroundStyle(WidgetPalette.navy)
            Text("Danach erscheinen deine aktuellen Einträge hier.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetHeader(compact: true)

            Spacer(minLength: 0)

            if let item = entry.snapshot.dueItems.first {
                Text("Nächste Fälligkeit")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.person)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                        Text(item.remainingAmount, format: .currency(code: "EUR"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.isOwedByMe ? WidgetPalette.navy : WidgetPalette.emerald)
                    }

                    Spacer(minLength: 2)
                    completeButton(for: item)
                }

                dueLabel(for: item)
            } else {
                Label("Keine Fälligkeit", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(WidgetPalette.emerald)
                Text(entry.snapshot.activeCount == 0 ? "Alles erledigt" : "Keine Termine gesetzt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                widgetHeader(compact: false)
                Spacer(minLength: 0)
                totalLine(title: "Schulde ich", value: entry.snapshot.debtTotal, color: WidgetPalette.navy)
                totalLine(title: "Ich bekomme", value: entry.snapshot.receivableTotal, color: WidgetPalette.emerald)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .overlay(WidgetPalette.navy.opacity(0.14))

            VStack(alignment: .leading, spacing: 8) {
                Text("Nächste Fälligkeit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let item = entry.snapshot.dueItems.first {
                    Spacer(minLength: 0)
                    HStack(spacing: 6) {
                        Text(item.person)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        completeButton(for: item)
                    }
                    if !item.reason.isEmpty {
                        Text(item.reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Text(item.remainingAmount, format: .currency(code: "EUR"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(item.isOwedByMe ? WidgetPalette.navy : WidgetPalette.emerald)
                    dueLabel(for: item)
                } else {
                    Spacer()
                    Label("Keine Fälligkeit", systemImage: "calendar.badge.checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WidgetPalette.emerald)
                    Text(entry.snapshot.activeCount == 0 ? "Alles erledigt" : "Keine Termine gesetzt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func widgetHeader(compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Label("Even", systemImage: "equal.circle.fill")
                .font((compact ? Font.subheadline : Font.headline).weight(.bold))
                .foregroundStyle(WidgetPalette.emerald)
                .widgetAccentable()

            Spacer(minLength: 4)

            Text(entry.snapshot.balance, format: .currency(code: "EUR").precision(.fractionLength(0...2)))
                .font((compact ? Font.subheadline : Font.title3).weight(.bold))
                .foregroundStyle(entry.snapshot.balance >= 0 ? WidgetPalette.emerald : WidgetPalette.navy)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
    }

    private func totalLine(title: String, value: Double, color: Color) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value, format: .currency(code: "EUR").precision(.fractionLength(0...2)))
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }

    private func dueLabel(for item: WidgetDebt) -> some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: entry.date)
        let dueDay = calendar.startOfDay(for: item.dueDate)
        let days = calendar.dateComponents([.day], from: today, to: dueDay).day ?? 0
        let text: String

        switch days {
        case ..<0:
            text = days == -1 ? "1 Tag überfällig" : "\(abs(days)) Tage überfällig"
        case 0:
            text = "Heute fällig"
        case 1:
            text = "Morgen fällig"
        default:
            text = item.dueDate.formatted(.dateTime.day().month(.abbreviated))
        }

        return Text(text)
            .font(.caption2.weight(days <= 0 ? .semibold : .regular))
            .foregroundStyle(days <= 0 ? WidgetPalette.ochre : Color.secondary)
            .lineLimit(1)
    }

    private func completeButton(for item: WidgetDebt) -> some View {
        Button(intent: CompleteDebtIntent(itemID: item.id)) {
            Image(systemName: "checkmark.circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(WidgetPalette.emerald)
                .frame(width: 30, height: 30)
                .contentShape(Circle())
                .widgetAccentable()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.person) als erledigt markieren")
    }
}

private extension UNUserNotificationCenter {
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}
