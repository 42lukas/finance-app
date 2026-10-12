//
//  DebtsView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct DebtsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        predicate: NSPredicate(format: "isArchived != YES"),
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var showSheet = false
    @State private var showEditAmountAlert = false
    @State private var itemToEdit: Item?
    @State private var editedAmountText = ""

    private var currentDebtTotal: Double {
        items
            .filter { $0.category == "schulde ich" }
            .reduce(0) { $0 + remainingAmount(for: $1) }
    }

    private var currentReceivableTotal: Double {
        items
            .filter { $0.category == "bekomme ich" }
            .reduce(0) { $0 + remainingAmount(for: $1) }
    }

    var body: some View {
        VStack(spacing: 12) {
            currentBalanceSummary
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Group {
                if items.isEmpty {
                    DebtsEmptyStateView {
                        showSheet = true
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            NavigationLink {
                                DebtDetailView(item: item)
                            } label: {
                                debtCard(for: item)
                            }
                            .buttonStyle(.plain)
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
                                .tint(AppPalette.navy)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .padding(.horizontal)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .sheet(isPresented: $showSheet) {
            SheetView(showSheet: $showSheet)
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showSheet.toggle()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppPalette.emerald)
                }
            }
        }
        .navigationTitle("Schulden")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Betrag bearbeiten", isPresented: $showEditAmountAlert) {
            TextField("Betrag in €", text: $editedAmountText)
                .keyboardType(.decimalPad)
            Button("Abbrechen", role: .cancel) {
                resetEditState()
            }
            Button("Speichern") {
                saveEditedAmount()
            }
        } message: {
            Text("Der Gesamtbetrag kann nicht kleiner als die bereits bezahlte Summe sein.")
        }
    }

    private var currentBalanceSummary: some View {
        HStack(spacing: 10) {
            balanceSummaryCard(
                title: "Aktuelle Schulden",
                amount: currentDebtTotal,
                color: AppPalette.navy,
                systemImage: "arrow.up.circle.fill"
            )

            balanceSummaryCard(
                title: "Ich bekomme",
                amount: currentReceivableTotal,
                color: AppPalette.emerald,
                systemImage: "arrow.down.circle.fill"
            )
        }
    }

    private func balanceSummaryCard(
        title: String,
        amount: Double,
        color: Color,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(color)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(amount, format: .currency(code: "EUR"))
                .font(.headline.weight(.bold))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .contentTransition(.numericText(value: amount))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.surface)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(amount.formatted(.currency(code: "EUR")))
    }

    @ViewBuilder
    private func debtCard(for item: Item) -> some View {
        let totalAmount = max(item.amount, 0)
        let paidAmount = paidAmount(for: item)
        let remainingAmount = max(totalAmount - paidAmount, 0)
        let categoryColor = item.category == "schulde ich" ? AppPalette.navy : AppPalette.emerald

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.person?.isEmpty == false ? item.person! : "Ohne Person")
                        .font(.headline)

                    if let description = item.descriptionText, !description.isEmpty {
                        Label(description, systemImage: "note.text")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label(formattedDate(item.timestamp), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Label(
                    item.category ?? "Kategorie",
                    systemImage: item.category == "schulde ich" ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                )
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(item.category == "schulde ich" ? AppPalette.paleNavy : AppPalette.mint)
                .foregroundStyle(categoryColor)
                .clipShape(Capsule())
            }

            HStack(alignment: .firstTextBaseline) {
                Text(totalAmount, format: .currency(code: "EUR"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppPalette.navy)

                Spacer()

                Label(
                    remainingAmount <= 0 ? "Bezahlt" : "Offen",
                    systemImage: remainingAmount <= 0 ? "checkmark.circle.fill" : "clock.fill"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(remainingAmount <= 0 ? AppPalette.emerald : AppPalette.ochre)
            }

            ProgressView(value: paidAmount, total: max(totalAmount, 1))
                .tint(AppPalette.emerald)

            HStack {
                Text("\(currency(paidAmount)) bezahlt")
                    .foregroundStyle(AppPalette.emerald)
                Spacer()
                Text("\(currency(remainingAmount)) offen")
                    .foregroundStyle(remainingAmount <= 0 ? Color.secondary : AppPalette.ochre)
            }
            .font(.caption.weight(.medium))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.surface)
        )
        .accessibilityElement(children: .combine)
    }

    private func archiveItem(_ item: Item) {
        withAnimation {
            item.isArchived = true
            saveContext()
        }
    }

    private func startEditingAmount(for item: Item) {
        itemToEdit = item
        editedAmountText = String(format: "%.2f", item.amount)
        showEditAmountAlert = true
    }

    private func saveEditedAmount() {
        defer { resetEditState() }
        guard let item = itemToEdit else { return }

        let normalized = editedAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let newAmount = Double(normalized), newAmount >= 0 else { return }

        withAnimation {
            item.amount = max(newAmount, paidAmount(for: item))
            saveContext()
        }
    }

    private func resetEditState() {
        itemToEdit = nil
        editedAmountText = ""
        showEditAmountAlert = false
    }

    private func partialPayments(for item: Item) -> [PartialPayment] {
        guard let data = item.partialPaymentsData else { return [] }
        return (try? JSONDecoder().decode([PartialPayment].self, from: data)) ?? []
    }

    private func paidAmount(for item: Item) -> Double {
        let historyPaid = partialPayments(for: item).reduce(0) { $0 + max($1.amount, 0) }
        let effectivePaid = max(historyPaid, max(item.paidAmount, 0))
        return min(effectivePaid, max(item.amount, 0))
    }

    private func remainingAmount(for item: Item) -> Double {
        max(item.amount - paidAmount(for: item), 0)
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
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

#Preview {
    DebtsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
