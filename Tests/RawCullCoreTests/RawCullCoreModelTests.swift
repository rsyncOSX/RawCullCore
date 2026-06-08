import Foundation
@testable import RawCullCore
import Testing

@Suite("RawCullCore models")
struct RawCullCoreModelTests {
    @Test
    func `ExifMetadata is codable and hashable`() throws {
        let metadata = ExifMetadata(
            shutterSpeed: "1/1000",
            focalLength: "600.0mm",
            aperture: "ƒ/5.6",
            apertureValue: 5.6,
            iso: "ISO 800",
            isoValue: 800,
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
    func `RawCullSourceCatalog stores source identity and URL`() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/catalog")
        let catalog = RawCullSourceCatalog(id: id, name: "Catalog", url: url)

        #expect(catalog.id == id)
        #expect(catalog.name == "Catalog")
        #expect(catalog.url == url)
    }
}
