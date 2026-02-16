//
//  StatisticsModels.swift
//  Finance
//
//

import Foundation

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case month = "Monat"
    case year = "Jahr"
    case allTime = "All Time"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .month:
            return "Aktueller Monat"
        case .year:
            return "Aktuelles Jahr"
        case .allTime:
            return "Seit Beginn"
        }
    }
}

struct StatisticsSummary {
    let entriesCount: Int
    let totalAmount: Double
    let owedAmount: Double
    let receivableAmount: Double
    let averageAmount: Double
    let uniquePersons: Int
    let paidOffCount: Int

    static let empty = StatisticsSummary(
        entriesCount: 0,
        totalAmount: 0,
        owedAmount: 0,
        receivableAmount: 0,
        averageAmount: 0,
        uniquePersons: 0,
        paidOffCount: 0
    )
}

struct PersonCluster: Identifiable {
    let name: String
    let entries: Int
    let totalAmount: Double

    var id: String { name }
}

struct TimeSeriesPoint: Identifiable {
    let date: Date
    let owedAmount: Double
    let receivableAmount: Double

    var id: Date { date }
    var netAmount: Double { receivableAmount - owedAmount }
}

struct WeekdayCluster: Identifiable {
    let weekday: String
    let entries: Int

    var id: String { weekday }
}

struct StatisticsSnapshot {
    let summary: StatisticsSummary
    let topPeopleByEntries: [PersonCluster]
    let topPeopleByAmount: [PersonCluster]
    let timeSeries: [TimeSeriesPoint]
    let weekdayClusters: [WeekdayCluster]
}
