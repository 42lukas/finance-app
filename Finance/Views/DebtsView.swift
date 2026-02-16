//
//  DebtsView.swift
//  Finance
//
//

import SwiftUI
import CoreData

private struct PartialPayment: Codable, Identifiable {
    let id: UUID
    let amount: Double
    let timestamp: Date

    init(id: UUID = UUID(), amount: Double, timestamp: Date = Date()) {
        self.id = id
        self.amount = amount
        self.timestamp = timestamp
    }
}

private enum EntryAlert {
    case editAmount
    case addPartialPayment
}

struct DebtsView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        predicate: NSPredicate(format: "isArchived != YES"),
        animation: .default)
    private var items: FetchedResults<Item>
    @State private var showSheet: Bool = false
    @State private var itemToEdit: Item?
    @State private var editedAmountText: String = ""
    @State private var itemForPartialPayment: Item?
    @State private var partialPaymentAmountText: String = ""
    @State private var activeAlert: EntryAlert?
    @State private var expandedRows: Set<NSManagedObjectID> = []

    var body: some View {
        List {
            ForEach(items) { item in
                debtCard(for: item)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        archiveItem(item)
                    } label: {
                        Label("Archivieren", systemImage: "archivebox.fill")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    Button {
                        startEditingAmount(for: item)
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .padding()
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(
            Color(.systemBackground)
                .ignoresSafeArea()
        )
        .sheet(isPresented: $showSheet) {
            SheetView(showSheet: $showSheet)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showSheet.toggle()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black)
                }
                
            }
        }
        .navigationTitle("Schulden")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle(), isPresented: isAlertPresentedBinding()) {
            if activeAlert == .editAmount {
                TextField("Betrag in €", text: $editedAmountText)
                    .keyboardType(.decimalPad)
            } else {
                TextField("Teilzahlung in €", text: $partialPaymentAmountText)
                    .keyboardType(.decimalPad)
            }
            Button("Abbrechen", role: .cancel) {}
            Button("Speichern") {
                if activeAlert == .editAmount {
                    saveEditedAmount()
                } else {
                    savePartialPayment()
                }
            }
        } message: {
            if activeAlert == .editAmount {
                Text("Bitte neuen Betrag eingeben.")
            } else {
                Text(partialPaymentMessage())
            }
        }
    }

    @ViewBuilder
    private func debtCard(for item: Item) -> some View {
        let totalAmount = max(item.amount, 0)
        let paidAmount = paidAmount(for: item)
        let remainingAmount = max(totalAmount - paidAmount, 0)
        let payments = partialPayments(for: item).sorted { $0.timestamp > $1.timestamp }
        let isExpanded = expandedRows.contains(item.objectID)

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.person?.isEmpty == false ? item.person! : "Ohne Person")
                        .font(.headline)
                    if let description = item.descriptionText, !description.isEmpty {
                        Label(description, systemImage: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Label(formattedDate(timestamp: item.timestamp), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(item.category ?? "Kategorie", systemImage: item.category == "schulde ich" ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((item.category == "schulde ich" ? Color.red : Color.green).opacity(0.15))
                    .foregroundStyle(item.category == "schulde ich" ? .red : .green)
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                amountChip(title: "Gesamt", amount: totalAmount, color: .blue, systemImage: "sum")
                amountChip(title: "Bezahlt", amount: paidAmount, color: .green, systemImage: "checkmark.circle.fill")
                amountChip(title: "Offen", amount: remainingAmount, color: .orange, systemImage: "clock.fill")
            }

            Button {
                startAddingPartialPayment(for: item)
            } label: {
                Label("Teilzahlung hinzufügen", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(remainingAmount <= 0)
            .opacity(remainingAmount <= 0 ? 0.5 : 1)
            .buttonStyle(.borderless)

            if remainingAmount <= 0 {
                paidOffBanner()
            }

            if payments.isEmpty {
                Label("Noch keine Teilzahlungen vorhanden.", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            } else {
                VStack(spacing: 10) {
                    HStack {
                        Label("Teilzahlungen (\(payments.count))", systemImage: "list.bullet.rectangle.portrait")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            withAnimation(.snappy(duration: 0.24, extraBounce: 0.02)) {
                                toggleExpansion(for: item)
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                    }

                    if isExpanded {
                        VStack(spacing: 8) {
                            ForEach(payments) { payment in
                                HStack {
                                    Label("\(String(format: "%.2f", payment.amount))€", systemImage: "eurosign.circle")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Text(formattedDate(timestamp: payment.timestamp))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.top, 4)
                        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .animation(.snappy(duration: 0.24, extraBounce: 0.02), value: isExpanded)
    }

    private func archiveItem(_ item: Item) {
        withAnimation {
            item.isArchived = true
            expandedRows.remove(item.objectID)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func startEditingAmount(for item: Item) {
        itemToEdit = item
        editedAmountText = String(format: "%.2f", item.amount)
        activeAlert = .editAmount
    }

    private func saveEditedAmount() {
        guard let item = itemToEdit else { return }
        let normalized = editedAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let newAmount = Double(normalized), newAmount >= 0 else { return }

        withAnimation {
            // Gesamtbetrag darf nicht kleiner als bereits bezahlte Summe werden.
            item.amount = max(newAmount, paidAmount(for: item))
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func startAddingPartialPayment(for item: Item) {
        itemForPartialPayment = item
        partialPaymentAmountText = String(format: "%.2f", remainingAmount(for: item))
        activeAlert = .addPartialPayment
    }

    private func savePartialPayment() {
        guard let item = itemForPartialPayment else { return }

        let normalized = partialPaymentAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let enteredAmount = Double(normalized), enteredAmount > 0 else { return }

        let openAmount = remainingAmount(for: item)
        guard openAmount > 0 else { return }

        let amountToApply = min(enteredAmount, openAmount)
        var payments = partialPayments(for: item)
        payments.append(PartialPayment(amount: amountToApply))
        savePartialPayments(payments, for: item)
        item.paidAmount = min(item.paidAmount + amountToApply, item.amount)

        withAnimation {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func amountChip(title: String, amount: Double, color: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(String(format: "%.2f", amount))€")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleExpansion(for item: Item) {
        if expandedRows.contains(item.objectID) {
            expandedRows.remove(item.objectID)
        } else {
            expandedRows.insert(item.objectID)
        }
    }

    private func paidOffBanner() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Komplett bezahlt")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text("Sehr stark, diese Schuld ist erledigt.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.95))
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.green, Color.teal],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func partialPayments(for item: Item) -> [PartialPayment] {
        guard let data = item.partialPaymentsData else { return [] }
        do {
            return try JSONDecoder().decode([PartialPayment].self, from: data)
        } catch {
            return []
        }
    }

    private func savePartialPayments(_ payments: [PartialPayment], for item: Item) {
        do {
            item.partialPaymentsData = try JSONEncoder().encode(payments)
        } catch {
            item.partialPaymentsData = nil
        }
    }

    private func paidAmount(for item: Item) -> Double {
        let historyPaid = partialPayments(for: item).reduce(0) { $0 + $1.amount }
        let storedPaid = max(item.paidAmount, 0)
        let effectivePaid = max(historyPaid, storedPaid)
        return min(effectivePaid, max(item.amount, 0))
    }

    private func remainingAmount(for item: Item) -> Double {
        max(item.amount - paidAmount(for: item), 0)
    }

    private func partialPaymentMessage() -> String {
        guard let item = itemForPartialPayment else {
            return "Bitte Betrag eingeben."
        }
        return "Offen aktuell: \(String(format: "%.2f", remainingAmount(for: item)))€"
    }

    private func alertTitle() -> String {
        activeAlert == .editAmount ? "Betrag bearbeiten" : "Teilzahlung hinzufügen"
    }

    private func isAlertPresentedBinding() -> Binding<Bool> {
        Binding {
            activeAlert != nil
        } set: { isPresented in
            if !isPresented {
                activeAlert = nil
            }
        }
    }

    func formattedDate(timestamp: Date?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy, HH:mm" // Format: Tag.Monat.Jahr Stunde:Minute
        return formatter.string(from: timestamp ?? Date())
    }
}


#Preview {
    DebtsView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
