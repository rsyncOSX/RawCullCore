import CoreGraphics
import Foundation
import Testing
@testable import RawCullCore

@Suite("HistogramCalculator")
struct HistogramCalculatorTests {
    @Test("Returns 256 normalized bins")
    func returnsNormalizedBins() throws {
        let image = try makeRGBAImage(
            width: 2,
            height: 2,
            pixels: [
                0, 0, 0, 255,
                255, 255, 255, 255,
                255, 0, 0, 255,
                0, 255, 0, 255
            ],
        )

        let histogram = HistogramCalculator.normalizedLuminanceHistogram(from: image)

        #expect(histogram.count == HistogramCalculator.binCount)
        #expect(histogram[0] == 1)
        #expect(histogram[76] == 1)
        #expect(histogram[149] == 1)
        #expect(histogram[255] == 1)
        #expect(histogram.reduce(0, +) == 4)
    }

    @Test("Normalizes repeated luminance values by maximum bin count")
    func normalizesByMaximumBinCount() throws {
        let image = try makeRGBAImage(
            width: 3,
            height: 1,
            pixels: [
                0, 0, 0, 255,
                0, 0, 0, 255,
                255, 255, 255, 255
            ],
        )

        let histogram = HistogramCalculator.normalizedLuminanceHistogram(from: image)

        #expect(histogram[0] == 1)
        #expect(histogram[255] == 0.5)
    }

    @Test("Returns zero histogram for unsupported grayscale image")
    func unsupportedImageReturnsZeroHistogram() throws {
        let image = try makeGrayscaleImage(width: 1, height: 1, pixels: [255])

        let histogram = HistogramCalculator.normalizedLuminanceHistogram(from: image)

        #expect(histogram.count == HistogramCalculator.binCount)
        #expect(histogram.allSatisfy { $0 == 0 })
    }
}

private nonisolated func makeRGBAImage(width: Int, height: Int, pixels: [UInt8]) throws -> CGImage {
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    #expect(pixels.count == height * bytesPerRow)
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))

    return try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent,
    ))
}

private nonisolated func makeGrayscaleImage(width: Int, height: Int, pixels: [UInt8]) throws -> CGImage {
    let bytesPerRow = width
    #expect(pixels.count == height * bytesPerRow)
    let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.genericGrayGamma2_2))

    return try #require(CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent,
    ))
}
