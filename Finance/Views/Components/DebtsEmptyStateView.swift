//
//  DebtsEmptyStateView.swift
//  Finance
//
//

import SwiftUI

struct DebtsEmptyStateView: View {
    let onCreateEntry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Noch keine Einträge")
                        .font(.headline)
                    Text("Lege deinen ersten Schulden- oder Forderungseintrag an.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: onCreateEntry) {
                    Label("Eintrag erstellen", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundStyle(Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                VStack(spacing: 12) {
                    skeletonDebtCard
                    skeletonDebtCard
                    skeletonDebtCard
                }
                .padding(.top, 6)
            }
            .padding()
        }
    }

    private var skeletonDebtCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: 130, height: 14)

            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(height: 12)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(height: 48)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(height: 48)
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(height: 48)
            }

            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray5))
                .frame(height: 40)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
