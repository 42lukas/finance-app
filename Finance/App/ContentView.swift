//
//  ContentView.swift
//  Finance
//
//

import SwiftUI
import Combine
import CoreData
import WidgetKit

struct ContentView: View {
    enum TopTab: String, CaseIterable, Identifiable {
        case debts = "Schulden"
        case statistics = "Statistiken"

        var id: String { rawValue }
    }

    @State private var selectedTab: TopTab = .debts
    @State private var isPresentingNewEntry = false
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
                        DebtsView {
                            isPresentingNewEntry = true
                        }
                    case .statistics:
                        StatisticsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(AppPalette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isPresentingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Neuen Eintrag erstellen")
                }

                ToolbarItem(placement: .principal) {
                    Text("Even")
                        .font(.headline)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        ArchiveView()
                    } label: {
                        Image(systemName: "archivebox")
                    }
                    .accessibilityLabel("Archiv öffnen")

                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $isPresentingNewEntry) {
                SheetView(showSheet: $isPresentingNewEntry)
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            PersistenceController.shared.refreshViewContextFromSharedStore()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
                .receive(on: DispatchQueue.main)
        ) { _ in
            WidgetCenter.shared.reloadTimelines(ofKind: "EvenOverviewWidget")
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
                .receive(on: DispatchQueue.main)
        ) { _ in
            guard !viewContext.hasChanges else { return }
            PersistenceController.shared.refreshViewContextFromSharedStore()
        }
    }
}

#Preview {
    ContentView()
}
