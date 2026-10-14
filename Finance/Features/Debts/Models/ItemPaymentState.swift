//
//  ItemPaymentState.swift
//  Finance
//

import Foundation

extension Item {
    var decodedPartialPayments: [PartialPayment] {
        guard let partialPaymentsData else { return [] }
        return (try? JSONDecoder().decode([PartialPayment].self, from: partialPaymentsData)) ?? []
    }

    var effectivePaidAmount: Double {
        let historyPaid = decodedPartialPayments.reduce(0) { $0 + max($1.amount, 0) }
        return min(max(historyPaid, max(paidAmount, 0)), max(amount, 0))
    }

    var openAmount: Double {
        max(amount - effectivePaidAmount, 0)
    }
}
