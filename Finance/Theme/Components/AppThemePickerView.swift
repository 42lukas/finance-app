//
//  AppThemePickerView.swift
//  Finance
//
//

import SwiftUI

struct AppThemePickerView: View {
    @Binding var selectedTheme: AppTheme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppTheme.allCases) { theme in
                Button {
                    selectedTheme = theme
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: theme.systemImage)
                            .font(.headline)
                        Text(theme.title)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(themeBackground(for: theme))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(themeBorderColor(for: theme), lineWidth: selectedTheme == theme ? 1.5 : 1)
                    }
                    .foregroundStyle(selectedTheme == theme ? theme.accentColor : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func themeBackground(for theme: AppTheme) -> some ShapeStyle {
        if selectedTheme == theme {
            return AnyShapeStyle(theme.accentColor.opacity(0.16))
        }
        return AnyShapeStyle(Color(.tertiarySystemBackground))
    }

    private func themeBorderColor(for theme: AppTheme) -> Color {
        selectedTheme == theme ? theme.accentColor.opacity(0.45) : Color(.separator).opacity(0.2)
    }
}
