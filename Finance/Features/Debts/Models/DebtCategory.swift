//
//  DebtCategory.swift
//  Finance
//

import Foundation

enum DebtCategory: String, CaseIterable, Identifiable {
    case receivable = "bekomme ich"
    case payable = "schulde ich"

    var id: Self { self }

    var title: String {
        switch self {
        case .receivable:
            return "Ich bekomme"
        case .payable:
            return "Ich schulde"
        }
    }

    mutating func toggle() {
        self = self == .receivable ? .payable : .receivable
    }

    static func title(for storedValue: String?) -> String {
        guard let storedValue, let category = DebtCategory(rawValue: storedValue) else {
            return "Kategorie"
        }
        return category.title
    }
}
