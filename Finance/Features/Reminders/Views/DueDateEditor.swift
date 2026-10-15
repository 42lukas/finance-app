//
//  DueDateEditor.swift
//  Finance
//

import SwiftUI

struct DueDateEditor: View {
    @Binding var dueDate: Date?

    private var hasDueDate: Binding<Bool> {
        Binding {
            dueDate != nil
        } set: { isEnabled in
            if isEnabled {
                dueDate = dueDate
                    ?? Calendar.current.date(byAdding: .day, value: 7, to: Date())
                    ?? Date()
            } else {
                dueDate = nil
            }
        }
    }

    private var selectedDate: Binding<Date> {
        Binding {
            dueDate ?? Date()
        } set: { newDate in
            dueDate = newDate
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: hasDueDate.animation(.snappy(duration: 0.2))) {
                Label("Fälligkeit", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(AppPalette.emerald)

            if dueDate != nil {
                DatePicker(
                    "Datum",
                    selection: selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(.subheadline)
            } else {
                Text("Kein Termin gesetzt")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
