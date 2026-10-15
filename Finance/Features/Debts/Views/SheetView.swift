//
//  SheetView.swift
//  Finance
//
//

import SwiftUI
import CoreData

struct SheetView: View {
    private enum FocusField {
        case person
        case description
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)],
        animation: .default)
    private var items: FetchedResults<Item>

    @Binding var showSheet: Bool
    @FocusState private var focusedField: FocusField?

    @State private var amount: Double = 0
    @State private var showManualAmountAlert: Bool = false
    @State private var manualAmountText: String = ""

    private let nums = [1.00, 5.00, 10.00, 50.00]
    @State private var selectedNum: Double = 10.00

    @State private var selectedCategory: DebtCategory = .receivable

    @State private var textFieldPerson: String = ""
    @State private var textFieldDescription: String = ""
    @State private var dueDate: Date?

    private var normalizedPerson: String {
        InputRules.normalizedPerson(textFieldPerson)
    }

    private var amountCents: Int64 {
        InputRules.storedCents(from: amount)
    }

    private var canSaveEntry: Bool {
        !normalizedPerson.isEmpty
            && (InputRules.minimumAmountCents...InputRules.maximumAmountCents).contains(amountCents)
    }

    private var personSuggestions: [String] {
        let query = normalizedPersonName(textFieldPerson)
        guard !query.isEmpty else { return [] }

        let matches = existingPersonNames.filter {
            normalizedPersonName($0).hasPrefix(query)
        }

        return Array(matches.prefix(6))
    }

    private var shouldShowPersonSuggestions: Bool {
        focusedField == .person
        && !textFieldPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !personSuggestions.isEmpty
    }

    private var existingPersonNames: [String] {
        var seen: Set<String> = []
        var names: [String] = []

        for item in items {
            let trimmed = (item.person ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let normalized = normalizedPersonName(trimmed)
            guard !seen.contains(normalized) else { continue }

            seen.insert(normalized)
            names.append(trimmed)
        }

        return names
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    amountCard
                    incrementCard
                    detailsCard

                    Button {
                        addItem()
                        showSheet = false
                    } label: {
                        Label("Eintrag speichern", systemImage: "checkmark.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppPalette.emerald)
                            .foregroundStyle(AppPalette.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSaveEntry)
                    .opacity(canSaveEntry ? 1 : 0.55)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(backgroundLayer.ignoresSafeArea())
            .navigationTitle("Neuer Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSheet = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .alert("Betrag manuell eingeben", isPresented: $showManualAmountAlert) {
            TextField(
                "Betrag in €",
                text: $manualAmountText
            )
                .keyboardType(.decimalPad)
                .enforcingCharacterLimit(
                    $manualAmountText,
                    maximumLength: InputRules.moneyInputMaxLength
                )
            Button("Abbrechen", role: .cancel) {}
            Button("Übernehmen") {
                applyManualAmount()
            }
            .disabled(InputRules.cents(fromMoneyInput: manualAmountText) == nil)
        }
    }

    private var amountCard: some View {
        VStack(spacing: 10) {
            Label("Aktueller Betrag", systemImage: "eurosign.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(currencyText(amount))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(amount > 0 ? .primary : .secondary)
                .contentTransition(.numericText(value: amount))
                .onTapGesture {
                    presentManualAmountEntry()
                }
                .onLongPressGesture {
                    presentManualAmountEntry()
                }

            Text("Tippen für freie Eingabe")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                colors: [
                    AppPalette.mint,
                    AppPalette.paleNavy.opacity(colorScheme == .dark ? 0.75 : 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var incrementCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Betrag anpassen", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))

                Picker("Betragsschritt", selection: $selectedNum) {
                    ForEach(nums, id: \.self) { num in
                        Text(stepAmountText(num)).tag(num)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    amountActionButton(
                        title: "−\(stepAmountText(selectedNum))",
                        systemImage: "minus.circle.fill",
                        tint: AppPalette.navy
                    ) {
                        decreaseAmount(dec: selectedNum)
                    }

                    amountActionButton(
                        title: "+\(stepAmountText(selectedNum))",
                        systemImage: "plus.circle.fill",
                        tint: AppPalette.emerald
                    ) {
                        increaseAmount(inc: selectedNum)
                    }
                }
            }
        }
    }

    private var detailsCard: some View {
        cardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Label("Eintragsdetails", systemImage: "text.badge.plus")
                    .font(.subheadline.weight(.semibold))

                VStack(alignment: .trailing, spacing: 4) {
                    fieldRow(
                        icon: "person.fill",
                        placeholder: "Person",
                        text: $textFieldPerson
                    )
                    .enforcingCharacterLimit(
                        $textFieldPerson,
                        maximumLength: InputRules.personMaxLength
                    )
                    .focused($focusedField, equals: .person)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)

                    characterCounter(textFieldPerson, maximumLength: InputRules.personMaxLength)
                }

                if shouldShowPersonSuggestions {
                    personSuggestionList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(alignment: .trailing, spacing: 4) {
                    fieldRow(
                        icon: "note.text",
                        placeholder: "Beschreibung",
                        text: $textFieldDescription
                    )
                    .enforcingCharacterLimit(
                        $textFieldDescription,
                        maximumLength: InputRules.descriptionMaxLength
                    )
                    .focused($focusedField, equals: .description)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)

                    characterCounter(textFieldDescription, maximumLength: InputRules.descriptionMaxLength)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label("Kategorie", systemImage: "tag.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Kategorie", selection: $selectedCategory) {
                        ForEach(DebtCategory.allCases) { category in
                            Text(category.title).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider()
                    .overlay(AppPalette.navy.opacity(0.10))

                DueDateEditor(dueDate: $dueDate)
            }
            .animation(.snappy(duration: 0.22, extraBounce: 0.01), value: shouldShowPersonSuggestions)
        }
    }

    private var personSuggestionList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Vorschläge")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(personSuggestions, id: \.self) { suggestion in
                Button {
                    textFieldPerson = InputRules.truncated(
                        suggestion,
                        to: InputRules.personMaxLength
                    )
                    focusedField = .description
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(AppPalette.emerald)
                        Text(suggestion)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(AppPalette.surfaceMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                AppPalette.background,
                AppPalette.surfaceMuted.opacity(colorScheme == .dark ? 0.58 : 0.82)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func fieldRow(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            TextField(placeholder, text: text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(AppPalette.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func characterCounter(_ text: String, maximumLength: Int) -> some View {
        Text("\(text.count)/\(maximumLength)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private func amountActionButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(tint.opacity(0.14))
                .foregroundStyle(tint)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func cardContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func currencyText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "EUR"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber) ?? String(format: "%.2f €", value)
    }

    private func stepAmountText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) €"
    }

    private func normalizedPersonName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func increaseAmount(inc: Double) {
        let incrementCents = InputRules.storedCents(from: inc)
        amount = InputRules.amount(
            fromCents: min(amountCents + incrementCents, InputRules.maximumAmountCents)
        )
    }

    func decreaseAmount(dec: Double) {
        let decrementCents = InputRules.storedCents(from: dec)
        amount = InputRules.amount(fromCents: max(amountCents - decrementCents, 0))
    }

    private func applyManualAmount() {
        guard let cents = InputRules.cents(fromMoneyInput: manualAmountText) else { return }
        amount = InputRules.amount(fromCents: cents)
    }

    private func presentManualAmountEntry() {
        manualAmountText = InputRules.editableMoneyText(for: amount)
        showManualAmountAlert = true
    }
    
    private func addItem() {
        guard canSaveEntry else { return }

        let shouldRequestNotificationAuthorization = dueDate != nil
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.id = UUID()
            newItem.timestamp = Date()
            newItem.amount = InputRules.amount(fromCents: amountCents)
            newItem.isArchived = false
            newItem.paidAmount = 0
            newItem.partialPaymentsData = nil
            newItem.dueDate = dueDate.map { Calendar.current.startOfDay(for: $0) }
            newItem.category = selectedCategory.rawValue
            newItem.person = normalizedPerson
            newItem.descriptionText = InputRules.normalizedOptionalText(
                textFieldDescription,
                maximumLength: InputRules.descriptionMaxLength
            )
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }

        Task {
            await DueDateNotificationScheduler.shared.reschedule(
                requestAuthorization: shouldRequestNotificationAuthorization
            )
        }
    }
}


#Preview {
    SheetView(showSheet: .constant(true))
}
