//
//  DebtEntryCreationService.swift
//  Finance
//
//

import Foundation
import CoreData

enum DebtEntryCategory: String {
    case iOwe = "schulde ich"
    case iGetBack = "bekomme ich"
}

enum DebtEntryCreationError: LocalizedError {
    case invalidAmount
    case emptyPerson

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Der Betrag muss größer als 0 Euro sein."
        case .emptyPerson:
            return "Bitte gib eine Person an."
        }
    }
}

struct DebtEntryCreationService {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer = PersistenceController.shared.container) {
        self.container = container
    }

    func createEntry(
        amount: Double,
        category: DebtEntryCategory,
        person: String,
        reason: String
    ) async throws {
        let roundedAmount = (amount * 100).rounded() / 100
        guard roundedAmount > 0 else {
            throw DebtEntryCreationError.invalidAmount
        }

        let trimmedPerson = person.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPerson.isEmpty else {
            throw DebtEntryCreationError.emptyPerson
        }

        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)

        let context = container.newBackgroundContext()
        try await context.perform {
            let item = Item(context: context)
            item.timestamp = Date()
            item.amount = roundedAmount
            item.isArchived = false
            item.paidAmount = 0
            item.partialPaymentsData = nil
            item.category = category.rawValue
            item.person = trimmedPerson
            item.descriptionText = trimmedReason.isEmpty ? nil : trimmedReason

            if context.hasChanges {
                try context.save()
            }
        }
    }
}
