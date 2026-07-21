import Foundation
@testable import RawCullCore
import Testing

@Suite("RawCullCore models")
struct RawCullCoreModelTests {
    @Test
    func `ExifMetadata is codable and hashable`() throws {
        let metadata = ExifMetadata(
            shutterSpeed: "1/1000",
            exposureTimeSeconds: 0.001,
            focalLength: "600.0mm",
            focalLengthMM: 600,
            aperture: "ƒ/5.6",
            apertureValue: 5.6,
            iso: "ISO 800",
            isoValue: 800,
            exposureCompensationEV: -0.3,
            camera: "ILCE-1",
            lensModel: "FE 600mm F4 GM OSS",
            rawFileType: "Lossless Compressed",
            rawSizeClass: "L",
            pixelWidth: 8640,
            pixelHeight: 5760,
        )

        let data = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(ExifMetadata.self, from: data)

        #expect(decoded == metadata)
        #expect(Set([metadata, decoded]).count == 1)
    }

    @Test
    func `RawCullFileItem identity equality is keyed by id`() {
        let id = UUID()
        let first = RawCullFileItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/one.ARW"),
            name: "one.ARW",
            size: 100,
            dateModified: Date(timeIntervalSince1970: 1),
            captureDate: Date(timeIntervalSince1970: 0.5),
            captureTimeZoneOffsetSeconds: 7_200,
            exifData: nil,
            afFocusNormalized: nil,
        )
        let second = RawCullFileItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/two.ARW"),
            name: "two.ARW",
            size: 200,
            dateModified: Date(timeIntervalSince1970: 2),
            exifData: nil,
            afFocusNormalized: nil,
        )

        #expect(first == second)
        #expect(Set([first, second]).count == 1)
        #expect(first.formattedSize.isEmpty == false)
    }

    @Test
    func `RawCullFileItem decodes legacy data without a capture date`() throws {
        let id = UUID()
        let legacyJSON = """
        {
          "id": "\(id.uuidString)",
          "url": "file:///tmp/legacy.ARW",
          "name": "legacy.ARW",
          "size": 100,
          "dateModified": 1000,
          "exifData": null,
          "afFocusNormalized": null
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let item = try decoder.decode(RawCullFileItem.self, from: Data(legacyJSON.utf8))

        #expect(item.captureDate == nil)
        #expect(item.captureTimeZoneOffsetSeconds == nil)
        #expect(item.effectiveCaptureDate == item.dateModified)
        #expect(item.usesFileModificationDateForCaptureTime)
    }

    @Test
    func `Legacy grouping config decodes new tolerance defaults`() throws {
        let legacyJSON = """
        {
          "visualDistanceThreshold": 0.2,
          "maxTimeGapSeconds": 2,
          "requireSameCamera": true,
          "requireSimilarFocalLength": true,
          "maxFocalLengthDeltaMM": 3
        }
        """

        let config = try JSONDecoder().decode(BurstGroupingConfig.self, from: Data(legacyJSON.utf8))

        #expect(config.visualDistanceThreshold == 0.2)
        #expect(config.maxFallbackTimeGapSeconds == 10)
        #expect(config.maxShutterSpeedDeltaEV == 0.5)
        #expect(config.maxExposureCompensationDeltaEV == 0.34)
    }

    @Test
    func `RawCullSourceCatalog stores source identity and URL`() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/catalog")
        let catalog = RawCullSourceCatalog(id: id, name: "Catalog", url: url)

        #expect(catalog.id == id)
        #expect(catalog.name == "Catalog")
        #expect(catalog.url == url)
    }
}
