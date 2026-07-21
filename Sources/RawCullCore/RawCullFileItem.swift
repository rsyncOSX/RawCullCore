import CoreGraphics
import Foundation

public nonisolated struct RawCullFileItem: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let name: String
    public let size: Int64
    public let dateModified: Date
    public let captureDate: Date?
    public let captureTimeZoneOffsetSeconds: Int?
    public let exifData: ExifMetadata?
    public let afFocusNormalized: CGPoint?

    public nonisolated init(
        id: UUID = UUID(),
        url: URL,
        name: String,
        size: Int64,
        dateModified: Date,
        captureDate: Date? = nil,
        captureTimeZoneOffsetSeconds: Int? = nil,
        exifData: ExifMetadata?,
        afFocusNormalized: CGPoint?,
    ) {
        self.id = id
        self.url = url
        self.name = name
        self.size = size
        self.dateModified = dateModified
        self.captureDate = captureDate
        self.captureTimeZoneOffsetSeconds = captureTimeZoneOffsetSeconds
        self.exifData = exifData
        self.afFocusNormalized = afFocusNormalized
    }

    public nonisolated var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public nonisolated var effectiveCaptureDate: Date {
        captureDate ?? dateModified
    }

    public nonisolated var usesFileModificationDateForCaptureTime: Bool {
        captureDate == nil
    }

    public nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
