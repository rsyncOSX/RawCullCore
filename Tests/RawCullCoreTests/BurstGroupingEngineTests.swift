import CoreGraphics
import Foundation
@testable import RawCullCore
import Testing

@Suite("BurstGroupingEngine")
struct BurstGroupingEngineTests {
    @Test
    func `Empty file list returns no groups or evidence`() {
        let output = BurstGroupingEngine.group(
            files: [],
            adjacentDistances: [:],
            config: BurstGroupingConfig(),
        )

        #expect(output.groups.isEmpty)
        #expect(output.boundaryEvidence.isEmpty)
    }

    @Test
    func `Low visual distance and stable metadata keeps files in one burst`() throws {
        let files = [
            makeBurstFile(name: "one.ARW", seconds: 0),
            makeBurstFile(name: "two.ARW", seconds: 1),
            makeBurstFile(name: "three.ARW", seconds: 2)
        ]
        let distances = [
            BurstPairKey.cacheKey(previousID: files[0].id, currentID: files[1].id): Float(0.10),
            BurstPairKey.cacheKey(previousID: files[1].id, currentID: files[2].id): Float(0.15)
        ]

        let output = BurstGroupingEngine.group(
            files: files,
            adjacentDistances: distances,
            config: BurstGroupingConfig(),
        )

        let group = try #require(output.groups.first)
        #expect(output.groups.count == 1)
        #expect(group.fileIDs == files.map(\.id))
        #expect(output.boundaryEvidence.allSatisfy { !$0.startsNewGroup })
    }

    @Test
    func `Missing similarity evidence starts a new group`() throws {
        let files = [
            makeBurstFile(name: "one.ARW", seconds: 0),
            makeBurstFile(name: "two.ARW", seconds: 1)
        ]

        let output = BurstGroupingEngine.group(
            files: files,
            adjacentDistances: [:],
            config: BurstGroupingConfig(),
        )

        #expect(output.groups.map(\.fileIDs) == [[files[0].id], [files[1].id]])
        let evidence = try #require(output.boundaryEvidence.first)
        #expect(evidence.startsNewGroup)
        #expect(evidence.reasons == ["Similarity evidence missing"])
    }

    @Test
    func `Metadata and capture changes are recorded as boundary evidence`() throws {
        let previous = makeBurstFile(
            name: "one.ARW",
            seconds: 0,
            exif: makeExif(shutterSpeed: "1/1000", focalLength: "400.0mm", apertureValue: 5.6, isoValue: 800, camera: "A", lens: "L"),
        )
        let current = makeBurstFile(
            name: "two.ARW",
            seconds: 5,
            exif: makeExif(shutterSpeed: "1/2000", focalLength: "500.0mm", apertureValue: 8.0, isoValue: 1600, camera: "B", lens: "L"),
        )
        let key = BurstPairKey.cacheKey(previousID: previous.id, currentID: current.id)

        let output = BurstGroupingEngine.group(
            files: [previous, current],
            adjacentDistances: [key: 0.10],
            config: BurstGroupingConfig(),
        )

        let evidence = try #require(output.boundaryEvidence.first)
        #expect(evidence.startsNewGroup)
        #expect(evidence.timeGapSeconds == 5)
        #expect(evidence.focalLengthDelta == 100)
        #expect(evidence.exposureChanged)
        #expect(evidence.cameraChanged)
        #expect(!evidence.lensChanged)
        #expect(evidence.reasons.contains("Capture gap"))
        #expect(evidence.reasons.contains("Camera changed"))
        #expect(evidence.reasons.contains("Focal length changed"))
        #expect(evidence.reasons.contains("Exposure changed"))
    }
}

nonisolated func makeBurstFile(
    id: UUID = UUID(),
    name: String,
    seconds: TimeInterval,
    exif: ExifMetadata? = makeExif(),
    afPoint: CGPoint? = CGPoint(x: 0.5, y: 0.5),
) -> RawCullFileItem {
    RawCullFileItem(
        id: id,
        url: URL(fileURLWithPath: "/tmp/\(name)"),
        name: name,
        size: 100,
        dateModified: Date(timeIntervalSince1970: seconds),
        exifData: exif,
        afFocusNormalized: afPoint,
    )
}

nonisolated func makeExif(
    shutterSpeed: String? = "1/1000",
    focalLength: String? = "400.0mm",
    apertureValue: Double? = 5.6,
    isoValue: Int? = 800,
    camera: String? = "ILCE-1",
    lens: String? = "FE 400mm",
) -> ExifMetadata {
    ExifMetadata(
        shutterSpeed: shutterSpeed,
        focalLength: focalLength,
        aperture: apertureValue.map { "ƒ/\($0)" },
        apertureValue: apertureValue,
        iso: isoValue.map { "ISO \($0)" },
        isoValue: isoValue,
        camera: camera,
        lensModel: lens,
        rawFileType: "Lossless Compressed",
        rawSizeClass: "L",
        pixelWidth: 8640,
        pixelHeight: 5760,
    )
}
