//
//  StatisticsDataManagementView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct StatisticsDataManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var itemToDeletePermanently: Item?
    @State private var showDeleteAllArchivedConfirmation: Bool = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Hier entfernte Einträge verschwinden dauerhaft aus den Statistiken.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Das ist endgültig und kann nicht rückgängig gemacht werden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Einträge (\(items.count))") {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Keine Daten",
                        systemImage: "tray",
                        description: Text("Es gibt aktuell keine Einträge zum Bereinigen.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(items) { item in
                        entryRow(item: item)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    itemToDeletePermanently = item
                                } label: {
                                    Label("Endgültig löschen", systemImage: "trash.fill")
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Daten bereinigen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAllArchivedConfirmation = true
                } label: {
                    Label("Archiv endgültig löschen", systemImage: "trash.circle")
                }
                .disabled(archivedCount == 0)
            }
        }
        .alert("Eintrag endgültig löschen?", isPresented: deleteAlertBinding()) {
            Button("Abbrechen", role: .cancel) {}
            Button("Endgültig löschen", role: .destructive) {
                deleteSelectedItemPermanently()
            }
        } message: {
            Text("Der Eintrag wird komplett entfernt und taucht in den Statistiken nicht mehr auf.")
        }
        .alert("Alle archivierten Einträge löschen?", isPresented: $showDeleteAllArchivedConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Alles löschen", role: .destructive) {
                deleteAllArchivedItemsPermanently()
            }
        } message: {
            Text("\(archivedCount) archivierte Einträge werden dauerhaft gelöscht.")
        }
    }

    private var archivedCount: Int {
        items.filter { $0.isArchived }.count
    }

    private func entryRow(item: Item) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(item.person?.isEmpty == false ? item.person! : "Ohne Person")
                    .font(.headline)
                Spacer()
                Text("\(String(format: "%.2f", item.amount))€")
                    .font(.headline)
                    .foregroundStyle(item.category == "schulde ich" ? .red : .green)
            }

            if let description = item.descriptionText, !description.isEmpty {
                Label(description, systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(formattedDate(item.timestamp), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(item.isArchived ? "Archiviert" : "Aktiv", systemImage: item.isArchived ? "archivebox.fill" : "circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((item.isArchived ? Color.gray : Color.blue).opacity(0.14))
                    .foregroundStyle(item.isArchived ? .gray : .blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func deleteAlertBinding() -> Binding<Bool> {
        Binding {
            itemToDeletePermanently != nil
        } set: { isPresented in
            if !isPresented {
                itemToDeletePermanently = nil
            }
        }
    }

    private func deleteSelectedItemPermanently() {
        guard let item = itemToDeletePermanently else { return }

        withAnimation {
            viewContext.delete(item)
            saveContext()
            itemToDeletePermanently = nil

            if items.isEmpty {
                dismiss()
            }
        }
    }

    private func deleteAllArchivedItemsPermanently() {
        let archivedItems = items.filter(\.isArchived)
        guard !archivedItems.isEmpty else { return }

        withAnimation {
            archivedItems.forEach(viewContext.delete)
            saveContext()
        }
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
}
