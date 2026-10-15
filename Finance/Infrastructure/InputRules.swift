//
//  InputRules.swift
//  Finance
//

import Foundation
import SwiftUI

enum InputRules {
    static let personMaxLength = 20
    static let descriptionMaxLength = 30
    static let paymentNoteMaxLength = 30
    static let archiveSearchMaxLength = 30
    static let moneyInputMaxLength = 16

    static let minimumAmountCents: Int64 = 0
    static let maximumAmountCents: Int64 = 999_999_999

    static func truncated(_ value: String, to maximumLength: Int) -> String {
        guard value.count > maximumLength else { return value }
        return String(value.prefix(maximumLength))
    }

    static func normalizedPerson(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func normalizedOptionalText(_ value: String, maximumLength: Int) -> String? {
        let limited = truncated(value, to: maximumLength)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return limited.isEmpty ? nil : limited
    }

    static func cents(fromMoneyInput value: String) -> Int64? {
        let compact = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "€", with: "")
            .filter { !$0.isWhitespace }

        guard !compact.isEmpty else { return nil }
        guard !compact.contains(",") || !compact.contains(".") else { return nil }

        let separator: Character? = compact.contains(",") ? "," : (compact.contains(".") ? "." : nil)
        let parts: [Substring]
        if let separator {
            parts = compact.split(separator: separator, maxSplits: 1, omittingEmptySubsequences: false)
        } else {
            parts = [Substring(compact)]
        }

        guard parts.count <= 2 else { return nil }

        let integerPart = parts[0].isEmpty ? "0" : String(parts[0])
        let fractionalPart = parts.count == 2 ? String(parts[1]) : ""

        guard integerPart.allSatisfy(\.isNumber) else { return nil }
        guard fractionalPart.allSatisfy(\.isNumber), fractionalPart.count <= 2 else { return nil }

        let paddedFraction = fractionalPart.padding(toLength: 2, withPad: "0", startingAt: 0)
        guard let euros = Int64(integerPart), let cents = Int64(paddedFraction) else { return nil }
        guard euros <= maximumAmountCents / 100 else { return nil }

        let totalCents = euros * 100 + cents
        guard (minimumAmountCents...maximumAmountCents).contains(totalCents) else { return nil }
        return totalCents
    }

    static func storedCents(from amount: Double) -> Int64 {
        guard amount.isFinite, amount > 0 else { return 0 }
        let maximumSafeAmount = Double(Int64.max / 100)
        return Int64((min(amount, maximumSafeAmount) * 100).rounded())
    }

    static func amount(fromCents cents: Int64) -> Double {
        Double(cents) / 100
    }

    static func normalizedStoredAmount(_ amount: Double) -> Double {
        self.amount(fromCents: storedCents(from: amount))
    }

    static func editableMoneyText(for amount: Double, locale: Locale = .current) -> String {
        guard storedCents(from: amount) != 0 else { return "" }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: normalizedStoredAmount(amount) as NSNumber) ?? "0,00"
    }
}

extension View {
    func enforcingCharacterLimit(
        _ text: Binding<String>,
        maximumLength: Int
    ) -> some View {
        onChange(of: text.wrappedValue, initial: true) { _, newValue in
            let limitedValue = InputRules.truncated(newValue, to: maximumLength)
            guard limitedValue != newValue else { return }
            text.wrappedValue = limitedValue
        }
    }
}
