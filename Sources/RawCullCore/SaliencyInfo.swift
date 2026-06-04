import Foundation

public nonisolated struct SaliencyInfo: Codable, Equatable, Sendable {
    public let subjectLabel: String?
    public let subjectConfidence: Float?

    public nonisolated init(subjectLabel: String?, subjectConfidence: Float? = nil) {
        self.subjectLabel = subjectLabel
        self.subjectConfidence = subjectConfidence
    }
}
