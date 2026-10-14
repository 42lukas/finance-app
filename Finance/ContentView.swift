//
//  ContentView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct ContentView: View {
    enum TopTab: String, CaseIterable, Identifiable {
        case debts = "Schulden"
        case statistics = "Statistiken"

        var id: String { rawValue }
    }

    @State private var selectedTab: TopTab = .debts
    @Environment(\.scenePhase) private var scenePhase

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
                        StatisticsSettingsView()
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
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            Task {
                await DueDateNotificationScheduler.shared.reschedule()
            }
        }
    }
}

#Preview {
    ContentView()
}
