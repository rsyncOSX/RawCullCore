import Foundation

public nonisolated struct ExifMetadata: Codable, Hashable, Sendable {
    public let shutterSpeed: String?
    public let exposureTimeSeconds: Double?
    public let focalLength: String?
    public let focalLengthMM: Double?
    public let aperture: String?
    public let apertureValue: Double?
    public let iso: String?
    public let isoValue: Int?
    public let exposureCompensationEV: Double?
    public let camera: String?
    public let lensModel: String?
    public let rawFileType: String?
    public let rawSizeClass: String?
    public let pixelWidth: Int?
    public let pixelHeight: Int?

    public nonisolated init(
        shutterSpeed: String?,
        exposureTimeSeconds: Double? = nil,
        focalLength: String?,
        focalLengthMM: Double? = nil,
        aperture: String?,
        apertureValue: Double?,
        iso: String?,
        isoValue: Int?,
        exposureCompensationEV: Double? = nil,
        camera: String?,
        lensModel: String?,
        rawFileType: String?,
        rawSizeClass: String?,
        pixelWidth: Int?,
        pixelHeight: Int?,
    ) {
        self.shutterSpeed = shutterSpeed
        self.exposureTimeSeconds = exposureTimeSeconds
        self.focalLength = focalLength
        self.focalLengthMM = focalLengthMM
        self.aperture = aperture
        self.apertureValue = apertureValue
        self.iso = iso
        self.isoValue = isoValue
        self.exposureCompensationEV = exposureCompensationEV
        self.camera = camera
        self.lensModel = lensModel
        self.rawFileType = rawFileType
        self.rawSizeClass = rawSizeClass
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}
