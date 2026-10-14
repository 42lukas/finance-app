//
//  DueDateEditor.swift
//  Finance
//

import SwiftUI

struct DueDateEditor: View {
    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $hasDueDate.animation(.snappy(duration: 0.2))) {
                Label("Fälligkeitsdatum", systemImage: "calendar.badge.clock")
                    .font(.subheadline.weight(.semibold))
            }
            .tint(AppPalette.emerald)

            if hasDueDate {
                DatePicker(
                    "Fällig am",
                    selection: $dueDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .font(.subheadline)
            } else {
                Text("Keine Erinnerung für diesen Eintrag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
