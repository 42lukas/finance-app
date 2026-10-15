//
//  ArchiveView.swift
//  Finance
//

import CoreData
import SwiftUI

struct ArchiveView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Item.archivedAt, ascending: false),
            NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)
        ],
        predicate: NSPredicate(format: "isArchived == YES"),
        animation: .default
    )
    private var archivedItems: FetchedResults<Item>

    @State private var selectedFilter: ArchiveFilter = .all
    @State private var searchText = ""
    @State private var itemAwaitingRestoreChoice: Item?
    @State private var itemToDelete: Item?
    @State private var errorMessage: String?

    private var visibleItems: [Item] {
        archivedItems.filter { item in
            selectedFilter.includes(item) && matchesSearch(item)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            filterPicker

            if archivedItems.isEmpty {
                emptyArchiveView
            } else if visibleItems.isEmpty {
                noResultsView
            } else {
                archiveList
            }
        }
        .background(AppPalette.background.ignoresSafeArea())
        .navigationTitle("Archiv")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            prompt: "Person oder Grund suchen"
        )
        .enforcingCharacterLimit(
            $searchText,
            maximumLength: InputRules.archiveSearchMaxLength
        )
        .confirmationDialog(
            "Wie soll der Eintrag wiederhergestellt werden?",
            isPresented: restoreChoiceBinding,
            titleVisibility: .visible
        ) {
            Button("Offenen Betrag wiederherstellen") {
                restoreSelectedWidgetItem(revertingCompletion: true)
            }
            Button("Nur ins Aktive verschieben") {
                restoreSelectedWidgetItem(revertingCompletion: false)
            }
            Button("Abbrechen", role: .cancel) {
                itemAwaitingRestoreChoice = nil
            }
        } message: {
            Text("Dieser Eintrag wurde im Widget als erledigt markiert. Du kannst auch die dabei erzeugte Zahlung rückgängig machen.")
        }
        .alert("Eintrag endgültig löschen?", isPresented: deleteConfirmationBinding) {
            Button("Abbrechen", role: .cancel) {
                itemToDelete = nil
            }
            Button("Endgültig löschen", role: .destructive) {
                deleteSelectedItem()
            }
        } message: {
            Text("Der Eintrag und seine Teilzahlungen werden dauerhaft gelöscht und aus den Statistiken entfernt.")
        }
        .alert("Aktion fehlgeschlagen", isPresented: errorAlertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Der Eintrag konnte nicht aktualisiert werden.")
        }
    }

    private var filterPicker: some View {
        Picker("Archiv filtern", selection: $selectedFilter) {
            ForEach(ArchiveFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var archiveList: some View {
        List {
            ForEach(visibleItems) { item in
                ArchiveEntryCard(item: item)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            requestRestore(item)
                        } label: {
                            Label("Wiederherstellen", systemImage: "arrow.uturn.backward.circle.fill")
                        }
                        .tint(AppPalette.emerald)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            itemToDelete = item
                        } label: {
                            Label("Endgültig löschen", systemImage: "trash.fill")
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 7, leading: 16, bottom: 7, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyArchiveView: some View {
        ContentUnavailableView {
            Label("Archiv ist leer", systemImage: "archivebox")
        } description: {
            Text("Archivierte Einträge bleiben hier erhalten und können später wiederhergestellt werden.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        ContentUnavailableView {
            Label("Keine Treffer", systemImage: "magnifyingglass")
        } description: {
            Text("Passe Suche oder Filter an.")
        } actions: {
            Button("Filter zurücksetzen") {
                selectedFilter = .all
                searchText = ""
            }
            .foregroundStyle(AppPalette.emerald)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var restoreChoiceBinding: Binding<Bool> {
        Binding {
            itemAwaitingRestoreChoice != nil
        } set: { isPresented in
            if !isPresented {
                itemAwaitingRestoreChoice = nil
            }
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            itemToDelete != nil
        } set: { isPresented in
            if !isPresented {
                itemToDelete = nil
            }
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding {
            errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                errorMessage = nil
            }
        }
    }

    private func matchesSearch(_ item: Item) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return [item.person, item.descriptionText]
            .compactMap { $0 }
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func requestRestore(_ item: Item) {
        if DebtArchiveService.canRevertWidgetCompletion(for: item) {
            itemAwaitingRestoreChoice = item
        } else {
            restore(item, mode: .keepPayments)
        }
    }

    private func restoreSelectedWidgetItem(revertingCompletion: Bool) {
        guard let item = itemAwaitingRestoreChoice else { return }
        itemAwaitingRestoreChoice = nil
        restore(item, mode: revertingCompletion ? .revertWidgetCompletion : .keepPayments)
    }

    private func restore(_ item: Item, mode: DebtArchiveRestorationMode) {
        do {
            try DebtArchiveService.restore(item, mode: mode)
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = "Der Eintrag konnte nicht wiederhergestellt werden."
        }
    }

    private func deleteSelectedItem() {
        guard let item = itemToDelete else { return }
        itemToDelete = nil

        do {
            viewContext.delete(item)
            try viewContext.save()
        } catch {
            viewContext.rollback()
            errorMessage = "Der Eintrag konnte nicht endgültig gelöscht werden."
        }
    }
}

private struct ArchiveEntryCard: View {
    @ObservedObject var item: Item

    private var isCompleted: Bool { item.openAmount <= 0.005 }
    private var isOwedByMe: Bool { item.category == "schulde ich" }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayPerson)
                        .font(.headline)

                    if let description = item.descriptionText, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Label(
                        DebtCategory.title(for: item.category),
                        systemImage: isOwedByMe ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isOwedByMe ? AppPalette.navy : AppPalette.emerald)
                }

                Spacer(minLength: 8)

                statusBadge
            }

            HStack(alignment: .firstTextBaseline) {
                Text(item.amount, format: .currency(code: "EUR"))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isOwedByMe ? AppPalette.navy : AppPalette.emerald)

                Spacer()

                Text("\(currency(item.effectivePaidAmount)) bezahlt")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppPalette.emerald)
            }

            ProgressView(value: item.effectivePaidAmount, total: max(item.amount, 1))
                .tint(AppPalette.emerald)

            HStack(spacing: 12) {
                Label(archiveDateText, systemImage: "archivebox.fill")

                if item.archiveSource == DebtArchiveSource.widgetCompletion.rawValue {
                    Label("Widget", systemImage: "rectangle.and.hand.point.up.left.fill")
                } else if item.archiveSource == DebtArchiveSource.manual.rawValue {
                    Label("Manuell", systemImage: "hand.tap.fill")
                }

                Spacer(minLength: 4)

                Text("\(currency(item.openAmount)) offen")
                    .foregroundStyle(isCompleted ? Color.secondary : AppPalette.ochre)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppPalette.surface)
        )
        .accessibilityElement(children: .combine)
    }

    private var statusBadge: some View {
        Label(
            isCompleted ? "Erledigt" : "Noch offen",
            systemImage: isCompleted ? "checkmark.circle.fill" : "clock.fill"
        )
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isCompleted ? AppPalette.mint : AppPalette.surfaceMuted)
        .foregroundStyle(isCompleted ? AppPalette.emerald : AppPalette.ochre)
        .clipShape(Capsule())
    }

    private var displayPerson: String {
        guard let person = item.person, !person.isEmpty else { return "Unbekannt" }
        return person
    }

    private var archiveDateText: String {
        guard let archivedAt = item.archivedAt else { return "Archiviert" }
        return archivedAt.formatted(.dateTime.day().month(.abbreviated).year())
    }

    private func currency(_ amount: Double) -> String {
        amount.formatted(.currency(code: "EUR"))
    }
}

#Preview {
    NavigationStack {
        ArchiveView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
