//
//  DueDateLabel.swift
//  Finance
//

import SwiftUI

struct DueDateLabel: View {
    let dueDate: Date
    var isCompleted: Bool = false

    private var calendar: Calendar { .current }

    private var startOfDueDate: Date {
        calendar.startOfDay(for: dueDate)
    }

    private var startOfToday: Date {
        calendar.startOfDay(for: Date())
    }

    private var dayDifference: Int {
        calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate).day ?? 0
    }

    private var labelText: String {
        if isCompleted {
            return "Fällig am \(formattedDate)"
        }

        switch dayDifference {
        case ..<0:
            let days = abs(dayDifference)
            return days == 1 ? "Seit 1 Tag überfällig" : "Seit \(days) Tagen überfällig"
        case 0:
            return "Heute fällig"
        case 1:
            return "Morgen fällig"
        default:
            return "Fällig am \(formattedDate)"
        }
    }

    private var formattedDate: String {
        dueDate.formatted(.dateTime.day().month().year())
    }

    private var tint: Color {
        guard !isCompleted else { return .secondary }
        return dayDifference <= 0 ? AppPalette.ochre : .secondary
    }

    var body: some View {
        Label(labelText, systemImage: dayDifference < 0 && !isCompleted ? "exclamationmark.circle.fill" : "calendar.badge.clock")
            .font(.caption.weight(dayDifference <= 0 && !isCompleted ? .semibold : .regular))
            .foregroundStyle(tint)
    }
}
