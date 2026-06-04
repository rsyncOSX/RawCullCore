import CoreGraphics
import Foundation

public nonisolated enum HistogramCalculator {
    public nonisolated static let binCount = 256

    /// Builds a normalized 256-bin luminance histogram from an RGB(A)
    /// 8-bit-per-channel image.
    public nonisolated static func normalizedLuminanceHistogram(from image: CGImage) -> [CGFloat] {
        guard image.width > 0,
              image.height > 0,
              let pixelData = image.dataProvider?.data,
              let data = CFDataGetBytePtr(pixelData),
              image.bitsPerComponent == 8
        else {
            return zeroHistogram()
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return zeroHistogram() }

        var bins = [UInt](repeating: 0, count: binCount)

        for y in 0 ..< image.height {
            for x in 0 ..< image.width {
                let pixelOffset = (y * image.bytesPerRow) + (x * bytesPerPixel)
                let red = CGFloat(data[pixelOffset])
                let green = CGFloat(data[pixelOffset + 1])
                let blue = CGFloat(data[pixelOffset + 2])
                let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                let index = min(max(Int(luminance), 0), binCount - 1)
                bins[index] += 1
            }
        }

        guard let maxCount = bins.max(), maxCount > 0 else {
            return zeroHistogram()
        }
        return bins.map { CGFloat($0) / CGFloat(maxCount) }
    }

    private nonisolated static func zeroHistogram() -> [CGFloat] {
        Array(repeating: 0, count: binCount)
    }
}
