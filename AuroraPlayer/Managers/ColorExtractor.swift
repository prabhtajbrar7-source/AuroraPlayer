//
//  ColorExtractor.swift
//  AuroraPlayer
//
//  Extracts a small palette (dominant + accent + shadow) from album artwork,
//  so the Now Playing screen's background gradient always matches the art —
//  the "dynamic artwork colors" feature, done with a real (if lightweight)
//  color-quantization pass rather than just reading the 4 corner pixels.
//

import UIKit
import SwiftUI

struct ArtworkPalette: Equatable {
    let dominant: Color
    let accent: Color
    let shadow: Color

    static let placeholder = ArtworkPalette(
        dominant: Color(hex: "3A3A4A"),
        accent: Color(hex: "7F5AF0"),
        shadow: Color(hex: "111116")
    )
}

enum ColorExtractor {
    /// Downsamples the image aggressively (to ~24x24) then buckets pixels into
    /// coarse color cells, picking the most common bucket as "dominant" and the
    /// most saturated frequent bucket as "accent". This runs in well under a
    /// millisecond even on large artwork thanks to the downsample step.
    static func extractPalette(from image: UIImage) -> ArtworkPalette {
        guard let pixels = downsampledPixels(image, targetSize: 24) else { return .placeholder }

        var buckets: [UInt32: (count: Int, r: Int, g: Int, b: Int)] = [:]
        for pixel in pixels {
            let r = Int((pixel >> 24) & 0xFF)
            let g = Int((pixel >> 16) & 0xFF)
            let b = Int((pixel >> 8) & 0xFF)
            // Quantize to steps of 32 per channel to group similar colors together.
            let key = UInt32((r / 32) << 16 | (g / 32) << 8 | (b / 32))
            var bucket = buckets[key] ?? (0, 0, 0, 0)
            bucket.count += 1
            bucket.r += r
            bucket.g += g
            bucket.b += b
            buckets[key] = bucket
        }

        guard !buckets.isEmpty else { return .placeholder }

        let sorted = buckets.values.sorted { $0.count > $1.count }
        let dominantBucket = sorted[0]
        let dominant = averageColor(dominantBucket)

        // Accent = most saturated color among the top 6 most frequent buckets,
        // so the gradient has some life instead of collapsing to muddy gray.
        let topBuckets = sorted.prefix(6)
        let accentBucket = topBuckets.max { lhs, rhs in
            saturation(of: averageColor(lhs)) < saturation(of: averageColor(rhs))
        } ?? dominantBucket
        let accent = averageColor(accentBucket)

        return ArtworkPalette(
            dominant: dominant,
            accent: accent,
            shadow: darken(dominant, by: 0.65)
        )
    }

    private static func averageColor(_ bucket: (count: Int, r: Int, g: Int, b: Int)) -> Color {
        Color(
            red: Double(bucket.r / bucket.count) / 255.0,
            green: Double(bucket.g / bucket.count) / 255.0,
            blue: Double(bucket.b / bucket.count) / 255.0
        )
    }

    private static func saturation(of color: Color) -> Double {
        let ui = UIColor(color)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(s)
    }

    private static func darken(_ color: Color, by amount: Double) -> Color {
        let ui = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return Color(red: r * (1 - amount), green: g * (1 - amount), blue: b * (1 - amount))
    }

    /// Renders the image into a tiny RGBA8 bitmap and returns each pixel packed
    /// as 0xRRGGBBAA, so the caller never touches raw CGContext/bitmap details.
    private static func downsampledPixels(_ image: UIImage, targetSize: Int) -> [UInt32]? {
        let size = CGSize(width: targetSize, height: targetSize)
        guard let cgImage = image.cgImage else { return nil }

        var pixelData = [UInt8](repeating: 0, count: targetSize * targetSize * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(origin: .zero, size: size))

        var result: [UInt32] = []
        result.reserveCapacity(targetSize * targetSize)
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = UInt32(pixelData[i])
            let g = UInt32(pixelData[i + 1])
            let b = UInt32(pixelData[i + 2])
            let a = UInt32(pixelData[i + 3])
            result.append((r << 24) | (g << 16) | (b << 8) | a)
        }
        return result
    }
}
