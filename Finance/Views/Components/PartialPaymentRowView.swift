//
//  PartialPaymentRowView.swift
//  Finance
//
//

import SwiftUI

struct PartialPaymentRowView: View {
    let payment: PartialPayment
    let dateText: String
    let onEditNote: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(String(format: "%.2f", payment.amount))€", systemImage: "eurosign.circle")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: onEditNote) {
                    Image(systemName: payment.note?.isEmpty == false ? "note.text" : "square.and.pencil")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(payment.note?.isEmpty == false ? .blue : .secondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }

            if let note = payment.note, !note.isEmpty {
                Label(note, systemImage: "text.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
