//
//  AppTheme.swift
//  Finance
//
//

import SwiftUI

enum AppPalette {
    static let background = dynamicColor(
        light: UIColor(red: 247 / 255, green: 238 / 255, blue: 214 / 255, alpha: 1),
        dark: UIColor(red: 7 / 255, green: 24 / 255, blue: 38 / 255, alpha: 1)
    )

    static let surface = dynamicColor(
        light: UIColor(red: 255 / 255, green: 249 / 255, blue: 236 / 255, alpha: 1),
        dark: UIColor(red: 16 / 255, green: 43 / 255, blue: 67 / 255, alpha: 1)
    )

    static let surfaceMuted = dynamicColor(
        light: UIColor(red: 244 / 255, green: 235 / 255, blue: 215 / 255, alpha: 1),
        dark: UIColor(red: 23 / 255, green: 58 / 255, blue: 85 / 255, alpha: 1)
    )

    static let navy = dynamicColor(
        light: UIColor(red: 16 / 255, green: 43 / 255, blue: 67 / 255, alpha: 1),
        dark: UIColor(red: 169 / 255, green: 192 / 255, blue: 208 / 255, alpha: 1)
    )

    static let emerald = dynamicColor(
        light: UIColor(red: 8 / 255, green: 122 / 255, blue: 91 / 255, alpha: 1),
        dark: UIColor(red: 45 / 255, green: 214 / 255, blue: 163 / 255, alpha: 1)
    )

    static let mint = dynamicColor(
        light: UIColor(red: 221 / 255, green: 243 / 255, blue: 233 / 255, alpha: 1),
        dark: UIColor(red: 18 / 255, green: 61 / 255, blue: 54 / 255, alpha: 1)
    )

    static let paleNavy = dynamicColor(
        light: UIColor(red: 228 / 255, green: 235 / 255, blue: 240 / 255, alpha: 1),
        dark: UIColor(red: 28 / 255, green: 64 / 255, blue: 88 / 255, alpha: 1)
    )

    static let ochre = dynamicColor(
        light: UIColor(red: 138 / 255, green: 91 / 255, blue: 15 / 255, alpha: 1),
        dark: UIColor(red: 224 / 255, green: 182 / 255, blue: 93 / 255, alpha: 1)
    )

    static let destructive = dynamicColor(
        light: UIColor(red: 139 / 255, green: 42 / 255, blue: 42 / 255, alpha: 1),
        dark: UIColor(red: 224 / 255, green: 110 / 255, blue: 110 / 255, alpha: 1)
    )

    private static func dynamicColor(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

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
        AppPalette.emerald
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
