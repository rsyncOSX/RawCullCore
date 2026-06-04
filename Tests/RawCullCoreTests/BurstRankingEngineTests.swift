import Foundation
import Testing
@testable import RawCullCore

@Suite("BurstRankingEngine")
struct BurstRankingEngineTests {
    @Test("Relative sharpness is empty when spread is too small")
    func relativeSharpnessRequiresMeaningfulSpread() {
        let ids = [UUID(), UUID()]
        let components = BurstRankingEngine.burstRelativeSharpnessComponents(
            fileIDs: ids,
            scores: [ids[0]: 0.50, ids[1]: 0.52],
            maxScore: 1.0,
        )

        #expect(components.isEmpty)
    }

    @Test("Relative sharpness normalizes scores inside burst")
    func relativeSharpnessNormalizesScores() throws {
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

    @Test("Rank group recommends highest scoring candidate with high confidence")
    func rankGroupHighConfidence() throws {
        let files = [
            makeBurstFile(name: "one.ARW", seconds: 0),
            makeBurstFile(name: "two.ARW", seconds: 1),
            makeBurstFile(name: "three.ARW", seconds: 2)
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

    @Test("Missing scores produce low confidence and sharpness cautions")
    func missingScoresAreLowConfidence() throws {
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

    @Test("Rank applies review states by group id")
    func rankAppliesReviewStates() throws {
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
