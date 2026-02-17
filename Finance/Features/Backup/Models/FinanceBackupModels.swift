//
//  FinanceBackupModels.swift
//  Finance
//
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct FinanceBackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let items: [FinanceBackupEntry]
}

struct FinanceBackupEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date?
    let amount: Double
    let category: String?
    let person: String?
    let descriptionText: String?
    let isArchived: Bool
    let paidAmount: Double
    let partialPayments: [FinanceBackupPartialPayment]
}

struct FinanceBackupPartialPayment: Codable {
    let id: UUID
    let amount: Double
    let timestamp: Date
}

struct FinanceBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
