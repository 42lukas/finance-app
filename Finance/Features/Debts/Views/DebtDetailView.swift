//
//  DebtDetailView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct DebtDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var item: Item

    @State private var showAddPaymentSheet = false
    @State private var paymentAmountText = ""
    @State private var paymentNoteText = ""
    @State private var paymentToEdit: PartialPayment?
    @State private var editedNoteText = ""
    @State private var paymentToDelete: PartialPayment?

    private var totalAmountCents: Int64 {
        InputRules.storedCents(from: item.amount)
    }

    private var totalAmount: Double {
        InputRules.amount(fromCents: totalAmountCents)
    }

    private var payments: [PartialPayment] {
        guard let data = item.partialPaymentsData else { return [] }
        let decoded = (try? JSONDecoder().decode([PartialPayment].self, from: data)) ?? []
        return decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private var paidAmountCents: Int64 {
        let historyPaid = payments.reduce(Int64.zero) {
            $0 + InputRules.storedCents(from: $1.amount)
        }
        let effectivePaid = max(historyPaid, InputRules.storedCents(from: item.paidAmount))
        return min(effectivePaid, totalAmountCents)
    }

    private var paidAmount: Double {
        InputRules.amount(fromCents: paidAmountCents)
    }

    private var remainingAmountCents: Int64 {
        max(totalAmountCents - paidAmountCents, 0)
    }

    private var remainingAmount: Double {
        InputRules.amount(fromCents: remainingAmountCents)
    }

    private var enteredPaymentCents: Int64? {
        InputRules.cents(fromMoneyInput: paymentAmountText)
    }

    private var canSavePayment: Bool {
        guard let enteredPaymentCents else { return false }
        return remainingAmountCents > 0 && enteredPaymentCents <= remainingAmountCents
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                overviewCard
                paymentsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .navigationTitle(item.person?.isEmpty == false ? item.person! : "Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddPaymentSheet, onDismiss: resetNewPayment) {
            addPaymentSheet
        }
        .alert("Notiz bearbeiten", isPresented: editNoteAlertBinding()) {
            TextField(
                "Notiz (optional)",
                text: $editedNoteText
            )
            .enforcingCharacterLimit(
                $editedNoteText,
                maximumLength: InputRules.paymentNoteMaxLength
            )
            Button("Abbrechen", role: .cancel) {
                resetEditNote()
            }
            Button("Speichern") {
                saveEditedNote()
            }
        }
        .alert("Teilzahlung löschen?", isPresented: deletePaymentAlertBinding()) {
            Button("Abbrechen", role: .cancel) {
                paymentToDelete = nil
            }
            Button("Löschen", role: .destructive) {
                deleteSelectedPayment()
            }
        } message: {
            Text("Der bezahlte und offene Betrag werden anschließend neu berechnet.")
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    if let description = item.descriptionText, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                    }

                    Text(formattedDate(item.timestamp))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let dueDate = item.dueDate {
                        DueDateLabel(dueDate: dueDate, isCompleted: remainingAmount <= 0)
                    }
                }

                Spacer()

                Label(
                    DebtCategory.title(for: item.category),
                    systemImage: item.category == "schulde ich" ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(item.category == "schulde ich" ? AppPalette.paleNavy : AppPalette.mint)
                .foregroundStyle(item.category == "schulde ich" ? AppPalette.navy : AppPalette.emerald)
                .clipShape(Capsule())
            }

            Text(totalAmount, format: .currency(code: "EUR"))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.navy)
                .contentTransition(.numericText(value: totalAmount))

            VStack(spacing: 9) {
                ProgressView(value: paidAmount, total: max(totalAmount, 1))
                    .tint(AppPalette.emerald)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Bereits bezahlt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(paidAmount, format: .currency(code: "EUR"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppPalette.emerald)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Offen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(remainingAmount, format: .currency(code: "EUR"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(remainingAmount <= 0 ? AppPalette.emerald : AppPalette.ochre)
                    }
                }
            }

            if remainingAmount > 0 {
                Button {
                    paymentAmountText = ""
                    paymentNoteText = ""
                    showAddPaymentSheet = true
                } label: {
                    Label("Teilzahlung hinzufügen", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppPalette.emerald)
                        .foregroundStyle(AppPalette.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Label("Komplett bezahlt", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppPalette.mint)
                    .foregroundStyle(AppPalette.emerald)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.surface)
        )
    }

    private var paymentsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Teilzahlungen", systemImage: "list.bullet.rectangle.portrait")
                    .font(.headline)
                Spacer()
                Text("\(payments.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if payments.isEmpty {
                Label("Noch keine Teilzahlungen vorhanden.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(payments.enumerated()), id: \.element.id) { index, payment in
                        PartialPaymentRowView(
                            payment: payment,
                            dateText: formattedDate(payment.timestamp),
                            onEditNote: {
                                paymentToEdit = payment
                                editedNoteText = InputRules.truncated(
                                    payment.note ?? "",
                                    to: InputRules.paymentNoteMaxLength
                                )
                            },
                            onDelete: {
                                paymentToDelete = payment
                            }
                        )

                        if index < payments.count - 1 {
                            Divider()
                                .overlay(AppPalette.navy.opacity(0.10))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppPalette.surface)
        )
    }

    private var addPaymentSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Betrag")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(
                            "0,00 €",
                            text: $paymentAmountText
                        )
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(AppPalette.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .enforcingCharacterLimit(
                            $paymentAmountText,
                            maximumLength: InputRules.moneyInputMaxLength
                        )

                        Button("Restbetrag übernehmen") {
                            paymentAmountText = InputRules.editableMoneyText(for: remainingAmount)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.emerald)
                        .buttonStyle(.plain)

                        Text("Aktuell offen: \(currency(remainingAmount))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notiz (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        TextField(
                            "z. B. Überweisung oder Barzahlung",
                            text: $paymentNoteText
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(AppPalette.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .enforcingCharacterLimit(
                            $paymentNoteText,
                            maximumLength: InputRules.paymentNoteMaxLength
                        )

                        characterCounter(paymentNoteText, maximumLength: InputRules.paymentNoteMaxLength)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppPalette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Teilzahlung hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        showAddPaymentSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveNewPayment()
                    }
                    .disabled(!canSavePayment)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func characterCounter(_ text: String, maximumLength: Int) -> some View {
        Text("\(text.count)/\(maximumLength)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func saveNewPayment() {
        guard
            let enteredPaymentCents,
            remainingAmountCents > 0,
            enteredPaymentCents <= remainingAmountCents
        else { return }

        let payment = PartialPayment(
            amount: InputRules.amount(fromCents: enteredPaymentCents),
            note: InputRules.normalizedOptionalText(
                paymentNoteText,
                maximumLength: InputRules.paymentNoteMaxLength
            )
        )

        var updatedPayments = payments
        updatedPayments.append(payment)
        save(updatedPayments)
        showAddPaymentSheet = false
    }

    private func saveEditedNote() {
        guard let paymentToEdit else { return }

        var updatedPayments = payments
        guard let index = updatedPayments.firstIndex(where: { $0.id == paymentToEdit.id }) else {
            resetEditNote()
            return
        }

        updatedPayments[index].note = InputRules.normalizedOptionalText(
            editedNoteText,
            maximumLength: InputRules.paymentNoteMaxLength
        )
        save(updatedPayments)
        resetEditNote()
    }

    private func deleteSelectedPayment() {
        guard let paymentToDelete else { return }
        var updatedPayments = payments
        updatedPayments.removeAll { $0.id == paymentToDelete.id }
        save(updatedPayments)
        self.paymentToDelete = nil
    }

    private func save(_ updatedPayments: [PartialPayment]) {
        let chronologicalPayments = updatedPayments.sorted { $0.timestamp < $1.timestamp }
        let totalPaidCents = chronologicalPayments.reduce(Int64.zero) {
            $0 + InputRules.storedCents(from: $1.amount)
        }

        item.paidAmount = InputRules.amount(fromCents: min(totalPaidCents, totalAmountCents))
        item.partialPaymentsData = try? JSONEncoder().encode(chronologicalPayments)

        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    private func editNoteAlertBinding() -> Binding<Bool> {
        Binding {
            paymentToEdit != nil
        } set: { isPresented in
            if !isPresented {
                resetEditNote()
            }
        }
    }

    private func deletePaymentAlertBinding() -> Binding<Bool> {
        Binding {
            paymentToDelete != nil
        } set: { isPresented in
            if !isPresented {
                paymentToDelete = nil
            }
        }
    }

    private func resetNewPayment() {
        paymentAmountText = ""
        paymentNoteText = ""
    }

    private func resetEditNote() {
        paymentToEdit = nil
        editedNoteText = ""
    }

    private func formattedDate(_ date: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: date ?? Date())
    }

    private func currency(_ amount: Double) -> String {
        amount.formatted(.currency(code: "EUR"))
    }
}
