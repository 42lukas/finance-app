//
//  FinanceAppShortcuts.swift
//  Finance
//
//

import AppIntents

struct FinanceAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddIOweDebtEntryIntent(),
            phrases: [
                "Ich schulde in \(.applicationName)",
                "Neuer Schuldeneintrag in \(.applicationName)"
            ],
            shortTitle: "Ich schulde",
            systemImageName: "arrow.up.circle.fill"
        )
        AppShortcut(
            intent: AddIGetBackDebtEntryIntent(),
            phrases: [
                "Ich bekomme in \(.applicationName)",
                "Neuer Guthaben Eintrag in \(.applicationName)"
            ],
            shortTitle: "Ich bekomme",
            systemImageName: "arrow.down.circle.fill"
        )
    }

    static var shortcutTileColor: ShortcutTileColor = .teal
}
