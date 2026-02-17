//
//  FinanceBackupService.swift
//  Finance
//
//

import CoreData
import Foundation

enum FinanceBackupService {
    private static let schemaVersion: Int = 1

    static func makeBackupDocument(from items: [Item]) throws -> FinanceBackupDocument {
        let payload = FinanceBackupPayload(
            schemaVersion: schemaVersion,
            exportedAt: Date(),
            items: items.map(makeBackupEntry(from:))
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)
        return FinanceBackupDocument(data: data)
    }

    static func suggestedFileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "finance-backup-\(formatter.string(from: date)).json"
    }

    private static func makeBackupEntry(from item: Item) -> FinanceBackupEntry {
        FinanceBackupEntry(
            id: UUID(),
            timestamp: item.timestamp,
            amount: item.amount,
            category: item.category,
            person: item.person,
            descriptionText: item.descriptionText,
            isArchived: item.isArchived,
            paidAmount: item.paidAmount,
            partialPayments: decodePartialPayments(from: item.partialPaymentsData)
        )
    }

    private static func decodePartialPayments(from data: Data?) -> [FinanceBackupPartialPayment] {
        guard let data else {
            return []
        }

        do {
            return try JSONDecoder().decode([FinanceBackupPartialPayment].self, from: data)
        } catch {
            return []
        }
    }
}
