//
//  AddDebtEntryIntents.swift
//  Finance
//
//

import AppIntents
import Foundation

struct AddIOweDebtEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Schuldeneintrag (Ich schulde)"
    static var description = IntentDescription("Legt einen neuen Eintrag an: Ich schulde jemandem Geld.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Betrag in Euro", requestValueDialog: IntentDialog("Wie hoch ist der Betrag in Euro?"))
    var amount: Double

    @Parameter(title: "Person", requestValueDialog: IntentDialog("Fuer welche Person ist der Eintrag?"))
    var person: String

    @Parameter(title: "Grund", default: "", requestValueDialog: IntentDialog("Was ist der Grund?"))
    var reason: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ich schulde \(\.$amount) Euro an \(\.$person) wegen \(\.$reason)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await DebtEntryCreationService().createEntry(
                amount: amount,
                category: .iOwe,
                person: person,
                reason: reason
            )

            return .result(dialog: IntentDialog("Eintrag erstellt."))
        } catch let error as DebtEntryCreationError {
            switch error {
            case .invalidAmount:
                return .result(dialog: IntentDialog("Der Betrag muss größer als 0 Euro sein."))
            case .emptyPerson:
                return .result(dialog: IntentDialog("Bitte gib eine Person an."))
            }
        } catch {
            return .result(dialog: IntentDialog("Eintrag konnte nicht erstellt werden."))
        }
    }
}

struct AddIGetBackDebtEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Schuldeneintrag (Ich bekomme)"
    static var description = IntentDescription("Legt einen neuen Eintrag an: Ich bekomme Geld von jemandem.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Betrag in Euro", requestValueDialog: IntentDialog("Wie hoch ist der Betrag in Euro?"))
    var amount: Double

    @Parameter(title: "Person", requestValueDialog: IntentDialog("Fuer welche Person ist der Eintrag?"))
    var person: String

    @Parameter(title: "Grund", default: "", requestValueDialog: IntentDialog("Was ist der Grund?"))
    var reason: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ich bekomme \(\.$amount) Euro von \(\.$person) wegen \(\.$reason)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await DebtEntryCreationService().createEntry(
                amount: amount,
                category: .iGetBack,
                person: person,
                reason: reason
            )

            return .result(dialog: IntentDialog("Eintrag erstellt."))
        } catch let error as DebtEntryCreationError {
            switch error {
            case .invalidAmount:
                return .result(dialog: IntentDialog("Der Betrag muss größer als 0 Euro sein."))
            case .emptyPerson:
                return .result(dialog: IntentDialog("Bitte gib eine Person an."))
            }
        } catch {
            return .result(dialog: IntentDialog("Eintrag konnte nicht erstellt werden."))
        }
    }
}
