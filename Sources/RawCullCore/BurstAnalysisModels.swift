import Foundation

public nonisolated struct BurstGroup: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let fileIDs: [UUID]

    public nonisolated init(id: Int, fileIDs: [UUID]) {
        self.id = id
        self.fileIDs = fileIDs
    }
}

public nonisolated struct BurstGroupingConfig: Codable, Equatable, Sendable {
    public var visualDistanceThreshold: Float
    public var maxTimeGapSeconds: Double
    public var requireSameCamera: Bool
    public var requireSimilarFocalLength: Bool
    public var maxFocalLengthDeltaMM: Double

    public nonisolated static let algorithmVersion = 3

    public nonisolated init(
        visualDistanceThreshold: Float = 0.25,
        maxTimeGapSeconds: Double = 2.0,
        requireSameCamera: Bool = true,
        requireSimilarFocalLength: Bool = true,
        maxFocalLengthDeltaMM: Double = 3.0,
    ) {
        self.visualDistanceThreshold = visualDistanceThreshold
        self.maxTimeGapSeconds = maxTimeGapSeconds
        self.requireSameCamera = requireSameCamera
        self.requireSimilarFocalLength = requireSimilarFocalLength
        self.maxFocalLengthDeltaMM = maxFocalLengthDeltaMM
    }
}

public nonisolated enum BurstPairKey {
    public nonisolated static func cacheKey(previousID: UUID, currentID: UUID) -> String {
        "\(previousID.uuidString)|\(currentID.uuidString)"
    }
}

public nonisolated struct BurstBoundaryEvidence: Codable, Equatable, Sendable {
    public var previousID: UUID
    public var currentID: UUID
    public var visualDistance: Float?
    public var timeGapSeconds: Double?
    public var focalLengthDelta: Double?
    public var exposureChanged: Bool
    public var cameraChanged: Bool
    public var lensChanged: Bool
    public var startsNewGroup: Bool
    public var reasons: [String]

    public nonisolated init(
        previousID: UUID,
        currentID: UUID,
        visualDistance: Float?,
        timeGapSeconds: Double?,
        focalLengthDelta: Double?,
        exposureChanged: Bool,
        cameraChanged: Bool,
        lensChanged: Bool,
        startsNewGroup: Bool,
        reasons: [String],
    ) {
        self.previousID = previousID
        self.currentID = currentID
        self.visualDistance = visualDistance
        self.timeGapSeconds = timeGapSeconds
        self.focalLengthDelta = focalLengthDelta
        self.exposureChanged = exposureChanged
        self.cameraChanged = cameraChanged
        self.lensChanged = lensChanged
        self.startsNewGroup = startsNewGroup
        self.reasons = reasons
    }
}

public nonisolated enum BurstDecisionConfidence: String, Codable, Equatable, Sendable {
    case high
    case medium
    case low

    public nonisolated var title: String {
        switch self {
        case .high: "High confidence"
        case .medium: "Review recommended"
        case .low: "Low confidence"
        }
    }
}

public nonisolated struct BurstWinnerOverride: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var winnerFileName: String
    public var memberFileNames: [String]

    public nonisolated init(
        id: UUID = UUID(),
        winnerFileName: String,
        memberFileNames: [String],
    ) {
        self.id = id
        self.winnerFileName = winnerFileName
        self.memberFileNames = memberFileNames
    }

    enum CodingKeys: String, CodingKey {
        case id
        case winnerFileName
        case memberFileNames
    }

    public nonisolated init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        winnerFileName = try values.decode(String.self, forKey: .winnerFileName)
        memberFileNames = try values.decodeIfPresent([String].self, forKey: .memberFileNames) ?? []
    }
}

public nonisolated enum BurstReviewState: String, Codable, Equatable, Sendable {
    case none
    case needsReview
    case reviewed
    case deferred
    // Keep existing states for cache/backward compatibility unless you migrate them.
    case algorithmReviewed
    case manualWinnerOverride
    case decisionApplied

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .none
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public extension BurstReviewState {
    nonisolated var title: String {
        switch self {
        case .none: "Not reviewed"
        case .needsReview: "Needs Review"
        case .reviewed: "Reviewed"
        case .deferred: "Deferred"
        case .algorithmReviewed: "Algorithm Reviewed"
        case .manualWinnerOverride: "Manual Winner"
        case .decisionApplied: "Decision Applied"
        }
    }
}

public nonisolated struct BurstCandidateScore: Codable, Equatable, Sendable {
    public var fileID: UUID
    public var overallScore: Float
    public var sharpnessComponent: Float
    public var burstRelativeSharpnessComponent: Float?
    public var focusPointComponent: Float
    public var saliencyComponent: Float
    public var metadataComponent: Float
    public var confidence: BurstDecisionConfidence
    public var reasons: [String]
    public var cautions: [String]

    public nonisolated init(
        fileID: UUID,
        overallScore: Float,
        sharpnessComponent: Float,
        burstRelativeSharpnessComponent: Float?,
        focusPointComponent: Float,
        saliencyComponent: Float,
        metadataComponent: Float,
        confidence: BurstDecisionConfidence,
        reasons: [String],
        cautions: [String],
    ) {
        self.fileID = fileID
        self.overallScore = overallScore
        self.sharpnessComponent = sharpnessComponent
        self.burstRelativeSharpnessComponent = burstRelativeSharpnessComponent
        self.focusPointComponent = focusPointComponent
        self.saliencyComponent = saliencyComponent
        self.metadataComponent = metadataComponent
        self.confidence = confidence
        self.reasons = reasons
        self.cautions = cautions
    }
}

public nonisolated struct BurstAnalysisResult: Codable, Equatable, Identifiable, Sendable {
    public var id: Int {
        groupID
    }

    public var groupID: Int
    public var fileIDs: [UUID]
    public var candidates: [BurstCandidateScore]
    public var recommendedFileID: UUID?
    public var secondBestFileID: UUID?
    public var confidence: BurstDecisionConfidence
    public var reviewState: BurstReviewState
    public var isSafeForOneClickCulling: Bool
    public var reasons: [String]
    public var cautions: [String]

    public nonisolated init(
        groupID: Int,
        fileIDs: [UUID],
        candidates: [BurstCandidateScore],
        recommendedFileID: UUID?,
        secondBestFileID: UUID?,
        confidence: BurstDecisionConfidence,
        reviewState: BurstReviewState,
        isSafeForOneClickCulling: Bool,
        reasons: [String],
        cautions: [String],
    ) {
        self.groupID = groupID
        self.fileIDs = fileIDs
        self.candidates = candidates
        self.recommendedFileID = recommendedFileID
        self.secondBestFileID = secondBestFileID
        self.confidence = confidence
        self.reviewState = reviewState
        self.isSafeForOneClickCulling = isSafeForOneClickCulling
        self.reasons = reasons
        self.cautions = cautions
    }

    public nonisolated func canApplyOneClickCulling(hasSharpnessScores: Bool) -> Bool {
        isSafeForOneClickCulling && hasSharpnessScores
    }
}
