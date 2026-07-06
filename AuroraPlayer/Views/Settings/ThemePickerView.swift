//
//  ThemePickerView.swift
//  AuroraPlayer
//

import SwiftUI

struct ThemePickerView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(AppTheme.all) { option in
                    swatch(for: option)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func swatch(for option: AppTheme) -> some View {
        let isSelected = option.id == theme.current.id
        return Button {
            theme.select(option)
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [option.accentColor, option.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(.white, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: option.accentColor.opacity(0.5), radius: isSelected ? 8 : 0)

                Text(option.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
