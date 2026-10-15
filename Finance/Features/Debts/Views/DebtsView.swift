//
//  DebtsView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct DebtsView: View {
    let onCreateEntry: () -> Void

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        predicate: NSPredicate(format: "isArchived != YES"),
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var itemToEdit: Item?
    @State private var recentlyArchivedItemID: UUID?
    @State private var recentlyArchivedPerson = ""
    @State private var dismissUndoTask: Task<Void, Never>?
    @State private var archiveErrorMessage: String?

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
                        onCreateEntry()
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
                                    startEditingEntry(item)
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
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppPalette.background.ignoresSafeArea())
        .sheet(item: $itemToEdit, onDismiss: resetEditState) { item in
            DebtEditSheet(item: item) { amount, reason, category, dueDate in
                saveEditedEntry(
                    item,
                    amount: amount,
                    reason: reason,
                    category: category,
                    dueDate: dueDate
                )
            }
        }
        .overlay(alignment: .bottom) {
            if recentlyArchivedItemID != nil {
                archiveUndoBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Archivieren fehlgeschlagen", isPresented: archiveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(archiveErrorMessage ?? "Der Eintrag konnte nicht archiviert werden.")
        }
        .onDisappear {
            dismissUndoTask?.cancel()
            clearUndoState()
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    Text(item.person?.isEmpty == false ? item.person! : "Unbekannt")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 8)

                    HStack(spacing: 6) {
                        Image(
                            systemName: item.category == "schulde ich"
                                ? "arrow.up.circle.fill"
                                : "arrow.down.circle.fill"
                        )
                        Text(DebtCategory.title(for: item.category))
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(item.category == "schulde ich" ? AppPalette.paleNavy : AppPalette.mint)
                    .foregroundStyle(categoryColor)
                    .clipShape(Capsule())
                    .fixedSize(horizontal: true, vertical: true)
                }

                if let description = item.descriptionText, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let dueDate = item.dueDate {
                    DueDateLabel(dueDate: dueDate, isCompleted: remainingAmount <= 0)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
        let itemID = item.id ?? UUID()
        item.id = itemID
        let person = item.person?.isEmpty == false ? item.person! : "Eintrag"

        do {
            DebtArchiveService.archive(item, source: .manual)
            try viewContext.save()
        } catch {
            viewContext.rollback()
            archiveErrorMessage = "Der Eintrag konnte nicht gespeichert werden: \(error.localizedDescription)"
            return
        }

        withAnimation(.easeOut(duration: 0.2)) {
            recentlyArchivedItemID = itemID
            recentlyArchivedPerson = person
        }

        scheduleUndoDismissal(for: itemID)
    }

    private var archiveUndoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox.fill")
                .foregroundStyle(AppPalette.emerald)

            VStack(alignment: .leading, spacing: 2) {
                Text("Archiviert")
                    .font(.subheadline.weight(.semibold))
                Text(recentlyArchivedPerson)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Rückgängig") {
                restoreRecentlyArchivedItem()
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(AppPalette.emerald)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppPalette.surface)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        )
    }

    private func restoreRecentlyArchivedItem() {
        dismissUndoTask?.cancel()
        guard let itemID = recentlyArchivedItemID else { return }

        let request: NSFetchRequest<Item> = Item.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@ AND isArchived == YES", itemID as CVarArg)

        do {
            if let item = try viewContext.fetch(request).first {
                try DebtArchiveService.restore(item)
                try viewContext.save()
            }
            withAnimation {
                clearUndoState()
            }
        } catch {
            viewContext.rollback()
            archiveErrorMessage = "Der Eintrag konnte nicht wiederhergestellt werden: \(error.localizedDescription)"
        }
    }

    private var archiveErrorBinding: Binding<Bool> {
        Binding {
            archiveErrorMessage != nil
        } set: { isPresented in
            if !isPresented {
                archiveErrorMessage = nil
            }
        }
    }

    private func scheduleUndoDismissal(for itemID: UUID) {
        dismissUndoTask?.cancel()
        dismissUndoTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard recentlyArchivedItemID == itemID else { return }
                withAnimation {
                    clearUndoState()
                }
            }
        }
    }

    private func clearUndoState() {
        recentlyArchivedItemID = nil
        recentlyArchivedPerson = ""
        dismissUndoTask = nil
    }

    private func startEditingEntry(_ item: Item) {
        itemToEdit = item
    }

    private func saveEditedEntry(
        _ item: Item,
        amount: Double,
        reason: String?,
        category: String,
        dueDate: Date?
    ) {
        withAnimation {
            item.amount = amount
            item.descriptionText = reason
            item.category = category
            item.dueDate = dueDate
            saveContext()
        }
    }

    private func resetEditState() {
        itemToEdit = nil
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

    private func currency(_ amount: Double) -> String {
        amount.formatted(.currency(code: "EUR"))
    }
}

#Preview {
    DebtsView(onCreateEntry: {})
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
