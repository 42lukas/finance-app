//
//  StatisticsSettingsView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct StatisticsSettingsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var showFileExporter: Bool = false
    @State private var exportDocument: FinanceBackupDocument?
    @State private var exportFileName: String = FinanceBackupService.suggestedFileName()
    @State private var infoMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                StatisticsSectionCard(title: "Backup", subtitle: "JSON lokal in Dateien sichern") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(items.count) Einträge werden in eine JSON-Datei exportiert.", systemImage: "doc.text.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            exportBackup()
                        } label: {
                            Label("Backup laden", systemImage: "square.and.arrow.down.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            handleExportResult(result)
        }
        .alert("Backup", isPresented: infoAlertBinding()) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(infoMessage ?? "")
        }
    }

    private func exportBackup() {
        do {
            exportDocument = try FinanceBackupService.makeBackupDocument(from: Array(items))
            exportFileName = FinanceBackupService.suggestedFileName()
            showFileExporter = true
        } catch {
            infoMessage = "Backup konnte nicht erstellt werden."
        }
    }

    private func handleExportResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            infoMessage = "Backup wurde erfolgreich gespeichert."
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.code != NSUserCancelledError else {
                return
            }
            infoMessage = "Speichern fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    private func infoAlertBinding() -> Binding<Bool> {
        Binding {
            infoMessage != nil
        } set: { isPresented in
            if !isPresented {
                infoMessage = nil
            }
        }
    }
}
