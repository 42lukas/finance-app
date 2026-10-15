//
//  SettingsView.swift
//  Finance
//
//

import SwiftUI
import CoreData
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var showFileExporter: Bool = false
    @State private var exportDocument: FinanceBackupDocument?
    @State private var exportFileName: String = FinanceBackupService.suggestedFileName()
    @State private var infoMessage: String?
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    @AppStorage(ReminderPreferences.notificationsEnabledKey, store: ReminderPreferences.storage)
    private var notificationsEnabled: Bool = true

    @AppStorage(ReminderPreferences.frequencyKey, store: ReminderPreferences.storage)
    private var reminderFrequencyRawValue: Int = ReminderFrequency.threeTimes.rawValue

    @AppStorage(ReminderPreferences.timeMinutesKey, store: ReminderPreferences.storage)
    private var reminderTimeMinutes: Int = ReminderPreferences.defaultTimeMinutes

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionCard(title: "Darstellung", subtitle: "System, Hell oder Dunkel") {
                    AppThemePickerView(selectedTheme: $themeManager.selectedTheme)
                }

                reminderSettingsCard

                AppSectionCard(title: "Backup", subtitle: "JSON lokal in Dateien sichern") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("\(items.count) Einträge werden in eine JSON-Datei exportiert.", systemImage: "doc.text.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            exportBackup()
                        } label: {
                            Label("Backup exportieren", systemImage: "square.and.arrow.up.fill")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(AppPalette.mint)
                                .foregroundStyle(AppPalette.emerald)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                AppSectionCard(title: "Daten", subtitle: "Einträge endgültig löschen") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Daten verwalten", systemImage: "archivebox.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppPalette.paleNavy)
                            .foregroundStyle(AppPalette.navy)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationTitle("Einstellungen")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppPalette.background)
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
        .task {
            await refreshNotificationAuthorizationStatus()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshNotificationAuthorizationStatus()
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            Task {
                if isEnabled {
                    _ = await DueDateNotificationScheduler.shared.requestAuthorizationIfNeeded()
                }
                await DueDateNotificationScheduler.shared.reschedule()
                await refreshNotificationAuthorizationStatus()
            }
        }
        .onChange(of: reminderFrequencyRawValue) { _, _ in
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
        .onChange(of: reminderTimeMinutes) { _, _ in
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
    }

    private var reminderSettingsCard: some View {
        AppSectionCard(
            title: "Fälligkeitserinnerungen",
            subtitle: "Zeitpunkt und Häufigkeit für alle Einträge"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Mitteilungen", systemImage: "bell.badge.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(AppPalette.emerald)

                if notificationsEnabled {
                    Divider()
                        .overlay(AppPalette.navy.opacity(0.10))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anzahl der Erinnerungen")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Picker("Anzahl der Erinnerungen", selection: $reminderFrequencyRawValue) {
                            ForEach(ReminderFrequency.allCases) { frequency in
                                Text("\(frequency.rawValue)×").tag(frequency.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(selectedReminderFrequency.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                        .overlay(AppPalette.navy.opacity(0.10))

                    DatePicker(
                        "Uhrzeit",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.subheadline.weight(.medium))

                    notificationAuthorizationRow
                }
            }
        }
    }

    @ViewBuilder
    private var notificationAuthorizationRow: some View {
        switch notificationAuthorizationStatus {
        case .authorized:
            Label("Mitteilungen sind in iOS erlaubt.", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(AppPalette.emerald)
        case .provisional, .ephemeral:
            Label("Mitteilungen werden aktuell leise zugestellt.", systemImage: "bell.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .notDetermined:
            Button {
                Task {
                    _ = await DueDateNotificationScheduler.shared.requestAuthorizationIfNeeded()
                    await DueDateNotificationScheduler.shared.reschedule()
                    await refreshNotificationAuthorizationStatus()
                }
            } label: {
                Label("Mitteilungen erlauben", systemImage: "bell.fill")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppPalette.emerald)
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Mitteilungen sind in iOS deaktiviert.", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(AppPalette.ochre)

                Button("In iOS-Einstellungen öffnen") {
                    guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                    openURL(url)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.navy)
            }
        @unknown default:
            EmptyView()
        }
    }

    private var selectedReminderFrequency: ReminderFrequency {
        ReminderFrequency(rawValue: reminderFrequencyRawValue) ?? .threeTimes
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            return calendar.date(byAdding: .minute, value: reminderTimeMinutes, to: startOfToday) ?? Date()
        } set: { newValue in
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderTimeMinutes = (components.hour ?? 18) * 60 + (components.minute ?? 0)
        }
    }

    @MainActor
    private func refreshNotificationAuthorizationStatus() async {
        notificationAuthorizationStatus = await DueDateNotificationScheduler.shared.authorizationStatus()
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
