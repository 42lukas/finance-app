//
//  StatisticsCalculator.swift
//  Finance
//
//

import Foundation

enum StatisticsCalculator {
    static func makeSnapshot(
        from items: [Item],
        period: StatisticsPeriod,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> StatisticsSnapshot {
        let filteredItems = filtered(items: items, for: period, calendar: calendar, now: now)

        let summary = makeSummary(from: filteredItems)
        let peopleClusters = makePeopleClusters(from: filteredItems)
        let topPeopleByEntries = peopleClusters
            .sorted { lhs, rhs in
                if lhs.entries == rhs.entries {
                    return lhs.totalAmount > rhs.totalAmount
                }
                return lhs.entries > rhs.entries
            }
        let topPeopleByAmount = peopleClusters
            .sorted { lhs, rhs in
                if lhs.totalAmount == rhs.totalAmount {
                    return lhs.entries > rhs.entries
                }
                return lhs.totalAmount > rhs.totalAmount
            }

        return StatisticsSnapshot(
            summary: summary,
            topPeopleByEntries: Array(topPeopleByEntries.prefix(8)),
            topPeopleByAmount: Array(topPeopleByAmount.prefix(8)),
            timeSeries: makeTimeSeries(from: filteredItems, period: period, calendar: calendar, now: now),
            weekdayClusters: makeWeekdayClusters(from: filteredItems, calendar: calendar)
        )
    }

    private static func filtered(
        items: [Item],
        for period: StatisticsPeriod,
        calendar: Calendar,
        now: Date
    ) -> [Item] {
        guard period != .allTime else {
            return items
        }

        let component: Calendar.Component = (period == .month) ? .month : .year
        guard let interval = calendar.dateInterval(of: component, for: now) else {
            return items
        }

        return items.filter { item in
            guard let timestamp = item.timestamp else { return false }
            return interval.contains(timestamp)
        }
    }

    private static func makeSummary(from items: [Item]) -> StatisticsSummary {
        guard !items.isEmpty else {
            return .empty
        }

        var totalAmount: Double = 0
        var owedAmount: Double = 0
        var receivableAmount: Double = 0
        var uniquePeople = Set<String>()
        var paidOffCount = 0

        for item in items {
            let amount = max(item.amount, 0)
            totalAmount += amount

            if item.category == "schulde ich" {
                owedAmount += amount
            } else {
                receivableAmount += amount
            }

            let person = normalizedPerson(item.person)
            uniquePeople.insert(person)

            if max(item.amount - item.paidAmount, 0) <= 0 {
                paidOffCount += 1
            }
        }

        return StatisticsSummary(
            entriesCount: items.count,
            totalAmount: totalAmount,
            owedAmount: owedAmount,
            receivableAmount: receivableAmount,
            averageAmount: totalAmount / Double(items.count),
            uniquePersons: uniquePeople.count,
            paidOffCount: paidOffCount
        )
    }

    private static func makePeopleClusters(from items: [Item]) -> [PersonCluster] {
        var buckets: [String: (entries: Int, totalAmount: Double)] = [:]

        for item in items {
            let key = normalizedPerson(item.person)
            let amount = max(item.amount, 0)
            var bucket = buckets[key, default: (entries: 0, totalAmount: 0)]
            bucket.entries += 1
            bucket.totalAmount += amount
            buckets[key] = bucket
        }

        return buckets.map { key, value in
            PersonCluster(
                name: key,
                entries: value.entries,
                totalAmount: value.totalAmount
            )
        }
    }

    private static func makeTimeSeries(
        from items: [Item],
        period: StatisticsPeriod,
        calendar: Calendar,
        now: Date
    ) -> [TimeSeriesPoint] {
        guard !items.isEmpty else { return [] }

        let component: Calendar.Component = (period == .month) ? .day : .month
        let bucketDates = makeBucketDates(for: items, period: period, component: component, calendar: calendar, now: now)

        var buckets: [Date: (owed: Double, receivable: Double)] = [:]
        for item in items {
            let timestamp = item.timestamp ?? now
            guard let bucketDate = calendar.dateInterval(of: component, for: timestamp)?.start else { continue }

            var current = buckets[bucketDate, default: (owed: 0, receivable: 0)]
            let amount = max(item.amount, 0)
            if item.category == "schulde ich" {
                current.owed += amount
            } else {
                current.receivable += amount
            }
            buckets[bucketDate] = current
        }

        return bucketDates.map { date in
            let values = buckets[date, default: (owed: 0, receivable: 0)]
            return TimeSeriesPoint(
                date: date,
                owedAmount: values.owed,
                receivableAmount: values.receivable
            )
        }
    }

    private static func makeBucketDates(
        for items: [Item],
        period: StatisticsPeriod,
        component: Calendar.Component,
        calendar: Calendar,
        now: Date
    ) -> [Date] {
        if period == .month || period == .year {
            guard let interval = calendar.dateInterval(of: period == .month ? .month : .year, for: now) else {
                return []
            }
            return strideDates(from: interval.start, to: interval.end, component: component, calendar: calendar)
        }

        guard
            let firstItemDate = items.compactMap(\.timestamp).min(),
            let lastItemDate = items.compactMap(\.timestamp).max(),
            let firstBucket = calendar.dateInterval(of: .month, for: firstItemDate)?.start,
            let lastBucket = calendar.dateInterval(of: .month, for: lastItemDate)?.start
        else {
            return []
        }

        guard let lastEnd = calendar.date(byAdding: .month, value: 1, to: lastBucket) else {
            return [firstBucket]
        }

        return strideDates(from: firstBucket, to: lastEnd, component: .month, calendar: calendar)
    }

    private static func strideDates(
        from start: Date,
        to end: Date,
        component: Calendar.Component,
        calendar: Calendar
    ) -> [Date] {
        var dates: [Date] = []
        var current = start

        while current < end {
            dates.append(current)
            guard let next = calendar.date(byAdding: component, value: 1, to: current) else { break }
            current = next
        }
        return dates
    }

    private static func makeWeekdayClusters(from items: [Item], calendar: Calendar) -> [WeekdayCluster] {
        guard !items.isEmpty else { return [] }

        let symbols = calendar.shortWeekdaySymbols
        let symbolCount = symbols.count
        var counts = Array(repeating: 0, count: symbolCount)

        for item in items {
            let timestamp = item.timestamp ?? Date()
            let weekdayIndex = calendar.component(.weekday, from: timestamp) - 1
            guard weekdayIndex >= 0, weekdayIndex < symbolCount else { continue }
            counts[weekdayIndex] += 1
        }

        let start = max(calendar.firstWeekday - 1, 0)
        let orderedIndices = (0..<symbolCount).map { (start + $0) % symbolCount }

        return orderedIndices.map { index in
            WeekdayCluster(
                weekday: symbols[index],
                entries: counts[index]
            )
        }
    }

    private static func normalizedPerson(_ person: String?) -> String {
        let trimmed = (person ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unbekannt" : trimmed
    }
}
