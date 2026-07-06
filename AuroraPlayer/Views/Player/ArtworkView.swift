//
//  ArtworkView.swift
//  AuroraPlayer
//

import SwiftUI

struct ArtworkView: View {
    let song: Song?
    var cornerRadius: CGFloat = 20

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.clear)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url = song?.artworkURL, let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 16, y: 10)
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Color(hex: "3A3A4A"), Color(hex: "191922")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "music.note")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        )
    }
}

#Preview {
    ArtworkView(song: nil)
        .frame(width: 220)
        .padding()
        .background(Color.black)
}
