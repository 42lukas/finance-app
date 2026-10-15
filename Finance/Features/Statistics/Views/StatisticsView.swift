//
//  StatisticsView.swift
//  Finance
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

    private var snapshot: StatisticsSnapshot {
        StatisticsCalculator.makeSnapshot(from: Array(items), period: .allTime)
    }

    private var historicalNetAmount: Double {
        snapshot.summary.receivableAmount - snapshot.summary.owedAmount
    }

    private var currentNetAmount: Double {
        snapshot.summary.openReceivableAmount - snapshot.summary.openOwedAmount
    }

    private var paymentShare: Double {
        guard snapshot.summary.totalAmount > 0 else { return 0 }
        return min(max(snapshot.summary.paidAmount / snapshot.summary.totalAmount, 0), 1)
    }

    private var cumulativePoints: [TimeSeriesPoint] {
        var owedAmount: Double = 0
        var receivableAmount: Double = 0

        return snapshot.timeSeries.map { point in
            owedAmount += point.owedAmount
            receivableAmount += point.receivableAmount
            return TimeSeriesPoint(
                date: point.date,
                owedAmount: owedAmount,
                receivableAmount: receivableAmount
            )
        }
    }

    private let currencyCode = Locale.current.currency?.identifier ?? "EUR"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if items.isEmpty {
                    emptyState
                } else {
                    balanceSection
                    historySection
                    frequentPeopleSection
                    openDebtsSection
                    paymentProgressSection
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .navigationTitle("Statistiken")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppPalette.background)
    }

    private var balanceSection: some View {
        AppSectionCard(
            title: "Bilanz",
            subtitle: "Gesamte Historie inklusive Archiv"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Gesamt seit Beginn")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(signedCurrency(historicalNetAmount))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(balanceColor(for: historicalNetAmount))
                        .contentTransition(.numericText(value: historicalNetAmount))

                    Text(historicalBalanceExplanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 20) {
                    compactMetric(
                        title: "Schulden gesamt",
                        value: snapshot.summary.owedAmount,
                        systemImage: "arrow.up.circle.fill",
                        color: AppPalette.navy
                    )
                    compactMetric(
                        title: "Bekommen gesamt",
                        value: snapshot.summary.receivableAmount,
                        systemImage: "arrow.down.circle.fill",
                        color: AppPalette.emerald
                    )
                }

                Divider()
                    .overlay(AppPalette.navy.opacity(0.10))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Aktuell offen")
                                .font(.subheadline.weight(.semibold))
                            Text("Nur aktive Restbeträge")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(signedCurrency(currentNetAmount))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(balanceColor(for: currentNetAmount))
                    }

                    HStack(spacing: 6) {
                        Text("Du schuldest \(currency(snapshot.summary.openOwedAmount))")
                        Text("•")
                        Text("Du bekommst \(currency(snapshot.summary.openReceivableAmount))")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var historySection: some View {
        let points = cumulativePoints
        let trendColor = balanceColor(for: historicalNetAmount)

        return AppSectionCard(
            title: "Gesamtwert über Zeit",
            subtitle: "Kumulative Bilanz seit Beginn • inklusive Archiv"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(trendColor)
                        .frame(width: 8, height: 8)
                    Text("Bekommen minus Schulden")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    RuleMark(y: .value("Ausgeglichen", 0))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(AppPalette.navy.opacity(0.22))

                    ForEach(points) { point in
                        AreaMark(
                            x: .value("Datum", point.date),
                            yStart: .value("Ausgeglichen", 0),
                            yEnd: .value("Gesamtbilanz", point.netAmount)
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [trendColor.opacity(0.22), trendColor.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        LineMark(
                            x: .value("Datum", point.date),
                            y: .value("Gesamtbilanz", point.netAmount)
                        )
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(trendColor)

                        if point.id == points.last?.id {
                            PointMark(
                                x: .value("Datum", point.date),
                                y: .value("Gesamtbilanz", point.netAmount)
                            )
                            .symbolSize(55)
                            .foregroundStyle(trendColor)
                        }
                    }
                }
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(monthLabel(for: date))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine()
                            .foregroundStyle(AppPalette.navy.opacity(0.08))
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text(compactCurrency(amount))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(AppPalette.background.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: 200)
            }
        }
    }

    private var frequentPeopleSection: some View {
        let people = Array(snapshot.topPeopleByEntries.prefix(3))
        let maximum = max(people.map { Double($0.entries) }.max() ?? 0, 1)

        return AppSectionCard(
            title: "Am häufigsten",
            subtitle: "Anzahl aller Einträge • inklusive Archiv"
        ) {
            if people.isEmpty {
                Text("Keine Personendaten vorhanden.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(people) { person in
                    BarMark(
                        x: .value("Einträge", Double(person.entries)),
                        y: .value("Person", person.name)
                    )
                    .foregroundStyle(
                        person.id == people.first?.id
                            ? AppPalette.emerald
                            : AppPalette.navy.opacity(0.52)
                    )
                    .cornerRadius(6)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(person.entries)×")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXScale(domain: 0...(maximum + 1))
                .chartXAxis(.hidden)
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisValueLabel()
                            .foregroundStyle(AppPalette.navy)
                    }
                }
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(AppPalette.background.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .frame(height: max(120, CGFloat(people.count) * 42))
            }
        }
    }

    private var openDebtsSection: some View {
        AppSectionCard(
            title: "Offene Schulden",
            subtitle: "Nur aktive Beträge, die du noch schuldest"
        ) {
            if snapshot.oldestOpenDebt == nil && snapshot.largestOpenDebt == nil {
                Label("Du hast aktuell keine offenen Schulden.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppPalette.emerald)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 12) {
                    if let debt = snapshot.oldestOpenDebt {
                        debtRow(
                            title: "Am längsten offen",
                            debt: debt,
                            detail: "seit \(daysOpen(since: debt.timestamp)) Tagen • \(shortDate(debt.timestamp))",
                            systemImage: "clock.fill",
                            color: AppPalette.ochre
                        )
                    }

                    if snapshot.oldestOpenDebt != nil && snapshot.largestOpenDebt != nil {
                        Divider()
                            .overlay(AppPalette.navy.opacity(0.10))
                    }

                    if let debt = snapshot.largestOpenDebt {
                        debtRow(
                            title: "Größter offener Betrag",
                            debt: debt,
                            detail: debt.description,
                            systemImage: "arrow.up.right.circle.fill",
                            color: AppPalette.navy
                        )
                    }
                }
            }
        }
    }

    private var paymentProgressSection: some View {
        let remaining = max(snapshot.summary.totalAmount - snapshot.summary.paidAmount, 0)

        return AppSectionCard(
            title: "Bezahlt",
            subtitle: "Gesamtes Volumen inklusive Archiv"
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(currency(snapshot.summary.paidAmount))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppPalette.emerald)

                    Text("von \(currency(snapshot.summary.totalAmount))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(percentage(paymentShare))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppPalette.emerald)
                }

                ProgressView(value: paymentShare)
                    .tint(AppPalette.emerald)

                Text("Noch nicht als bezahlt erfasst: \(currency(remaining))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyState: some View {
        AppSectionCard(title: "Noch keine Statistik") {
            VStack(alignment: .leading, spacing: 8) {
                Label("Füge zuerst einige Schulden oder Forderungen hinzu.", systemImage: "plus.circle")
                Text("Danach erscheinen hier Gesamtbilanz, Verlauf und Zahlungsfortschritt.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private func compactMetric(
        title: String,
        value: Double,
        systemImage: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(currency(value))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func debtRow(
        title: String,
        debt: OutstandingEntryInsight,
        detail: String,
        systemImage: String,
        color: Color
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(debt.person) • \(detail)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(currency(debt.remainingAmount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
        }
    }

    private var historicalBalanceExplanation: String {
        if abs(historicalNetAmount) < 0.005 {
            return "Schulden und Forderungen sind über die gesamte Historie ausgeglichen."
        }
        if historicalNetAmount > 0 {
            return "Du hast insgesamt \(currency(historicalNetAmount)) mehr zum Bekommen erfasst."
        }
        return "Du hast insgesamt \(currency(abs(historicalNetAmount))) mehr Schulden erfasst."
    }

    private func balanceColor(for value: Double) -> Color {
        value >= 0 ? AppPalette.emerald : AppPalette.navy
    }

    private func daysOpen(since date: Date) -> Int {
        max(Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0, 0)
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year())
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        return formatter.string(from: date)
    }

    private func compactCurrency(_ value: Double) -> String {
        let absoluteValue = abs(value)
        if absoluteValue >= 1_000 {
            return String(format: "%.1f Tsd. €", value / 1_000)
        }
        return String(format: "%.0f €", value)
    }

    private func percentage(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }

    private func signedCurrency(_ value: Double) -> String {
        let sign = value > 0.005 ? "+" : ""
        return sign + currency(value)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: value as NSNumber) ?? String(format: "%.2f €", value)
    }
}
