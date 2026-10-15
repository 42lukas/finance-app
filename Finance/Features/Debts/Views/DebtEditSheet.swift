//
//  DebtEditSheet.swift
//  Finance
//

import SwiftUI

struct DebtEditSheet: View {
    let item: Item
    let onSave: (
        _ amount: Double,
        _ reason: String?,
        _ category: String,
        _ dueDate: Date?
    ) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var reasonText: String
    @State private var amountText: String
    @State private var dueDate: Date?
    @State private var direction: DebtCategory

    private let originalReason: String
    private let originalAmountCents: Int64
    private let originalDueDate: Date?
    private let originalDirection: DebtCategory

    init(
        item: Item,
        onSave: @escaping (
            _ amount: Double,
            _ reason: String?,
            _ category: String,
            _ dueDate: Date?
        ) -> Void
    ) {
        self.item = item
        self.onSave = onSave

        let calendar = Calendar.current
        let normalizedDueDate = item.dueDate.map { calendar.startOfDay(for: $0) }
        let normalizedReason = InputRules.truncated(
            Self.normalizedReason(item.descriptionText ?? ""),
            to: InputRules.descriptionMaxLength
        )
        let direction = DebtCategory(rawValue: item.category ?? "") ?? .receivable

        originalReason = normalizedReason
        originalAmountCents = InputRules.storedCents(from: item.amount)
        originalDueDate = normalizedDueDate
        originalDirection = direction
        _reasonText = State(initialValue: normalizedReason)
        _amountText = State(initialValue: InputRules.editableMoneyText(for: item.amount))
        _direction = State(initialValue: direction)
        _dueDate = State(initialValue: normalizedDueDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    directionSwitcher

                    editCard(title: "Grund", systemImage: "note.text") {
                        TextField(
                            "Wofür ist der Eintrag?",
                            text: $reasonText,
                            axis: .vertical
                        )
                        .enforcingCharacterLimit(
                            $reasonText,
                            maximumLength: InputRules.descriptionMaxLength
                        )
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .background(AppPalette.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        characterCounter(reasonText, maximumLength: InputRules.descriptionMaxLength)
                    }

                    editCard(title: "Gesamtbetrag", systemImage: "eurosign.circle.fill") {
                        HStack(spacing: 10) {
                            TextField(
                                "0,00",
                                text: $amountText
                            )
                                .keyboardType(.decimalPad)
                                .font(.title3.weight(.semibold))
                                .enforcingCharacterLimit(
                                    $amountText,
                                    maximumLength: InputRules.moneyInputMaxLength
                                )

                            Text("€")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppPalette.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Label(
                            "Bereits bezahlt: \(item.effectivePaidAmount.formatted(.currency(code: "EUR")))",
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(AppPalette.emerald)
                    }

                    cardContainer {
                        DueDateEditor(dueDate: $dueDate)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppPalette.background.ignoresSafeArea())
            .navigationTitle("Eintrag bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var enteredAmountCents: Int64? {
        if amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           originalAmountCents == 0 {
            return 0
        }
        return InputRules.cents(fromMoneyInput: amountText)
    }

    private var editedDueDate: Date? {
        dueDate.map { Calendar.current.startOfDay(for: $0) }
    }

    private var editedReason: String {
        Self.normalizedReason(reasonText)
    }

    private var canSave: Bool {
        guard let enteredAmountCents else { return false }

        let isAmountValid = enteredAmountCents >= InputRules.storedCents(from: item.effectivePaidAmount)
        let directionChanged = direction != originalDirection
        let reasonChanged = editedReason != originalReason
        let amountChanged = enteredAmountCents != originalAmountCents
        let dueDateChanged = editedDueDate != originalDueDate

        return isAmountValid && (directionChanged || reasonChanged || amountChanged || dueDateChanged)
    }

    private func save() {
        guard canSave, let enteredAmountCents else { return }
        onSave(
            InputRules.amount(fromCents: enteredAmountCents),
            InputRules.normalizedOptionalText(
                editedReason,
                maximumLength: InputRules.descriptionMaxLength
            ),
            direction.rawValue,
            editedDueDate
        )
        dismiss()
    }

    private var otherPersonName: String {
        let person = (item.person ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return person.isEmpty ? "Andere Person" : person
    }

    private var sourceName: String {
        direction == .receivable ? otherPersonName : "Ich"
    }

    private var destinationName: String {
        direction == .receivable ? "Ich" : otherPersonName
    }

    private var directionSwitcher: some View {
        ZStack(alignment: .trailing) {
            VStack(spacing: 0) {
                directionPartyRow(
                    label: "Von",
                    name: sourceName,
                    isCurrentUser: direction == .payable
                )

                Divider()
                    .overlay(AppPalette.navy.opacity(0.10))
                    .padding(.leading, 56)
                    .padding(.trailing, 62)

                directionPartyRow(
                    label: "An",
                    name: destinationName,
                    isCurrentUser: direction == .receivable
                )
            }
            .padding(.vertical, 3)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                withAnimation(.snappy(duration: 0.22)) {
                    direction.toggle()
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.headline.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(AppPalette.mint)
                    .foregroundStyle(AppPalette.emerald)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 14)
            .accessibilityLabel("Richtung wechseln")
            .accessibilityHint("Wechselt zwischen bekommen und schulden")
        }
    }

    private func directionPartyRow(
        label: String,
        name: String,
        isCurrentUser: Bool
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isCurrentUser ? "person.crop.circle.fill" : "person.circle.fill")
                .font(.title3)
                .foregroundStyle(isCurrentUser ? AppPalette.emerald : AppPalette.navy)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 10)
        .padding(.trailing, 58)
    }

    private func editCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.navy)

                content()
            }
        }
    }

    private func cardContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func characterCounter(_ text: String, maximumLength: Int) -> some View {
        Text("\(text.count)/\(maximumLength)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private static func normalizedReason(_ reason: String) -> String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
