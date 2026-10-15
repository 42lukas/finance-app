//
//  DebtArchiveService.swift
//  Finance
//

import CoreData
import Foundation

enum DebtArchiveSource: String {
    case manual
    case widgetCompletion
}

enum DebtArchiveRestorationMode {
    case keepPayments
    case revertWidgetCompletion
}

enum DebtArchiveService {
    static func archive(
        _ item: Item,
        source: DebtArchiveSource,
        completionPaymentID: UUID? = nil,
        date: Date = Date()
    ) {
        item.isArchived = true
        item.archivedAt = date
        item.archiveSource = source.rawValue
        item.archiveCompletionPaymentID = source == .widgetCompletion ? completionPaymentID : nil
    }

    static func restore(
        _ item: Item,
        mode: DebtArchiveRestorationMode = .keepPayments
    ) throws {
        if mode == .revertWidgetCompletion {
            try removeWidgetCompletionPayment(from: item)
        }

        item.isArchived = false
        item.archivedAt = nil
        item.archiveSource = nil
        item.archiveCompletionPaymentID = nil
    }

    static func canRevertWidgetCompletion(for item: Item) -> Bool {
        guard
            item.archiveSource == DebtArchiveSource.widgetCompletion.rawValue,
            let completionPaymentID = item.archiveCompletionPaymentID
        else {
            return false
        }

        return item.decodedPartialPayments.contains { $0.id == completionPaymentID }
    }

    private static func removeWidgetCompletionPayment(from item: Item) throws {
        guard let completionPaymentID = item.archiveCompletionPaymentID else { return }

        var payments = item.decodedPartialPayments
        guard let completionPayment = payments.first(where: { $0.id == completionPaymentID }) else {
            return
        }

        payments.removeAll { $0.id == completionPaymentID }
        let historyPaid = payments.reduce(0) { $0 + max($1.amount, 0) }
        let paidBeforeWidgetCompletion = max(item.amount - completionPayment.amount, 0)

        item.partialPaymentsData = try JSONEncoder().encode(payments)
        item.paidAmount = min(
            max(historyPaid, paidBeforeWidgetCompletion),
            max(item.amount, 0)
        )
    }
}
