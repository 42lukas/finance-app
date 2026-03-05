//
//  AppTheme.swift
//  Finance
//
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Hell"
        case .dark:
            return "Dunkel"
        }
    }

    var systemImage: String {
        switch self {
        case .system:
            return "gearshape.2.fill"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .system:
            return .indigo
        case .light:
            return .orange
        case .dark:
            return .blue
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

@MainActor
final class ThemeManager: ObservableObject {
    private static let storageKey = "finance_app_theme"

    @Published var selectedTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
        }
    }

    init() {
        let savedRawValue = UserDefaults.standard.string(forKey: Self.storageKey)
        self.selectedTheme = AppTheme(rawValue: savedRawValue ?? "") ?? .system
    }
}
