//
//  StatisticsView.swift
//  Finance
//
//

import SwiftUI
import CoreData
import Charts

struct StatisticsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default
    )
    private var items: FetchedResults<Item>

    @State private var selectedPeriod: StatisticsPeriod = .month

    private var snapshot: StatisticsSnapshot {
        StatisticsCalculator.makeSnapshot(
            from: Array(items),
            period: selectedPeriod
        )
    }

    private let currencyCode = Locale.current.currency?.identifier ?? "EUR"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                periodPicker

                if snapshot.summary.entriesCount == 0 {
                    emptyState
                } else {
                    metricGrid
                    nerdClusterSection
                    timeSeriesSection
                    topPeopleSection
                    weekdaySection
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)
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
        .background(Color(.systemBackground))
    }

    private var periodPicker: some View {
        StatisticsSectionCard(title: "Zeitraum", subtitle: selectedPeriod.subtitle) {
            VStack(spacing: 12) {
                Picker("Zeitraum", selection: $selectedPeriod) {
                    ForEach(StatisticsPeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                NavigationLink {
                    StatisticsDataManagementView()
                } label: {
                    Label("Statistik-Daten bereinigen", systemImage: "trash.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.14))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var metricGrid: some View {
        let summary = snapshot.summary

        return LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            StatisticsMetricCard(
                title: "Einträge",
                value: "\(summary.entriesCount)",
                systemImage: "list.bullet",
                color: .blue
            )
            StatisticsMetricCard(
                title: "Gesamtvolumen",
                value: currency(summary.totalAmount),
                systemImage: "sum",
                color: .indigo
            )
            StatisticsMetricCard(
                title: "Ich schulde",
                value: currency(summary.owedAmount),
                systemImage: "arrow.up.circle.fill",
                color: .red
            )
            StatisticsMetricCard(
                title: "Ich bekomme",
                value: currency(summary.receivableAmount),
                systemImage: "arrow.down.circle.fill",
                color: .green
            )
            StatisticsMetricCard(
                title: "Durchschnitt",
                value: currency(summary.averageAmount),
                systemImage: "chart.bar.doc.horizontal",
                color: .orange
            )
            StatisticsMetricCard(
                title: "Personen",
                value: "\(summary.uniquePersons)",
                systemImage: "person.2.fill",
                color: .teal
            )
        }
    }

    private var nerdClusterSection: some View {
        let topByEntries = snapshot.topPeopleByEntries.first
        let topByAmount = snapshot.topPeopleByAmount.first
        let concentration = concentrationIndex()

        return StatisticsSectionCard(title: "Cluster", subtitle: "Auffällige Muster für Nerd-Brain") {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    topByEntries == nil
                    ? "Keine Daten"
                    : "Häufigste Person: \(topByEntries!.name) (\(topByEntries!.entries)x)",
                    systemImage: "person.crop.circle.badge.clock"
                )
                Label(
                    topByAmount == nil
                    ? "Keine Daten"
                    : "Volumen-Spitze: \(topByAmount!.name) (\(currency(topByAmount!.totalAmount)))",
                    systemImage: "crown.fill"
                )
                Label(
                    "Konzentrationsindex Top-3: \(String(format: "%.1f", concentration * 100))%",
                    systemImage: "atom"
                )
                Label(
                    "Komplett bezahlt: \(snapshot.summary.paidOffCount) / \(snapshot.summary.entriesCount)",
                    systemImage: "checkmark.seal.fill"
                )
            }
            .font(.subheadline)
        }
    }

    private var timeSeriesSection: some View {
        StatisticsSectionCard(title: "Zeitverlauf", subtitle: "Ich schulde vs. ich bekomme") {
            Chart(snapshot.timeSeries) { point in
                AreaMark(
                    x: .value("Datum", point.date),
                    y: .value("Ich schulde", point.owedAmount)
                )
                .foregroundStyle(.red.opacity(0.16))

                LineMark(
                    x: .value("Datum", point.date),
                    y: .value("Ich schulde", point.owedAmount)
                )
                .foregroundStyle(.red)
                .symbol(.circle)

                AreaMark(
                    x: .value("Datum", point.date),
                    y: .value("Ich bekomme", point.receivableAmount)
                )
                .foregroundStyle(.green.opacity(0.16))

                LineMark(
                    x: .value("Datum", point.date),
                    y: .value("Ich bekomme", point.receivableAmount)
                )
                .foregroundStyle(.green)
                .symbol(.circle)
            }
            .chartLegend(position: .top, alignment: .leading)
            .frame(height: 220)
        }
    }

    private var topPeopleSection: some View {
        let clusters = Array(snapshot.topPeopleByEntries.prefix(6))

        return StatisticsSectionCard(title: "Top Personen", subtitle: "Wer taucht am häufigsten auf?") {
            if clusters.isEmpty {
                Text("Keine Personendaten vorhanden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(clusters) { person in
                    BarMark(
                        x: .value("Person", person.name),
                        y: .value("Einträge", person.entries)
                    )
                    .foregroundStyle(.blue.gradient)
                }
                .frame(height: 220)
            }
        }
    }

    private var weekdaySection: some View {
        let weekdayClusters = snapshot.weekdayClusters

        return StatisticsSectionCard(title: "Wochentag-Muster", subtitle: "Wann trägst du am meisten ein?") {
            if weekdayClusters.isEmpty {
                Text("Keine Wochentag-Daten vorhanden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(weekdayClusters) { day in
                    BarMark(
                        x: .value("Wochentag", day.weekday),
                        y: .value("Einträge", day.entries)
                    )
                    .foregroundStyle(.teal.gradient)
                }
                .frame(height: 200)
            }
        }
    }

    private var emptyState: some View {
        StatisticsSectionCard(title: "Noch keine Statistik", subtitle: selectedPeriod.subtitle) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Füge zuerst ein paar Schuldeneinträge hinzu.", systemImage: "plus.circle")
                Label("Danach siehst du hier Cluster, Trends und Nerd-Metriken.", systemImage: "chart.xyaxis.line")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func concentrationIndex() -> Double {
        let total = Double(max(snapshot.summary.entriesCount, 1))
        let topThree = snapshot.topPeopleByEntries.prefix(3).reduce(0) { $0 + $1.entries }
        return Double(topThree) / total
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: value as NSNumber) ?? String(format: "%.2f €", value)
    }
}
