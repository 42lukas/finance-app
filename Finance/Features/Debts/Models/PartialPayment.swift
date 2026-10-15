//
//  PartialPayment.swift
//  Finance
//
//

import Foundation

struct PartialPayment: Codable, Identifiable {
    let id: UUID
    let amount: Double
    let timestamp: Date
    var note: String?

    init(id: UUID = UUID(), amount: Double, timestamp: Date = Date(), note: String? = nil) {
        self.id = id
        self.amount = amount
        self.timestamp = timestamp
        self.note = note
    }
}
