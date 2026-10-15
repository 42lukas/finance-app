//
//  ContentView.swift
//  Finance
//
//

import SwiftUI
import CoreData
import WidgetKit

struct ContentView: View {
    enum TopTab: String, CaseIterable, Identifiable {
        case debts = "Schulden"
        case statistics = "Statistiken"

        var id: String { rawValue }
    }

    @State private var selectedTab: TopTab = .debts
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Picker("Bereich", selection: $selectedTab) {
                    ForEach(TopTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                Group {
                    switch selectedTab {
                    case .debts:
                        DebtsView()
                    case .statistics:
                        StatisticsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppPalette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
        }
        .task {
            await DueDateNotificationScheduler.shared.reschedule()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            PersistenceController.shared.refreshViewContextFromSharedStore()
            WidgetCenter.shared.reloadTimelines(ofKind: "EvenOverviewWidget")
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            WidgetCenter.shared.reloadTimelines(ofKind: "EvenOverviewWidget")
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            guard !viewContext.hasChanges else { return }
            PersistenceController.shared.refreshViewContextFromSharedStore()
        }
    }
}

#Preview {
    ContentView()
}
