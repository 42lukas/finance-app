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

    private var totalAmount: Double {
        max(item.amount, 0)
    }

    private var payments: [PartialPayment] {
        guard let data = item.partialPaymentsData else { return [] }
        let decoded = (try? JSONDecoder().decode([PartialPayment].self, from: data)) ?? []
        return decoded.sorted { $0.timestamp > $1.timestamp }
    }

    private var paidAmount: Double {
        let historyPaid = payments.reduce(0) { $0 + max($1.amount, 0) }
        let effectivePaid = max(historyPaid, max(item.paidAmount, 0))
        return min(effectivePaid, totalAmount)
    }

    private var remainingAmount: Double {
        max(totalAmount - paidAmount, 0)
    }

    private var enteredPaymentAmount: Double? {
        let normalized = paymentAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(normalized)
    }

    private var canSavePayment: Bool {
        guard let amount = enteredPaymentAmount else { return false }
        return amount > 0 && remainingAmount > 0
    }

    var body: some View {
        ScrollView {
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
            TextField("Notiz (optional)", text: $editedNoteText)
            Button("Abbrechen", role: .cancel) {
                resetEditNote()
            }
            Button("Speichern") {
                saveEditedNote()
            }
        } message: {
            Text("Ergänze einen kurzen Kontext zu dieser Teilzahlung.")
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
                        Label(description, systemImage: "note.text")
                            .font(.subheadline)
                    }

                    Label(formattedDate(item.timestamp), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label(
                    item.category ?? "Kategorie",
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
                                editedNoteText = payment.note ?? ""
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
            Form {
                Section("Betrag") {
                    TextField("0,00 €", text: $paymentAmountText)
                        .keyboardType(.decimalPad)

                    Button("Restbetrag übernehmen") {
                        paymentAmountText = String(format: "%.2f", remainingAmount)
                    }
                    .foregroundStyle(AppPalette.emerald)

                    Text("Aktuell offen: \(currency(remainingAmount))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(AppPalette.surface)

                Section("Notiz (optional)") {
                    TextField("z. B. Überweisung oder Barzahlung", text: $paymentNoteText)
                }
                .listRowBackground(AppPalette.surface)
            }
            .scrollContentBackground(.hidden)
            .background(AppPalette.background)
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

    private func saveNewPayment() {
        guard let enteredAmount = enteredPaymentAmount, enteredAmount > 0, remainingAmount > 0 else { return }

        let normalizedNote = paymentNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payment = PartialPayment(
            amount: min(enteredAmount, remainingAmount),
            note: normalizedNote.isEmpty ? nil : normalizedNote
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

        let normalizedNote = editedNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedPayments[index].note = normalizedNote.isEmpty ? nil : normalizedNote
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
        let totalPaid = chronologicalPayments.reduce(0) { $0 + max($1.amount, 0) }

        item.paidAmount = min(totalPaid, totalAmount)
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
