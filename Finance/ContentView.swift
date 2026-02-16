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
        }
    }
}

#Preview {
    ContentView()
}
