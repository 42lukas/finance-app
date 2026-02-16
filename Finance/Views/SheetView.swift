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

    private let nums = [0.01, 0.10, 1.00, 10.00]
    @State private var selectedNum: Double = 1.00

    private let categories = ["bekomme ich", "schulde ich"]
    @State private var selectedCategory: String = "bekomme ich"

    @State private var textFieldPerson: String = ""
    @State private var textFieldDescription: String = ""

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
            ScrollView {
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
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
            TextField("Betrag in €", text: $manualAmountText)
                .keyboardType(.decimalPad)
            Button("Abbrechen", role: .cancel) {}
            Button("Übernehmen") {
                applyManualAmount()
            }
        } message: {
            Text("Long-Press erkannt. Bitte Betrag eingeben.")
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
                .onLongPressGesture {
                    manualAmountText = String(format: "%.2f", amount)
                    showManualAmountAlert = true
                }

            Text("Long Press auf den Betrag, um ihn direkt einzugeben.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 14)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(colorScheme == .dark ? 0.35 : 0.20),
                    Color.cyan.opacity(colorScheme == .dark ? 0.20 : 0.12)
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
                Label("Schrittweite", systemImage: "dial.medium")
                    .font(.subheadline.weight(.semibold))

                Picker("Betragsschritt", selection: $selectedNum) {
                    ForEach(nums, id: \.self) { num in
                        Text("\(String(format: "%.2f", num))€").tag(num)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    amountActionButton(
                        title: "-\(String(format: "%.2f", selectedNum))€",
                        systemImage: "minus.circle.fill",
                        tint: .red
                    ) {
                        decreaseAmount(dec: selectedNum)
                    }

                    amountActionButton(
                        title: "+\(String(format: "%.2f", selectedNum))€",
                        systemImage: "plus.circle.fill",
                        tint: .green
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

                fieldRow(icon: "person.fill", placeholder: "Person", text: $textFieldPerson)
                    .focused($focusedField, equals: .person)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)

                if shouldShowPersonSuggestions {
                    personSuggestionList
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                fieldRow(icon: "note.text", placeholder: "Beschreibung", text: $textFieldDescription)
                    .focused($focusedField, equals: .description)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Kategorie", systemImage: "tag.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Kategorie", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(.segmented)
                }
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
                    textFieldPerson = suggestion
                    focusedField = .description
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.blue)
                        Text(suggestion)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var backgroundLayer: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground).opacity(colorScheme == .dark ? 0.34 : 0.72)
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
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
            .background(Color(.secondarySystemBackground))
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

    private func normalizedPersonName(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func increaseAmount(inc: Double) {
        amount += inc
    }

    func decreaseAmount(dec: Double) {
        amount = max(0, amount - dec)
    }

    private func applyManualAmount() {
        let normalized = manualAmountText
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let newAmount = Double(normalized) else { return }
        amount = max(0, newAmount)
    }
    
    private func addItem() {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.amount = amount
            newItem.isArchived = false
            newItem.paidAmount = 0
            newItem.partialPaymentsData = nil
            newItem.category = selectedCategory
            newItem.person = textFieldPerson.trimmingCharacters(in: .whitespacesAndNewlines)
            newItem.descriptionText = textFieldDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}


#Preview {
    SheetView(showSheet: .constant(true))
}
