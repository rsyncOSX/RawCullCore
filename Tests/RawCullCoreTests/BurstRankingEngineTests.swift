import Foundation
@testable import RawCullCore
import Testing

@Suite("BurstRankingEngine")
struct BurstRankingEngineTests {
    @Test
    func `Relative sharpness is empty when spread is too small`() {
        let ids = [UUID(), UUID()]
        let components = BurstRankingEngine.burstRelativeSharpnessComponents(
            fileIDs: ids,
            scores: [ids[0]: 0.50, ids[1]: 0.52],
            maxScore: 1.0,
        )

        #expect(components.isEmpty)
    }

    @Test
    func `Relative sharpness normalizes scores inside burst`() {
        let ids = [UUID(), UUID(), UUID()]
        let components = BurstRankingEngine.burstRelativeSharpnessComponents(
            fileIDs: ids,
            scores: [ids[0]: 0.40, ids[1]: 0.70, ids[2]: 1.00],
            maxScore: 1.0,
        )

        #expect(components[ids[0]] == 0)
        #expect(abs((components[ids[1]] ?? 0) - 0.5) < 0.0001)
        #expect(components[ids[2]] == 1)
    }

    @Test
    func `Rank group recommends highest scoring candidate with high confidence`() throws {
        let files = [
            makeBurstFile(name: "one.ARW", seconds: 0, captureSeconds: 100),
            makeBurstFile(name: "two.ARW", seconds: 1, captureSeconds: 101),
            makeBurstFile(name: "three.ARW", seconds: 2, captureSeconds: 102)
        ]
        let group = BurstGroup(id: 7, fileIDs: files.map(\.id))
        let evidence = stableEvidence(for: files)

        let result = BurstRankingEngine.rankGroup(
            group,
            filesByID: Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) }),
            scores: [
                files[0].id: 0.30,
                files[1].id: 0.55,
                files[2].id: 1.00
            ],
            maxScore: 1.0,
            saliencyInfo: Dictionary(uniqueKeysWithValues: files.map { ($0.id, SaliencyInfo(subjectLabel: "bird")) }),
            boundaryEvidence: evidence,
            reviewState: .algorithmReviewed,
        )

        #expect(result.groupID == 7)
        #expect(result.recommendedFileID == files[2].id)
        #expect(result.secondBestFileID == files[1].id)
        #expect(result.confidence == .high)
        #expect(result.reviewState == .algorithmReviewed)
        #expect(result.isSafeForOneClickCulling)
        #expect(result.canApplyOneClickCulling(hasSharpnessScores: true))

        let best = try #require(result.candidates.first)
        #expect(best.fileID == files[2].id)
        #expect(best.confidence == .high)
        #expect(best.reasons.contains("Burst-relative sharpness measured"))
    }

    @Test
    func `Missing scores produce low confidence and sharpness cautions`() {
        let files = [
            makeBurstFile(name: "one.ARW", seconds: 0, afPoint: nil),
            makeBurstFile(name: "two.ARW", seconds: 1, afPoint: nil)
        ]
        let group = BurstGroup(id: 1, fileIDs: files.map(\.id))

        let result = BurstRankingEngine.rankGroup(
            group,
            filesByID: Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) }),
            scores: [:],
            maxScore: 1.0,
            saliencyInfo: [:],
            boundaryEvidence: stableEvidence(for: files),
        )

        #expect(result.confidence == .low)
        #expect(!result.isSafeForOneClickCulling)
        #expect(!result.canApplyOneClickCulling(hasSharpnessScores: false))
        #expect(result.cautions.contains("Sharpness scores missing"))
        #expect(result.candidates.allSatisfy { $0.cautions.contains("Sharpness missing") })
        #expect(result.candidates.allSatisfy { $0.cautions.contains("AF evidence missing") })
    }

    @Test
    func `Rank applies review states by group id`() throws {
        let files = [
            makeBurstFile(name: "one.ARW", seconds: 0),
            makeBurstFile(name: "two.ARW", seconds: 1)
        ]
        let groups = [BurstGroup(id: 42, fileIDs: files.map(\.id))]

        let results = BurstRankingEngine.rank(
            groups: groups,
            filesByID: Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) }),
            scores: [files[0].id: 0.80, files[1].id: 0.70],
            maxScore: 1.0,
            saliencyInfo: [:],
            boundaryEvidence: stableEvidence(for: files),
            reviewStates: [42: .manualWinnerOverride],
        )

        let result = try #require(results.first)
        #expect(result.reviewState == .manualWinnerOverride)
    }

    @Test
    func `Faster shutter receives lower motion-risk ranking evidence`() throws {
        let fast = makeBurstFile(
            name: "fast.ARW",
            seconds: 0,
            captureSeconds: 100,
            exif: makeExif(
                shutterSpeed: "1/1000 s",
                exposureTimeSeconds: 1.0 / 1_000.0,
                focalLengthMM: 400,
            ),
        )
        let slow = makeBurstFile(
            name: "slow.ARW",
            seconds: 1,
            captureSeconds: 101,
            exif: makeExif(
                shutterSpeed: "1/100 s",
                exposureTimeSeconds: 1.0 / 100.0,
                focalLengthMM: 400,
            ),
        )
        let files = [fast, slow]

        let result = BurstRankingEngine.rankGroup(
            BurstGroup(id: 1, fileIDs: files.map(\.id)),
            filesByID: Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) }),
            scores: [fast.id: 0.8, slow.id: 0.8],
            maxScore: 1,
            saliencyInfo: [:],
            boundaryEvidence: stableEvidence(for: files),
        )

        #expect(result.recommendedFileID == fast.id)
        let fastCandidate = try #require(result.candidates.first { $0.fileID == fast.id })
        let slowCandidate = try #require(result.candidates.first { $0.fileID == slow.id })
        #expect(fastCandidate.metadataComponent > slowCandidate.metadataComponent)
        #expect(fastCandidate.reasons.contains("Fast shutter lowers motion risk"))
        #expect(slowCandidate.cautions.contains("Slower shutter increases motion risk"))
    }

    @Test
    func `High ISO receives noise-risk ranking evidence`() throws {
        let lowISO = makeBurstFile(
            name: "low-iso.ARW",
            seconds: 0,
            captureSeconds: 100,
            exif: makeExif(isoValue: 800),
        )
        let highISO = makeBurstFile(
            name: "high-iso.ARW",
            seconds: 1,
            captureSeconds: 101,
            exif: makeExif(isoValue: 6_400),
        )
        let files = [lowISO, highISO]

        let result = BurstRankingEngine.rankGroup(
            BurstGroup(id: 1, fileIDs: files.map(\.id)),
            filesByID: Dictionary(uniqueKeysWithValues: files.map { ($0.id, $0) }),
            scores: [lowISO.id: 0.8, highISO.id: 0.8],
            maxScore: 1,
            saliencyInfo: [:],
            boundaryEvidence: stableEvidence(for: files),
        )

        #expect(result.recommendedFileID == lowISO.id)
        let highISOCandidate = try #require(result.candidates.first { $0.fileID == highISO.id })
        #expect(highISOCandidate.cautions.contains("High ISO increases noise risk"))
    }
}

private nonisolated func stableEvidence(for files: [RawCullFileItem]) -> [BurstBoundaryEvidence] {
    guard files.count > 1 else { return [] }
    return files.indices.dropFirst().map { index in
        BurstBoundaryEvidence(
            previousID: files[index - 1].id,
            currentID: files[index].id,
            visualDistance: 0.10,
            timeGapSeconds: 1.0,
            focalLengthDelta: 0,
            exposureChanged: false,
            cameraChanged: false,
            lensChanged: false,
            startsNewGroup: false,
            reasons: [],
        )
    }
}
